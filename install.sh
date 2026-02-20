#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Linux Voice Agent Installer ===${NC}"
echo -e "Installing into: ${YELLOW}$SCRIPT_DIR${NC}"

# 1. System Dependencies
echo -e "${YELLOW}[1/6] Installing System Dependencies...${NC}"
sudo apt update -qq
sudo apt install -y git build-essential ffmpeg xdotool alsa-utils xclip libnotify-bin cmake python3-tk python3-venv xbindkeys libvulkan-dev glslc

# 2. Configuration
echo -e "${YELLOW}[2/6] Setup Configuration...${NC}"
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    if [ -f "$SCRIPT_DIR/config.env.example" ]; then
        cp "$SCRIPT_DIR/config.env.example" "$SCRIPT_DIR/config.env"
        # Update model path to absolute
        sed -i "s|WHISPER_MODEL=\"./whisper.cpp/models/ggml-medium.bin\"|WHISPER_MODEL=\"$SCRIPT_DIR/whisper.cpp/models/ggml-medium.bin\"|" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}Created config.env from example.${NC}"
    else
        echo -e "${RED}config.env.example not found!${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}config.env already exists. Skipping.${NC}"
fi

# 3. Whisper.cpp Setup
echo -e "${YELLOW}[3/6] Setting up Whisper.cpp...${NC}"
if [ ! -d "$SCRIPT_DIR/whisper.cpp" ]; then
    git clone https://github.com/ggerganov/whisper.cpp "$SCRIPT_DIR/whisper.cpp"
fi

cd "$SCRIPT_DIR/whisper.cpp"
if [ ! -f "build/bin/whisper-cli" ]; then
    echo "Building whisper.cpp..."
    cmake -B build -DGGML_VULKAN=ON -DWHISPER_BUILD_TESTS=OFF
    cmake --build build --config Release -j "$(nproc)"
fi
cd "$SCRIPT_DIR"

# 4. Model Download
echo -e "${YELLOW}[4/6] Downloading Whisper Model...${NC}"
if [ ! -f "$SCRIPT_DIR/whisper.cpp/models/ggml-medium.bin" ]; then
    bash "$SCRIPT_DIR/whisper.cpp/models/download-ggml-model.sh" medium
else
    echo -e "${GREEN}Model already exists. Skipping.${NC}"
fi

# 5. Make scripts executable
echo -e "${YELLOW}[5/6] Setting permissions...${NC}"
chmod +x "$SCRIPT_DIR/agent.py"
chmod +x "$SCRIPT_DIR/transcribe.sh"
chmod +x "$SCRIPT_DIR/record.sh"
chmod +x "$SCRIPT_DIR/type.sh"
chmod +x "$SCRIPT_DIR/toggle_lang.sh"

# 6. Shortcuts (xbindkeys)
echo -e "${YELLOW}[6/6] Configuring Shortcuts & Autostart...${NC}"
XB_FILE="$HOME/.xbindkeysrc"
if ! grep -q "LinuxVoiceTyping/agent.py" "$XB_FILE" 2>/dev/null; then
    echo "Adding shortcuts to $XB_FILE..."
    cat <<EOF >> "$XB_FILE"

# Voice Agent Shortcut (Meta+H = Start/Stop Recording)
"python3 $SCRIPT_DIR/agent.py"
  m:0x50 + c:43
  Mod4+h

# Voice Agent Language Toggle (Meta+Shift+H = Toggle TH/EN)
"$SCRIPT_DIR/toggle_lang.sh"
  m:0x50 + c:43 + Shift
  Mod4+Shift+h
EOF
    echo -e "${GREEN}Shortcuts added.${NC}"
else
    echo -e "${GREEN}Shortcuts already configured.${NC}"
fi

# Autostart xbindkeys on login
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat <<EOF > "$AUTOSTART_DIR/xbindkeys-linux-voice-typing.desktop"
[Desktop Entry]
Type=Application
Name=Xbindkeys (Voice Agent)
Exec=xbindkeys
Comment=Global hotkeys for Linux Voice Typing Agent
X-GNOME-Autostart-enabled=true
EOF

# Reload xbindkeys
killall xbindkeys 2>/dev/null || true
xbindkeys && echo -e "${GREEN}xbindkeys reloaded.${NC}"

echo ""
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo -e "Use the following shortcuts:"
echo -e "  ${YELLOW}Meta + H${NC}         → Start / Stop Recording"
echo -e "  ${YELLOW}Meta + Shift + H${NC} → Toggle Language (Thai 🇹🇭 / English 🇺🇸)"
echo -e ""
echo -e "Config file: ${YELLOW}$SCRIPT_DIR/config.env${NC}"
echo -e "If shortcuts don't work, try restarting your session."
