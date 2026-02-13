#!/usr/bin/env bash
set -euo pipefail
source "/home/task/Documents/LinuxVoiceTyping/config.env"

TXT_FILE="${1:-/tmp/voice_agent.txt}"
TEXT="$(cat "$TXT_FILE" 2>/dev/null || true)"

if [[ -z "$TEXT" ]]; then
  notify-send "Voice Agent" "No text recognized."
  exit 0
fi

# Prioritize clipboard paste to avoid keyboard layout mapping issues (especially for Thai)
# Save current clipboard (optional, skipping for speed/simplicity)
printf "%s" "$TEXT" | xclip -selection clipboard

# Ctrl+V paste
if xdotool key --clearmodifiers ctrl+v; then
  exit 0
fi

# Fallback: xdotool type
xdotool type --delay "$TYPE_DELAY" -- "$TEXT" 2>/dev/null
