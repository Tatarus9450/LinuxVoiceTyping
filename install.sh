#!/usr/bin/env bash
set -euo pipefail

# ── Colors ──
G='\033[0;32m'  Y='\033[1;33m'  R='\033[0;31m'  B='\033[1;34m'  NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_STEPS=7

step() { echo -e "\n${B}[$1/$TOTAL_STEPS]${NC} ${Y}$2${NC}"; }
ok()   { echo -e "  ${G}✓ $1${NC}"; }
fail() { echo -e "  ${R}✗ $1${NC}"; exit 1; }
skip() { echo -e "  ${G}⏭ $1 (already done)${NC}"; }

# ── Header ──
echo ""
echo -e "${G}╔══════════════════════════════════════════╗${NC}"
echo -e "${G}║   Linux Voice Typing — Auto Installer    ║${NC}"
echo -e "${G}╚══════════════════════════════════════════╝${NC}"
echo -e "  Project: ${Y}$SCRIPT_DIR${NC}"
echo ""

# ── 1. Pre-flight check ──
step 1 "Checking system..."

if ! command -v apt &>/dev/null; then
    fail "apt not found. This installer requires a Debian/Ubuntu-based distro."
fi

ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" ]]; then
    echo -e "  ${Y}⚠ Architecture: $ARCH (untested, may still work)${NC}"
else
    ok "Architecture: x86_64"
fi

ok "OS: $(lsb_release -ds 2>/dev/null || echo 'Linux')"

# ── 2. System Dependencies ──
step 2 "Installing system packages..."

PACKAGES=(
    git build-essential cmake          # Build tools
    ffmpeg                             # Audio processing
    xdotool xclip                      # Text injection
    alsa-utils                         # arecord
    libnotify-bin                      # notify-send
    python3-tk                         # Popup UI
    xbindkeys                          # Global hotkeys
    libvulkan-dev glslc                # Vulkan GPU acceleration
)

sudo apt update -qq
sudo apt install -y "${PACKAGES[@]}" -qq
ok "All packages installed"

# ── 3. Configuration ──
step 3 "Setting up config..."

if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    [ -f "$SCRIPT_DIR/config.env.example" ] || fail "config.env.example missing!"
    cp "$SCRIPT_DIR/config.env.example" "$SCRIPT_DIR/config.env"
    sed -i "s|WHISPER_MODEL=\"./whisper.cpp/models/ggml-medium.bin\"|WHISPER_MODEL=\"$SCRIPT_DIR/whisper.cpp/models/ggml-medium.bin\"|" "$SCRIPT_DIR/config.env"
    ok "Created config.env"
else
    skip "config.env exists"
fi

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
sed -i "s|WHISPER_THREADS=\"[0-9]*\"|WHISPER_THREADS=\"$NPROC\"|" "$SCRIPT_DIR/config.env"
ok "Set threads: $NPROC"

# ── 4. Clone & Build whisper.cpp ──
step 4 "Setting up whisper.cpp..."

if [ ! -d "$SCRIPT_DIR/whisper.cpp" ]; then
    git clone --depth 1 https://github.com/ggerganov/whisper.cpp "$SCRIPT_DIR/whisper.cpp"
    ok "Cloned whisper.cpp"
else
    skip "whisper.cpp directory exists"
fi

if [ ! -f "$SCRIPT_DIR/whisper.cpp/build/bin/whisper-cli" ]; then
    cd "$SCRIPT_DIR/whisper.cpp"
    echo -e "  Building with Vulkan GPU support (this may take a few minutes)..."
    cmake -B build -DGGML_VULKAN=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON 2>&1 | tail -1
    cmake --build build --config Release -j "$NPROC" 2>&1 | tail -1
    cd "$SCRIPT_DIR"
    [ -f "$SCRIPT_DIR/whisper.cpp/build/bin/whisper-cli" ] || fail "Build failed!"
    ok "Built whisper-cli (Vulkan enabled)"
else
    skip "whisper-cli already built"
fi

# ── 5. Download AI Model ──
step 5 "Downloading AI model (ggml-medium.bin, ~1.5 GB)..."

if [ ! -f "$SCRIPT_DIR/whisper.cpp/models/ggml-medium.bin" ]; then
    bash "$SCRIPT_DIR/whisper.cpp/models/download-ggml-model.sh" medium
    ok "Model downloaded"
else
    skip "Model already exists"
fi

# ── 6. Permissions ──
step 6 "Setting file permissions..."

chmod +x "$SCRIPT_DIR/agent.py"
chmod +x "$SCRIPT_DIR/transcribe.sh"
chmod +x "$SCRIPT_DIR/record.sh"
chmod +x "$SCRIPT_DIR/type.sh"
chmod +x "$SCRIPT_DIR/toggle_lang.sh"
ok "All scripts executable"

# ── 7. Hotkeys & Autostart ──
step 7 "Configuring global shortcuts..."

XB_FILE="$HOME/.xbindkeysrc"

# Create file if it doesn't exist
touch "$XB_FILE"

if ! grep -q "LinuxVoiceTyping/agent.py" "$XB_FILE" 2>/dev/null; then
    cat <<EOF >> "$XB_FILE"

# ── Linux Voice Typing ──
# Meta+H = Start/Stop Recording
"python3 $SCRIPT_DIR/agent.py"
  Mod4+h

# Meta+Shift+H = Toggle Language (TH/EN)
"$SCRIPT_DIR/toggle_lang.sh"
  Mod4+Shift+h
EOF
    ok "Shortcuts added to ~/.xbindkeysrc"
else
    skip "Shortcuts already in ~/.xbindkeysrc"
fi

# Autostart
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat <<EOF > "$AUTOSTART_DIR/linux-voice-typing.desktop"
[Desktop Entry]
Type=Application
Name=Linux Voice Typing (Hotkeys)
Exec=xbindkeys
Comment=Global hotkeys for Linux Voice Typing
X-GNOME-Autostart-enabled=true
EOF
ok "Autostart configured"

# Reload xbindkeys
killall xbindkeys 2>/dev/null || true
if xbindkeys 2>/dev/null; then
    ok "xbindkeys reloaded"
else
    echo -e "  ${Y}⚠ Could not start xbindkeys (will work after relogin)${NC}"
fi

# ── Done ──
echo ""
echo -e "${G}╔══════════════════════════════════════════╗${NC}"
echo -e "${G}║         Installation Complete! 🎉        ║${NC}"
echo -e "${G}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${Y}Meta + H${NC}           Start / Stop Recording"
echo -e "  ${Y}Meta + Shift + H${NC}   Toggle Thai 🇹🇭 / English 🇺🇸"
echo ""
echo -e "  Config: ${Y}$SCRIPT_DIR/config.env${NC}"
echo -e "  Logs:   ${Y}/tmp/agent_debug.log${NC}"
echo ""
echo -e "  ${G}Tip:${NC} Restart session if shortcuts don't work immediately."
echo ""
