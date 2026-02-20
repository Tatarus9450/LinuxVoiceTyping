#!/usr/bin/env python3
import os
import signal
import subprocess
import time
from pathlib import Path

HOME = Path.home()
BASE = Path(__file__).parent.resolve()
PID_FILE = Path("/tmp/voice_agent_arecord.pid")
POPUP_PID_FILE = Path("/tmp/voice_agent_popup.pid")
WAV_FILE = Path("/tmp/voice_agent.wav")
STATUS_FILE = Path("/tmp/voice_agent_status")

def log(msg):
    with open("/tmp/agent_debug.log", "a") as f:
        f.write(f"{time.ctime()}: {msg}\n")

def notify(msg: str):
    log(f"Notify: {msg}")
    subprocess.run(["notify-send", "Voice Agent", msg], check=False)

def set_status(status: str):
    STATUS_FILE.write_text(status)

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
    # Remove old wav
    try:
        WAV_FILE.unlink(missing_ok=True)
    except TypeError:
        if WAV_FILE.exists(): WAV_FILE.unlink()

    # Start Recording
    cmd = [
        "bash", "-lc",
        f"""
        set -e
        source "{BASE}/config.env"
        if [[ -n "$ARECORD_DEVICE" ]]; then
          arecord -D "$ARECORD_DEVICE" -f cd -t wav "{WAV_FILE}" &
        else
          arecord -f cd -t wav "{WAV_FILE}" &
        fi
        echo $! > "{PID_FILE}"
        """
    ]
    subprocess.run(cmd, check=True)

    # Start Popup (Modern UI) and set status
    set_status("recording")
    
    # We use Popen to keep it running independently
    popup_proc = subprocess.Popen(
        ["python3", str(BASE / "popup.py")],
        cwd=str(BASE),
        start_new_session=True,
        stdout=subprocess.DEVNULL, 
        stderr=subprocess.DEVNULL
    )
    POPUP_PID_FILE.write_text(str(popup_proc.pid))
    
    # Log
    log("Started recording and popup")


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
    log("Agent triggered")
    if not is_recording():
        start_recording()
    else:
        stop_recording_and_type()

if __name__ == "__main__":
    main()
