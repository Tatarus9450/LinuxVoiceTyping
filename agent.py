#!/usr/bin/env python3
import fcntl
import os
import signal
import subprocess
import time
from pathlib import Path

from typhoon_backend import config_bool, ensure_service, load_config

HOME = Path.home()
BASE = Path(__file__).parent.resolve()
PID_FILE = Path("/tmp/voice_agent_arecord.pid")
ARECORD_LOG_FILE = Path("/tmp/voice_agent_arecord.log")
POPUP_PID_FILE = Path("/tmp/voice_agent_popup.pid")
WAV_FILE = Path("/tmp/voice_agent.wav")
STATUS_FILE = Path("/tmp/voice_agent_status")
TRIGGER_LOCK_FILE = Path("/tmp/voice_agent_trigger.lock")
LAST_TRIGGER_FILE = Path("/tmp/voice_agent_last_trigger")
TRIGGER_DEBOUNCE_SECONDS = 0.35

def log(msg):
    with open("/tmp/agent_debug.log", "a") as f:
        f.write(f"{time.ctime()}: {msg}\n")

def notify(msg: str):
    log(f"Notify: {msg}")
    subprocess.run(["notify-send", "Phim Thai Mai Pen", msg], check=False)

def set_status(status: str):
    STATUS_FILE.write_text(status)


def read_recent_arecord_log(max_lines: int = 8) -> str:
    if not ARECORD_LOG_FILE.exists():
        return ""

    try:
        lines = [line.strip() for line in ARECORD_LOG_FILE.read_text(encoding="utf-8", errors="ignore").splitlines()]
    except Exception:
        return ""

    lines = [line for line in lines if line]
    if not lines:
        return ""
    return " | ".join(lines[-max_lines:])


def build_arecord_command(config, device_override=None):
    arecord_cmd = ["arecord"]
    if device_override:
        arecord_cmd.extend(["-D", device_override])
    arecord_cmd.extend(
        [
            "-f",
            config.get("ARECORD_FORMAT", "S16_LE"),
            "-c",
            config.get("ARECORD_CHANNELS", "1"),
            "-r",
            config.get("ARECORD_RATE", "16000"),
            "-t",
            "wav",
            str(WAV_FILE),
        ]
    )
    return arecord_cmd


def get_arecord_candidates(config):
    configured = config.get("ARECORD_DEVICE", "").strip()
    candidates = []
    seen = set()

    def add(value):
        key = value or ""
        if key not in seen:
            candidates.append(value)
            seen.add(key)

    if configured:
        add(configured)

    add(None)
    add("default")
    add("pulse")
    return candidates


def start_arecord_process(config):
    ARECORD_LOG_FILE.unlink(missing_ok=True)

    last_error = ""
    for candidate in get_arecord_candidates(config):
        arecord_cmd = build_arecord_command(config, device_override=candidate)
        label = candidate or "system default"

        with ARECORD_LOG_FILE.open("ab") as log_file:
            log_file.write(f"\n=== Attempt device: {label} ===\n".encode("utf-8"))
            proc = subprocess.Popen(
                arecord_cmd,
                cwd=str(BASE),
                stdout=log_file,
                stderr=log_file,
                start_new_session=True,
            )

        time.sleep(0.15)
        if proc.poll() is None:
            return proc, label

        last_error = read_recent_arecord_log() or f"arecord exited with code {proc.returncode}"
        log(f"Recording start failed on {label}: {last_error}")

    return None, last_error


def recording_output_ready(timeout: float = 2.0) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if WAV_FILE.exists():
            try:
                if WAV_FILE.stat().st_size > 0:
                    return True
            except OSError:
                pass
        time.sleep(0.05)
    return WAV_FILE.exists()


def is_duplicate_trigger() -> bool:
    now = time.time()
    with TRIGGER_LOCK_FILE.open("a+", encoding="utf-8") as lock_file:
        fcntl.flock(lock_file, fcntl.LOCK_EX)

        last_trigger = 0.0
        if LAST_TRIGGER_FILE.exists():
            try:
                last_trigger = float(LAST_TRIGGER_FILE.read_text().strip())
            except Exception:
                last_trigger = 0.0

        if now - last_trigger < TRIGGER_DEBOUNCE_SECONDS:
            return True

        LAST_TRIGGER_FILE.write_text(f"{now:.6f}", encoding="utf-8")
        return False

def kill_popup():
    if POPUP_PID_FILE.exists():
        try:
            pid_text = POPUP_PID_FILE.read_text().strip()
            if pid_text:
                os.kill(int(pid_text), signal.SIGTERM)
        except:
            pass
        POPUP_PID_FILE.unlink(missing_ok=True)
    # Ensure cleanup
    subprocess.run(["pkill", "-f", str(BASE / "popup.py")], check=False)
    STATUS_FILE.unlink(missing_ok=True)

def is_recording() -> bool:
    return PID_FILE.exists()

def start_recording():
    config = load_config()

    # Remove old wav
    try:
        WAV_FILE.unlink(missing_ok=True)
    except TypeError:
        if WAV_FILE.exists(): WAV_FILE.unlink()

    proc, device_label = start_arecord_process(config)
    if proc is None:
        PID_FILE.unlink(missing_ok=True)
        error_details = device_label or "Unable to start arecord."
        log(f"Recording failed to start: {error_details}")
        notify(f"Recording failed: {error_details}")
        return

    PID_FILE.write_text(str(proc.pid), encoding="utf-8")
    log(f"Recording started with {device_label}")

    set_status("recording")

    if config_bool(config, "POPUP_ENABLED", True):
        popup_proc = subprocess.Popen(
            ["python3", str(BASE / "popup.py")],
            cwd=str(BASE),
            start_new_session=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        POPUP_PID_FILE.write_text(str(popup_proc.pid))

    try:
        ensure_service(wait=False)
        log("Started recording and requested Typhoon warm-up")
    except Exception as exc:
        log(f"Typhoon warm-up failed: {exc}")


def stop_recording_and_type():
    # 1. Stop Recording
    try:
        pid = int(PID_FILE.read_text().strip()) if PID_FILE.exists() else None
    except: pid = None

    if pid:
        try:
            os.kill(pid, signal.SIGINT)
            time.sleep(1.0)
            try:
                os.kill(pid, 0)
                os.kill(pid, signal.SIGKILL)
            except: pass
        except: pass
    
    PID_FILE.unlink(missing_ok=True)

    if not recording_output_ready(timeout=2.0):
        kill_popup()
        error_details = read_recent_arecord_log() or "No audio file was created. Check your microphone or ARECORD_DEVICE."
        log(f"Recording did not produce audio: {error_details}")
        notify(f"Recording failed: {error_details}")
        return

    # 2. Update Status to Transcribing (Popup shows "Thinking...")
    set_status("transcribing")
    
    # 3. Transcribe
    transcribe = subprocess.run(
        [str(BASE / "transcribe.sh"), str(WAV_FILE)],
        text=True,
        capture_output=True
    )
    
    if transcribe.returncode != 0:
        kill_popup()
        notify(f"Transcribe failed: {transcribe.stderr}")
        return

    output_lines = transcribe.stdout.strip().splitlines()
    txt_path = output_lines[-1] if output_lines else "/tmp/voice_agent.txt"
    
    # Check emptiness
    txt_path_obj = Path(txt_path)
    if not txt_path_obj.exists() or txt_path_obj.stat().st_size == 0:
         kill_popup()
         notify("No speech detected.")
         return

    text_content = txt_path_obj.read_text().strip()
    if text_content in ["[BLANK_AUDIO]", "(Blank Audio)", ""] or not text_content:
        kill_popup()
        notify("No speech detected (Silence).")
        return

    # 4. Update Status to Typing (Popup shows "Typing...")
    set_status("typing")
    
    # 5. Type
    subprocess.run([str(BASE / "type.sh"), txt_path], check=False)
    
    # 6. Keep "Typing..." visible briefly, then cleanup
    time.sleep(1.0)
    kill_popup()

def main():
    if is_duplicate_trigger():
        log("Ignored duplicate trigger")
        return

    log("Agent triggered")
    if not is_recording():
        start_recording()
    else:
        stop_recording_and_type()

if __name__ == "__main__":
    main()
