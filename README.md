# Linux Voice Typing (Thai/English) 🇹🇭🇺🇸

A modern, high-performance offline voice typing agent for Linux, powered by `whisper.cpp`.
Designed for seamless integration with any application via global hotkeys.

## ✨ Features

- **Offline Privacy**: All transcription happens locally on your machine. No data is sent to the cloud.
- **High Performance**: Optimized for multi-core CPUs (uses 10+ threads).
- **Dual Language**: Supports **Thai** and **English** with instant toggling.
- **Modern UI**: Sleek, dark-mode overlay showing real-time status (Listening, Thinking, Typing).
- **Smart Typing**: Uses Clipboard Paste (Ctrl+V) to ensure correct text output regardless of keyboard layout.
- **Persistent**: Starts automatically on login and stays ready in the background.

## 🚀 Installation

1.  **Clone the repository**:
    ```bash
    git clone https://github.com/YOUR_USERNAME/LinuxVoiceTyping.git
    cd LinuxVoiceTyping
    ```
2.  **Run the installer**:
    ```bash
    chmod +x install.sh
    ./install.sh
    ```
    This script will:
    - Install all system dependencies.
    - Clone and build `whisper.cpp`.
    - Download the AI model.
    - Configure global shortcuts (`Meta+H`).

3.  **Start using it!** (You may need to restart your computer for shortcuts to take effect).

| Shortcut | Action |
| :--- | :--- |
| **Meta + H** | **Start/Stop Recording** (Super+H) |
| **Meta + Shift + H** | **Toggle Language** (Thai 🇹🇭 / English 🇺🇸) |

*Note: "Meta" is usually the Windows key.*

### How it works
1.  Press **Meta + Shift + H** to select your language (check the notification).
2.  Place your cursor where you want to type.
3.  Press **Meta + H** and start speaking.
4.  The overlay will show **🔴 Listening...**.
5.  Press **Meta + H** again to stop.
6.  The overlay will show **🔵 Thinking...** then **🟢 Typing...**.
7.  The text will appear in your active window!

## ⚙️ Configuration

You can customize settings in `config.env`:
```bash
nano ~/Documents/LinuxVoiceTyping/config.env
```

Key settings:
- `WHISPER_LANG`: Default language on boot (set to "th" for Thai).
- `WHISPER_THREADS`: CPU threads to use (default 10). Increase for speed if you have more cores.
- `ARECORD_DEVICE`: Microphone device (Currently: `sysdefault:CARD=Quadcast`).

## 🛠️ Troubleshooting

- **No Sound**: Check your microphone input level in System Settings.
- **Gibberish Text**: Ensure the target application supports Paste (Ctrl+V).
- **Popup missing**: Verify `python3-tk` is installed.

## 📂 Project Structure

- `agent.py`: Main logic controller.
- `popup.py`: Modern UI overlay.
- `transcribe.sh`: Transcription logic using `whisper.cpp`.
- `record.sh`: Audio recording script.
- `toggle_lang.sh`: Language switching script.
