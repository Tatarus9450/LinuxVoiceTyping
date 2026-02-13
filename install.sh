#!/usr/bin/env bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Updating package list...${NC}"
sudo apt update

echo -e "${GREEN}Installing dependencies...${NC}"
sudo apt install -y \
  git build-essential ffmpeg xdotool alsa-utils xclip libnotify-bin cmake python3-tk \
  python3 python3-venv

echo -e "${GREEN}Setting up project directory...${NC}"
mkdir -p ~/voice-agent
cd ~/voice-agent

if [ ! -d "whisper.cpp" ]; then
    echo -e "${GREEN}Cloning whisper.cpp...${NC}"
    git clone https://github.com/ggerganov/whisper.cpp
else
    echo -e "${GREEN}whisper.cpp already exists, skipping clone.${NC}"
fi

echo -e "${GREEN}Building whisper.cpp...${NC}"
cd whisper.cpp
make -j

echo -e "${GREEN}Downloading Whisper model (medium)...${NC}"
bash ./models/download-ggml-model.sh medium

echo -e "${GREEN}Setup complete!${NC}"
