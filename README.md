# Linux Voice Typing

Offline voice-to-text for Linux with a local [Typhoon ASR](https://github.com/scb-10x/typhoon-asr) worker.
Optimized for fast Thai dictation with Thai-English mixed speech support through a persistent local service.

---

## ✨ Features

- **100% Local** — Transcription runs on your machine with a self-hosted Typhoon backend.
- **Persistent ASR Worker** — Keeps the model loaded in memory for lower hotkey-to-text latency.
- **Thai + Mixed Dictation** — Default smart mode is tuned for Thai speech with English terms mixed in.
- **Works Everywhere** — Types into any focused application via clipboard paste.
- **Minimal UI** — Sleek dark overlay shows real-time status (Listening → Thinking → Typing).
- **Persistent** — Starts on login via `xbindkeys` global shortcuts.

---

## 🖥️ Requirements

- **OS**: Linux with X11 (tested on Kubuntu 24.04 / KDE Plasma)
- **Architecture**: x86_64
- **CPU**: Multi-core CPU strongly recommended
- **RAM**: 8 GB minimum, 16 GB+ recommended
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
2. Create a project-local Python virtualenv
3. Install PyTorch + Typhoon ASR into `.venv`
4. Download the model automatically into `.cache/huggingface`
5. Warm and validate the local Typhoon worker
6. Configure global hotkeys (`Meta+H`)
7. Set up autostart on login and prewarm the worker

> Restart your session if shortcuts don't work immediately.
> The first install requires internet access to download Python packages and model weights.

---

## ⌨️ Usage

| Shortcut | Action |
| :--- | :--- |
| `Meta + H` | **Start / Stop** recording |
| `Meta + Shift + H` | **Toggle dictation profile** (`Smart Mix` ↔ `Raw`) |

### How it works

1. Optional: press `Meta + Shift + H` to switch between `Smart Mix` and `Raw`.
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
| `TYPHOON_MODEL` | `scb10x/typhoon-asr-realtime` | Local Typhoon model name |
| `TYPHOON_DEVICE` | `auto` | Runtime device (`cpu`, `auto`, `cuda`) |
| `TYPHOON_CPU_THREADS` | `16` | CPU threads for PyTorch / Typhoon |
| `TYPHOON_HF_HOME` | `.cache/huggingface` | Local model/cache directory used by Hugging Face |
| `TYPHOON_PROFILE_DEFAULT` | `smart` | Default dictation profile (`smart`, `raw`) |
| `TYPHOON_REPLACEMENTS_FILE` | `typhoon_replacements.tsv` | Optional custom replacements for smart mode |
| `ARECORD_DEVICE` | *(empty)* | ALSA mic override (find with `arecord -L`) |
| `TYPE_DELAY` | `6` | Typing delay for xdotool fallback |
| `POPUP_ENABLED` | `true` | Show/hide status overlay |

---

## 📂 Project Structure

```
LinuxVoiceTyping/
├── autostart.sh       # Starts hotkeys and prewarms the Typhoon worker
├── agent.py           # Main controller (start/stop toggle)
├── popup.py           # Minimal UI overlay (tkinter)
├── transcribe.sh      # Shell wrapper around the Typhoon client
├── type.sh            # Text output (clipboard paste)
├── toggle_lang.sh     # Dictation profile switcher
├── typhoon_backend.py # Shared Typhoon service client helpers
├── typhoon_client.py  # CLI client for the local Typhoon worker
├── typhoon_service.py # Persistent local Typhoon worker
├── typhoon_replacements.tsv # Optional smart-mode replacements
├── config.env         # User settings
├── config.env.example # Settings template
├── install.sh         # One-shot installer
└── .cache/            # Git-ignored model/cache directory
```

---

## 🛠️ Troubleshooting

| Problem | Solution |
| :--- | :--- |
| No sound recorded | Check mic input in System Settings or `arecord -L` |
| Text not appearing | Target app may block paste — try a different app |
| Popup missing | Install `python3-tk`: `sudo apt install python3-tk` |
| Installer downloaded a lot of files | Typhoon/NVIDIA NeMo dependencies are large; this is expected on the first install |
| Slow first transcription | The worker may still be downloading or warming the model; wait for the first run to finish |
| Mixed Thai-English terms look wrong | Add overrides in `typhoon_replacements.tsv` and stay in `Smart Mix` mode |
| Smart mode changes text too much | Press `Meta+Shift+H` to switch to `Raw` |

**Logs**:
- `/tmp/agent_debug.log` for the hotkey controller
- `/tmp/voice_agent_typhoon.log` for the Typhoon worker

---

## 📄 License

MIT
