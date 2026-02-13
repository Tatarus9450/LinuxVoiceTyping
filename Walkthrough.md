# Linux Voice Typing Walkthrough

## Overview
This document guides you through setting up and using the "Voice Typing Agent" on Kubuntu 24.04 (KDE Plasma). The agent mimics Windows+H functionality, allowing you to record, transcribe, and type text into any focused application.

## Prerequisites & Installation
Ensure you have the project in `/home/task/Documents/LinuxVoiceTyping`.

## Setup Instructions

### 1. Configure Startup Shortcut (Recommended)
The system now uses `xbindkeys` to provide a reliable global shortcut **Meta+H** that works from boot.
This has been installed and configured for you.

If you ever need to restart the shortcut listener manually:
```bash
killall xbindkeys
xbindkeys
```

*(Optional) Legacy KDE Shortcut Method:*
If you prefer using KDE's native shortcuts instead of `xbindkeys`, you can manually set it in **System Settings** -> **Shortcuts** -> **Custom Shortcuts** -> New Command -> `/home/task/Documents/LinuxVoiceTyping/agent.py` attached to `Meta+H`.

### 2. Verify Audio Configuration
Check your default microphone setting. You can test recording with:
```bash
arecord -f cd -d 5 /tmp/test.wav
aplay /tmp/test.wav
```
If this works, the agent will work. If you have multiple devices, distinct the device name using `arecord -L` and update `ARECORD_DEVICE` in `/home/task/Documents/LinuxVoiceTyping/config.env`.

## Usage
1.  **Start Recording**: Press `Meta+H`.
    -   A notification "Recording..." should appear.
    -   Speak clearly into your microphone.
2.  **Stop & Type**: Press `Meta+H` again.
    -   A notification "Transcribing..." will appear.
    -   The transcribed text will be typed into your currently focused window.
    -   If text appears incorrect, verify the model path in `config.env`. The default is `medium`.


## Configuration
The settings are in `/home/task/Documents/LinuxVoiceTyping/config.env`.
-   **Language**: `WHISPER_LANG="auto"` (default). toggle with **Meta+Shift+H**.
-   **Threads**: `WHISPER_THREADS` (default 10) controls CPU usage. Increase for speed.
-   **Model**: `WHISPER_MODEL` points to the `ggml-medium.bin` file.

## UI Features
-   **Modern Overlay**: A dark, modern popup appears with real-time status:
    -   🔴 **Listening...**: Recording audio.
    -   🔵 **Thinking...**: Transcribing audio.
    -   🟢 **Typing...**: Injecting text.
-   **Language Flag**: Shows 🇹🇭 or 🇺🇸 to indicate active language.

## Troubleshooting
-   **Popup not showing**: Ensure `python3-tk` is installed (`sudo apt install python3-tk`). Check `config.env` for `POPUP_ENABLED=true`.
-   **No Text Typed**: Ensure `xdotool` is working (try `xdotool type "test"` in terminal). Some apps (like Snap packages) might block `xdotool`. The script falls back to clipboard (Ctrl+V) if direct typing fails.
-   **Transcription Issues**: Check `/tmp/voice_agent.txt` to see if text was generated.
-   **Logs**: Check `notify-send` messages.
