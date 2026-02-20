# Linux Voice Typing �

Offline voice-to-text for Linux — speak and type in **Thai** and **English**.  
Powered by [whisper.cpp](https://github.com/ggerganov/whisper.cpp) with **Vulkan GPU** acceleration.

---

## ✨ Features

- **100% Offline** — All transcription runs locally. No cloud, no data leaves your machine.
- **Vulkan GPU Accelerated** — Uses AMD/Intel integrated GPU for fast inference.
- **Thai + English** — Toggle between languages instantly with a hotkey.
- **Works Everywhere** — Types into any focused application via clipboard paste.
- **Minimal UI** — Sleek dark overlay shows real-time status (Listening → Thinking → Typing).
- **Persistent** — Starts on login via `xbindkeys` global shortcuts.

---

## 🖥️ Requirements

- **OS**: Linux with X11 (tested on Kubuntu 24.04 / KDE Plasma)
- **CPU**: x86_64 (multi-core recommended)
- **GPU**: Vulkan-capable (AMD/Intel iGPU works great)
- **Microphone**: Any ALSA-compatible input device

---

## 🚀 Quick Start

```bash
git clone https://github.com/Tatarus9450/LinuxVoiceTyping.git
cd LinuxVoiceTyping
chmod +x install.sh
./install.sh
```

The installer will:
1. Install all system dependencies
2. Clone and build `whisper.cpp` with Vulkan support
3. Download the AI model (`ggml-medium.bin`, ~1.5 GB)
4. Configure global hotkeys (`Meta+H`)
5. Set up autostart on login

> Restart your session if shortcuts don't work immediately.

---

## ⌨️ Usage

| Shortcut | Action |
| :--- | :--- |
| `Meta + H` | **Start / Stop** recording |
| `Meta + Shift + H` | **Toggle language** (Thai ↔ English) |

### How it works

1. Press `Meta + Shift + H` to pick your language.
2. Place your cursor where you want to type.
3. Press `Meta + H` — the overlay shows **🔴 Listening**.
4. Speak clearly.
5. Press `Meta + H` again — **🔵 Thinking** → **🟢 Typing**.
6. Text appears in your active window.

---

## ⚙️ Configuration

Edit `config.env` to customize:

```bash
nano ~/Documents/LinuxVoiceTyping/config.env
```

| Setting | Default | Description |
| :--- | :--- | :--- |
| `WHISPER_MODEL` | `ggml-medium.bin` | AI model path |
| `WHISPER_LANG` | `th` | Default language (`th`, `en`, `auto`) |
| `WHISPER_THREADS` | `16` | CPU threads for inference |
| `ARECORD_DEVICE` | *(empty)* | ALSA mic override (find with `arecord -L`) |
| `TYPE_DELAY` | `6` | Typing delay for xdotool fallback |
| `POPUP_ENABLED` | `true` | Show/hide status overlay |

---

## 📂 Project Structure

```
LinuxVoiceTyping/
├── agent.py           # Main controller (start/stop toggle)
├── popup.py           # Minimal UI overlay (tkinter)
├── transcribe.sh      # Whisper transcription pipeline
├── record.sh          # Audio capture (arecord)
├── type.sh            # Text output (clipboard paste)
├── toggle_lang.sh     # Language switcher
├── config.env         # User settings
├── config.env.example # Settings template
├── install.sh         # One-shot installer
└── whisper.cpp/       # AI engine (git-ignored)
```

---

## 🛠️ Troubleshooting

| Problem | Solution |
| :--- | :--- |
| No sound recorded | Check mic input in System Settings or `arecord -L` |
| Text not appearing | Target app may block paste — try a different app |
| Popup missing | Install `python3-tk`: `sudo apt install python3-tk` |
| Slow transcription | Increase `WHISPER_THREADS` or verify Vulkan build |
| Wrong language | Press `Meta+Shift+H` to toggle |

**Logs**: Check `/tmp/agent_debug.log` for diagnostics.

---

## 📄 License

MIT
