#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──
G='\033[0;32m'  Y='\033[1;33m'  R='\033[0;31m'  B='\033[1;34m'  NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
HF_HOME_DIR="$SCRIPT_DIR/.cache/huggingface"
AUTOSTART_SCRIPT="$SCRIPT_DIR/autostart.sh"
TOTAL_STEPS=9

step() { echo -e "\n${B}[$1/$TOTAL_STEPS]${NC} ${Y}$2${NC}"; }
ok()   { echo -e "  ${G}✓ $1${NC}"; }
fail() { echo -e "  ${R}✗ $1${NC}"; exit 1; }
skip() { echo -e "  ${G}⏭ $1 (already done)${NC}"; }
warn() { echo -e "  ${Y}⚠ $1${NC}"; }
need_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing command: $1"
}
escape_sed() {
    printf '%s' "$1" | sed 's/[\/&]/\\&/g'
}
upsert_env_key() {
    local key="$1"
    local value="$2"
    local file="$3"
    local escaped
    escaped="$(escape_sed "$value")"
    if grep -q "^${key}=" "$file"; then
        sed -i "s|^${key}=.*|${key}=\"${escaped}\"|" "$file"
    else
        printf '%s="%s"\n' "$key" "$value" >> "$file"
    fi
}
replace_managed_block() {
    local file="$1"
    local begin="$2"
    local end="$3"
    local content="$4"
    local tmp
    tmp="$(mktemp)"

    if [ -f "$file" ]; then
        awk -v begin="$begin" -v end="$end" '
            $0 == begin { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "$file" > "$tmp"
    else
        : > "$tmp"
    fi

    printf '\n%s\n%s\n%s\n' "$begin" "$content" "$end" >> "$tmp"
    mv "$tmp" "$file"
}
version_at_least() {
    local current="$1"
    local minimum="$2"
    dpkg --compare-versions "$current" ge "$minimum"
}

# ── Header ──
echo ""
echo -e "${G}╔══════════════════════════════════════════╗${NC}"
echo -e "${G}║ Linux Voice Typing — Install / Repair    ║${NC}"
echo -e "${G}╚══════════════════════════════════════════╝${NC}"
echo -e "  Project: ${Y}$SCRIPT_DIR${NC}"
echo ""

# ── 1. Pre-flight check ──
step 1 "Checking system..."

need_cmd uname
need_cmd python3

if ! command -v apt >/dev/null 2>&1; then
    fail "apt not found. This installer requires a Debian/Ubuntu-based distro."
fi

if ! command -v sudo >/dev/null 2>&1; then
    fail "sudo is required for dependency installation."
fi

sudo -v || fail "sudo authentication failed."

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    warn "Architecture: $ARCH (untested, may still work)"
else
    ok "Architecture: x86_64"
fi

ok "OS: $(lsb_release -ds 2>/dev/null || echo 'Linux')"

PYTHON_VERSION="$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')"
version_at_least "$PYTHON_VERSION" "3.10" || fail "Python 3.10+ is required (found $PYTHON_VERSION)"
ok "Python: $PYTHON_VERSION"

AVAILABLE_GB="$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {gsub(/G/, "", $4); print $4}')"
if [[ -n "$AVAILABLE_GB" ]] && (( AVAILABLE_GB < 8 )); then
    fail "At least 8 GB of free disk space is recommended; only ${AVAILABLE_GB}G available."
fi
ok "Disk available: ${AVAILABLE_GB:-unknown}G"

if [[ -n "${XDG_SESSION_TYPE:-}" && "${XDG_SESSION_TYPE:-}" != "x11" ]]; then
    warn "Current session is '${XDG_SESSION_TYPE}'. xdotool/xbindkeys work best on X11."
fi

# ── 2. System Dependencies ──
step 2 "Installing system packages..."

PACKAGES=(
    git                                 # Fetching repositories
    ffmpeg                             # Audio processing
    sox                                # Audio utilities for ASR deps
    xdotool xclip                      # Text injection
    alsa-utils                         # arecord
    libnotify-bin                      # notify-send
    python3-tk                         # Popup UI
    python3-venv python3-pip           # Isolated Python env
    xbindkeys                          # Global hotkeys
)

sudo apt update -qq
sudo apt install -y "${PACKAGES[@]}" -qq

for cmd in ffmpeg arecord xclip xdotool notify-send xbindkeys python3; do
    need_cmd "$cmd"
done
ok "All packages installed"

# ── 3. Configuration ──
step 3 "Preparing project state..."

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    [ -f "$SCRIPT_DIR/config.env.example" ] || fail "config.env.example missing!"
    cp "$SCRIPT_DIR/config.env.example" "$SCRIPT_DIR/config.env"
    ok "Created config.env"
else
    skip "config.env exists"
fi

mkdir -p "$SCRIPT_DIR/.cache" "$HF_HOME_DIR"
ok "Created cache directories"

# Auto-detect microphone
if grep -q 'ARECORD_DEVICE=""' "$SCRIPT_DIR/config.env"; then
    DEFAULT_MIC=$(arecord -L 2>/dev/null | grep '^sysdefault:' | head -1 || true)
    if [[ -n "$DEFAULT_MIC" ]]; then
        sed -i "s|ARECORD_DEVICE=\"\"|ARECORD_DEVICE=\"$DEFAULT_MIC\"|" "$SCRIPT_DIR/config.env"
        ok "Auto-detected mic: $DEFAULT_MIC"
    else
        ok "Using system default mic"
    fi
fi

# Auto-set threads to CPU count
NPROC=$(nproc 2>/dev/null || echo 4)
THREADS="$NPROC"

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
    TORCH_CHANNEL="cuda"
    ok "NVIDIA GPU detected; installer will use CUDA-enabled PyTorch"
else
    TORCH_CHANNEL="cpu"
    ok "No NVIDIA GPU detected; installer will use CPU-optimized PyTorch"
fi

upsert_env_key "TYPHOON_MODEL" "scb10x/typhoon-asr-realtime" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_DEVICE" "auto" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_CPU_THREADS" "$THREADS" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_VENV" "$VENV_DIR" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_HF_HOME" "$HF_HOME_DIR" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_PROFILE_DEFAULT" "smart" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_REQUEST_TIMEOUT" "120" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_STARTUP_TIMEOUT" "180" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_FFMPEG_TIMEOUT" "30" "$SCRIPT_DIR/config.env"
upsert_env_key "TYPHOON_REPLACEMENTS_FILE" "$SCRIPT_DIR/typhoon_replacements.tsv" "$SCRIPT_DIR/config.env"
upsert_env_key "ARECORD_FORMAT" "S16_LE" "$SCRIPT_DIR/config.env"
upsert_env_key "ARECORD_CHANNELS" "1" "$SCRIPT_DIR/config.env"
upsert_env_key "ARECORD_RATE" "16000" "$SCRIPT_DIR/config.env"
ok "Configured Typhoon with $THREADS CPU threads"

# ── 4. Python Environment ──
step 4 "Creating Python environment..."

if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
    ok "Created .venv"
else
    skip "Python virtual environment exists"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip wheel 'setuptools>=79,<82' >/dev/null
ok "Upgraded pip tooling"

# ── 5. Install Typhoon ASR ──
step 5 "Installing Python dependencies..."

if [[ "$TORCH_CHANNEL" == "cuda" ]]; then
    "$VENV_DIR/bin/pip" install --upgrade torch==2.11.0 torchaudio==2.11.0
else
    "$VENV_DIR/bin/pip" install --upgrade \
        --index-url https://download.pytorch.org/whl/cpu \
        --extra-index-url https://pypi.org/simple \
        torch==2.11.0 torchaudio==2.11.0
fi
"$VENV_DIR/bin/pip" install --upgrade typhoon-asr==0.1.1
ok "Installed Typhoon ASR dependencies"

# ── 6. Download Model ──
step 6 "Downloading and warming the Typhoon model..."

python3 "$SCRIPT_DIR/typhoon_client.py" --stop-service >/dev/null 2>&1 || true
"$VENV_DIR/bin/python" "$SCRIPT_DIR/typhoon_service.py" --preload-only
ok "Typhoon model cached and warmed"

# ── 7. Validation ──
step 7 "Validating the local runtime..."

"$VENV_DIR/bin/python" - <<'PY'
import importlib
modules = ["torch", "torchaudio", "nemo.collections.asr", "typhoon_asr"]
for name in modules:
    importlib.import_module(name)
print("ok")
PY
"$VENV_DIR/bin/python" "$SCRIPT_DIR/typhoon_client.py" --ensure-service
ok "Typhoon service responds correctly"

# ── 8. Permissions ──
step 8 "Setting file permissions..."

chmod +x "$SCRIPT_DIR/agent.py"
chmod +x "$AUTOSTART_SCRIPT"
chmod +x "$SCRIPT_DIR/typhoon_backend.py"
chmod +x "$SCRIPT_DIR/typhoon_client.py"
chmod +x "$SCRIPT_DIR/typhoon_service.py"
chmod +x "$SCRIPT_DIR/transcribe.sh"
chmod +x "$SCRIPT_DIR/type.sh"
chmod +x "$SCRIPT_DIR/toggle_lang.sh"
ok "All scripts executable"

# ── 9. Hotkeys & Autostart ──
step 9 "Configuring global shortcuts and autostart..."

XB_FILE="$HOME/.xbindkeysrc"
XB_BEGIN="# >>> LinuxVoiceTyping >>>"
XB_END="# <<< LinuxVoiceTyping <<<"
read -r -d '' XB_BLOCK <<EOF || true
# Meta+H = Start/Stop Recording
"python3 $SCRIPT_DIR/agent.py"
  Mod4+h

# Meta+Shift+H = Toggle dictation profile (Smart Mix / Raw)
"$SCRIPT_DIR/toggle_lang.sh"
  Mod4+Shift+h
EOF
replace_managed_block "$XB_FILE" "$XB_BEGIN" "$XB_END" "$XB_BLOCK"
ok "Updated ~/.xbindkeysrc"

# Autostart
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat <<EOF > "$AUTOSTART_DIR/linux-voice-typing.desktop"
[Desktop Entry]
Type=Application
Name=Linux Voice Typing
Exec=$AUTOSTART_SCRIPT
Comment=Start hotkeys and warm the Typhoon worker
X-GNOME-Autostart-enabled=true
EOF
ok "Autostart configured"

# Reload xbindkeys
killall xbindkeys 2>/dev/null || true
if xbindkeys -f "$XB_FILE" 2>/dev/null; then
    ok "xbindkeys reloaded"
else
    warn "Could not start xbindkeys (will work after relogin)"
fi

"$VENV_DIR/bin/python" "$SCRIPT_DIR/typhoon_client.py" --ensure-service --no-wait || true

# ── Done ──
echo ""
echo -e "${G}╔══════════════════════════════════════════╗${NC}"
echo -e "${G}║      Install / Repair Complete! 🎉       ║${NC}"
echo -e "${G}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${Y}Meta + H${NC}           Start / Stop Recording"
echo -e "  ${Y}Meta + Shift + H${NC}   Toggle Smart Mix / Raw"
echo ""
echo -e "  Config: ${Y}$SCRIPT_DIR/config.env${NC}"
echo -e "  Model cache: ${Y}$HF_HOME_DIR${NC}"
echo -e "  Logs:   ${Y}/tmp/agent_debug.log${NC}"
echo -e "  ASR:    ${Y}/tmp/voice_agent_typhoon.log${NC}"
echo ""
echo -e "  ${G}Tip:${NC} Restart session if shortcuts don't work immediately."
echo ""
