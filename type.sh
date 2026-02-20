#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
source "$SCRIPT_DIR/config.env"

TXT_FILE="${1:-/tmp/voice_agent.txt}"
TEXT="$(cat "$TXT_FILE" 2>/dev/null || true)"

if [[ -z "$TEXT" ]]; then
  notify-send "Voice Agent" "No text recognized."
  exit 0
fi

# Prioritize clipboard paste to avoid keyboard layout mapping issues (especially for Thai)
printf "%s" "$TEXT" | xclip -selection clipboard

# Primary: Ctrl+V paste (works with Thai and Unicode correctly)
if xdotool key --clearmodifiers ctrl+v; then
  exit 0
fi

# Fallback: xdotool type (may not work well with Thai)
xdotool type --delay "$TYPE_DELAY" -- "$TEXT" 2>/dev/null
