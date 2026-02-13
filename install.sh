#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Linux Voice Agent Installer ===${NC}"

# 1. System Dependencies
echo -e "${YELLOW}[1/6] Installing System Dependencies...${NC}"
sudo apt update -qq
sudo apt install -y git build-essential ffmpeg xdotool alsa-utils xclip libnotify-bin cmake python3-tk python3-venv xbindkeys

# 2. Configuration
echo -e "${YELLOW}[2/6] Setup Configuration...${NC}"
if [ ! -f "$SCRIPT_DIR/config.env" ]; then
    if [ -f "$SCRIPT_DIR/config.env.example" ]; then
        cp "$SCRIPT_DIR/config.env.example" "$SCRIPT_DIR/config.env"
        echo -e "${GREEN}Created config.env from example.${NC}"
        # Update model path to be absolute or relative correctly
        sed -i 's|WHISPER_MODEL="./whisper.cpp/models/ggml-medium.bin"|WHISPER_MODEL="'"$SCRIPT_DIR"'/whisper.cpp/models/ggml-medium.bin"|' "$SCRIPT_DIR/config.env"
    else
        echo -e "${RED}config.env.example not found!${NC}"
    fi
else
    echo -e "${GREEN}config.env already exists.${NC}"
fi

# 3. Whisper.cpp Setup
echo -e "${YELLOW}[3/6] Setting up Whisper.cpp...${NC}"
if [ ! -d "$SCRIPT_DIR/whisper.cpp" ]; then
    git clone https://github.com/ggerganov/whisper.cpp "$SCRIPT_DIR/whisper.cpp"
fi

cd "$SCRIPT_DIR/whisper.cpp"
if [ ! -f "build/bin/whisper-cli" ] && [ ! -f "main" ]; then
    echo "Building whisper.cpp..."
    make -j
fi

# 4. Model Download
echo -e "${YELLOW}[4/6] Downloading Model...${NC}"
if [ ! -f "models/ggml-medium.bin" ]; then
    bash ./models/download-ggml-model.sh medium
else
    echo -e "${GREEN}Model already exists.${NC}"
fi
cd "$SCRIPT_DIR"

# 5. Shortcuts (xbindkeys)
echo -e "${YELLOW}[5/6] Configuring Shortcuts...${NC}"
XB_FILE="$HOME/.xbindkeysrc"
if ! grep -q "LinuxVoiceTyping/agent.py" "$XB_FILE" 2>/dev/null; then
    echo "Adding shortcuts to $XB_FILE..."
    cat <<EOF >> "$XB_FILE"

# Voice Agent Shortcut
"python3 $SCRIPT_DIR/agent.py"
  m:0x50 + c:43
  Mod4+h

# Voice Agent Language Toggle
"$SCRIPT_DIR/toggle_lang.sh"
  m:0x50 + c:43 + Shift
  Mod4+Shift+h
EOF
else
    echo -e "${GREEN}Shortcuts already configured.${NC}"
fi

# 6. Autostart
echo -e "${YELLOW}[6/6] Configuring Autostart...${NC}"
AUTOStart_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOStart_DIR"
cat <<EOF > "$AUTOStart_DIR/xbindkeys.desktop"
[Desktop Entry]
Type=Application
Name=Xbindkeys (Voice Agent)
Exec=xbindkeys
Comment=Global Shortcuts
X-GNOME-Autostart-enabled=true
EOF

# Reload xbindkeys
killall xbindkeys 2>/dev/null || true
xbindkeys

echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo -e "You can now use:"
echo -e "  ${YELLOW}Meta + H${NC}       to Start/Stop Recording"
echo -e "  ${YELLOW}Meta + Shift + H${NC} to Toggle Language"
echo -e ""
echo -e "Please restart your computer if shortcuts don't work immediately."
