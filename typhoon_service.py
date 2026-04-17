#!/usr/bin/env python3
import argparse
import atexit
import json
import os
import re
import signal
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
import wave
from pathlib import Path

from typhoon_backend import SERVICE_PID_FILE, SOCKET_FILE, get_active_profile, load_config, normalize_profile

CONFIG = load_config()
MODEL = None
TORCH = None
NEMO_ASR = None
AUTO_MODEL_FOR_SEQ2SEQ_LM = None
AUTO_TOKENIZER = None
DEVICE = "cpu"
MODEL_LOCK = threading.Lock()
TRANSLATION_MODEL = None
TRANSLATION_TOKENIZER = None
TRANSLATION_LOCK = threading.Lock()
OWNS_SOCKET = False


def log(message: str) -> None:
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}", flush=True)


def configure_runtime() -> None:
    threads = CONFIG.get("TYPHOON_CPU_THREADS", str(os.cpu_count() or 4))
    for key in (
        "OMP_NUM_THREADS",
        "OPENBLAS_NUM_THREADS",
        "MKL_NUM_THREADS",
        "NUMEXPR_NUM_THREADS",
    ):
        os.environ.setdefault(key, threads)

    hf_home = Path(CONFIG.get("TYPHOON_HF_HOME", str(Path(".cache") / "huggingface"))).expanduser()
    hf_home.mkdir(parents=True, exist_ok=True)

    os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
    os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
    os.environ.setdefault("HF_HOME", str(hf_home))
    os.environ.setdefault("HF_HUB_CACHE", str(hf_home / "hub"))
    os.environ.setdefault("MPLCONFIGDIR", str(hf_home.parent / "matplotlib"))


def import_runtime_modules() -> None:
    global TORCH, NEMO_ASR

    if TORCH is not None and NEMO_ASR is not None:
        return

    configure_runtime()

    import torch  # type: ignore
    import nemo.collections.asr as nemo_asr  # type: ignore

    TORCH = torch
    NEMO_ASR = nemo_asr

    threads = int(CONFIG.get("TYPHOON_CPU_THREADS", str(os.cpu_count() or 4)))
    try:
        torch.set_num_threads(threads)
    except Exception:
        pass
    try:
        torch.set_num_interop_threads(max(1, min(threads, 4)))
    except Exception:
        pass
    try:
        torch.set_grad_enabled(False)
    except Exception:
        pass


def import_translation_modules() -> None:
    global AUTO_MODEL_FOR_SEQ2SEQ_LM, AUTO_TOKENIZER

    if AUTO_MODEL_FOR_SEQ2SEQ_LM is not None and AUTO_TOKENIZER is not None:
        return

    configure_runtime()

    from transformers import AutoModelForSeq2SeqLM, AutoTokenizer  # type: ignore

    AUTO_MODEL_FOR_SEQ2SEQ_LM = AutoModelForSeq2SeqLM
    AUTO_TOKENIZER = AutoTokenizer


def resolve_device() -> str:
    import_runtime_modules()

    requested = CONFIG.get("TYPHOON_DEVICE", "cpu").strip().lower()
    if requested == "auto":
        return "cuda" if TORCH.cuda.is_available() else "cpu"
    if requested == "cuda" and not TORCH.cuda.is_available():
        log("CUDA requested but unavailable; falling back to CPU")
        return "cpu"
    return requested or "cpu"


def _write_silence_wav(path: Path, duration_ms: int = 250, sample_rate: int = 16000) -> None:
    frame_count = int(sample_rate * (duration_ms / 1000))
    silence = (b"\x00\x00" * frame_count)

    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(silence)


def load_model() -> None:
    global DEVICE, MODEL

    if MODEL is not None:
        return

    import_runtime_modules()
    DEVICE = resolve_device()
    model_name = CONFIG.get("TYPHOON_MODEL", "scb10x/typhoon-asr-realtime")

    log(f"Loading model: {model_name} on {DEVICE.upper()}")
    MODEL = NEMO_ASR.models.ASRModel.from_pretrained(
        model_name=model_name,
        map_location=DEVICE,
    )
    MODEL.eval()

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp_audio:
        temp_path = Path(temp_audio.name)
    try:
        _write_silence_wav(temp_path)
        with MODEL_LOCK:
            with TORCH.inference_mode():
                MODEL.transcribe(audio=[str(temp_path)])
        log("Warm-up completed")
    finally:
        temp_path.unlink(missing_ok=True)


def _translate_text_loaded(text: str) -> str:
    if not text.strip():
        return ""

    inputs = TRANSLATION_TOKENIZER(
        text,
        return_tensors="pt",
        truncation=True,
        max_length=512,
    )
    if DEVICE == "cuda":
        inputs = {key: value.to(DEVICE) for key, value in inputs.items()}

    input_ids = inputs.get("input_ids")
    max_new_tokens = 64
    if input_ids is not None:
        max_new_tokens = max(64, min(512, int(input_ids.shape[-1]) * 2))

    with TRANSLATION_LOCK:
        with TORCH.inference_mode():
            generated = TRANSLATION_MODEL.generate(
                **inputs,
                max_new_tokens=max_new_tokens,
            )

    decoded = TRANSLATION_TOKENIZER.batch_decode(
        generated,
        skip_special_tokens=True,
        clean_up_tokenization_spaces=True,
    )
    translated = decoded[0].strip() if decoded else ""
    translated = re.sub(r"\s+", " ", translated).strip()
    translated = re.sub(r"\s+([,.;:!?%])", r"\1", translated)
    return translated


def load_translation_model() -> None:
    global DEVICE, TRANSLATION_MODEL, TRANSLATION_TOKENIZER

    if TRANSLATION_MODEL is not None and TRANSLATION_TOKENIZER is not None:
        return

    import_runtime_modules()
    import_translation_modules()

    DEVICE = resolve_device()
    model_name = CONFIG.get("TYPHOON_TRANSLATE_MODEL", "Helsinki-NLP/opus-mt-th-en")

    log(f"Loading translation model: {model_name} on {DEVICE.upper()}")
    TRANSLATION_TOKENIZER = AUTO_TOKENIZER.from_pretrained(model_name)
    TRANSLATION_MODEL = AUTO_MODEL_FOR_SEQ2SEQ_LM.from_pretrained(model_name)
    if DEVICE == "cuda":
        TRANSLATION_MODEL.to(DEVICE)
    TRANSLATION_MODEL.eval()

    _translate_text_loaded("สวัสดีครับ")
    log("Translation warm-up completed")


def prepare_audio(input_path: Path) -> Path:
    if not input_path.exists():
        raise FileNotFoundError(f"Audio file not found: {input_path}")

    with tempfile.NamedTemporaryFile(prefix="voice_agent_", suffix=".wav", delete=False) as tmp:
        output_path = Path(tmp.name)

    timeout = float(CONFIG.get("TYPHOON_FFMPEG_TIMEOUT", "30"))
    command = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(input_path),
        "-ac",
        "1",
        "-ar",
        "16000",
        "-c:a",
        "pcm_s16le",
        str(output_path),
    ]
    subprocess.run(command, check=True, timeout=timeout)
    return output_path


def read_duration(audio_path: Path) -> float:
    with wave.open(str(audio_path), "rb") as handle:
        frames = handle.getnframes()
        frame_rate = handle.getframerate() or 1
    return frames / frame_rate


def load_replacements() -> list[tuple[str, str]]:
    replacement_path = Path(CONFIG["TYPHOON_REPLACEMENTS_FILE"])
    if not replacement_path.exists():
        return []

    replacements: list[tuple[str, str]] = []
    for line in replacement_path.read_text(encoding="utf-8", errors="ignore").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if "\t" in stripped:
            source, target = stripped.split("\t", 1)
        elif "=>" in stripped:
            source, target = stripped.split("=>", 1)
        else:
            continue
        replacements.append((source.strip(), target.strip()))
    return replacements


def postprocess_text(text: str, profile: str) -> str:
    cleaned = text.replace("\r", " ").replace("\n", " ")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    cleaned = re.sub(r"\s+([,.;:!?%])", r"\1", cleaned)
    cleaned = re.sub(r"([([{])\s+", r"\1", cleaned)
    cleaned = re.sub(r"\s+([)\]}])", r"\1", cleaned)

    if normalize_profile(profile) in {"smart", "th_to_eng"}:
        for source, target in load_replacements():
            cleaned = cleaned.replace(source, target)

    return cleaned.strip()


def translate_text(text: str) -> str:
    if not text.strip():
        return ""

    load_translation_model()
    return _translate_text_loaded(text)


def extract_text(result) -> str:
    if not result:
        return ""

    first = result[0]
    if isinstance(first, str):
        return first
    if hasattr(first, "text"):
        return str(first.text)
    return str(first)


def transcribe_audio(audio_path: Path, profile: str | None = None) -> dict:
    load_model()

    active_profile = normalize_profile(profile or get_active_profile(CONFIG))
    processed_path = prepare_audio(audio_path)

    try:
        audio_duration = read_duration(processed_path)
        start = time.perf_counter()
        with MODEL_LOCK:
            with TORCH.inference_mode():
                raw_result = MODEL.transcribe(audio=[str(processed_path)])

        source_text = postprocess_text(extract_text(raw_result), active_profile)
        text = translate_text(source_text) if active_profile == "th_to_eng" else source_text
        processing_time = time.perf_counter() - start

        return {
            "ok": True,
            "text": text,
            "source_text": source_text,
            "profile": active_profile,
            "device": DEVICE,
            "model": CONFIG.get("TYPHOON_MODEL", "scb10x/typhoon-asr-realtime"),
            "translate_model": CONFIG.get("TYPHOON_TRANSLATE_MODEL", "Helsinki-NLP/opus-mt-th-en"),
            "translation_applied": active_profile == "th_to_eng",
            "audio_duration": audio_duration,
            "processing_time": processing_time,
            "rtf": (processing_time / audio_duration) if audio_duration else 0.0,
        }
    finally:
        processed_path.unlink(missing_ok=True)


class TyphoonHandler(socketserver.StreamRequestHandler):
    def handle(self) -> None:
        try:
            raw_request = self.rfile.readline()
            if not raw_request:
                return

            request = json.loads(raw_request.decode("utf-8"))
            action = request.get("action")

            if action == "ping":
                response = {
                    "ok": True,
                    "profile": get_active_profile(CONFIG),
                    "device": DEVICE,
                    "model": CONFIG.get("TYPHOON_MODEL", "scb10x/typhoon-asr-realtime"),
                    "translate_model": CONFIG.get("TYPHOON_TRANSLATE_MODEL", "Helsinki-NLP/opus-mt-th-en"),
                }
            elif action == "translate":
                source_text = str(request.get("text", ""))
                response = {
                    "ok": True,
                    "text": translate_text(source_text),
                    "source_text": source_text,
                    "device": DEVICE,
                    "translate_model": CONFIG.get("TYPHOON_TRANSLATE_MODEL", "Helsinki-NLP/opus-mt-th-en"),
                }
            elif action == "transcribe":
                audio_path = Path(request["audio_path"]).resolve()
                response = transcribe_audio(audio_path, request.get("profile"))
            else:
                response = {"ok": False, "error": f"Unknown action: {action}"}
        except Exception as exc:
            response = {"ok": False, "error": str(exc)}

        self.wfile.write(json.dumps(response, ensure_ascii=False).encode("utf-8") + b"\n")


class TyphoonServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


def cleanup() -> None:
    if OWNS_SOCKET:
        SOCKET_FILE.unlink(missing_ok=True)
    try:
        current_pid = SERVICE_PID_FILE.read_text(encoding="utf-8").strip()
    except Exception:
        current_pid = ""
    if current_pid == str(os.getpid()):
        SERVICE_PID_FILE.unlink(missing_ok=True)


def handle_signal(_signum, _frame) -> None:
    raise SystemExit(0)


def main() -> int:
    global OWNS_SOCKET

    parser = argparse.ArgumentParser(description="Persistent Typhoon ASR worker")
    parser.add_argument(
        "--preload-only",
        action="store_true",
        help="Download and warm the ASR model, then exit",
    )
    parser.add_argument(
        "--preload-translation",
        action="store_true",
        help="Download and warm the Thai-to-English translation model, then exit",
    )
    args = parser.parse_args()

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)
    atexit.register(cleanup)

    if args.preload_only:
        load_model()
    if args.preload_translation:
        load_translation_model()
    if args.preload_only or args.preload_translation:
        return 0

    load_model()

    SOCKET_FILE.unlink(missing_ok=True)
    SERVICE_PID_FILE.write_text(str(os.getpid()), encoding="utf-8")
    OWNS_SOCKET = True

    log(f"Typhoon service ready on {SOCKET_FILE}")
    with TyphoonServer(str(SOCKET_FILE), TyphoonHandler) as server:
        server.serve_forever()

    return 0


if __name__ == "__main__":
    sys.exit(main())
