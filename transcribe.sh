#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
source "$SCRIPT_DIR/config.env"

WAV="${1:-$AUDIO_WAV}"
OUT_TXT="/tmp/voice_agent.txt"

rm -f "$OUT_TXT"

python3 "$SCRIPT_DIR/typhoon_client.py" "$WAV" --output "$OUT_TXT"

echo "$OUT_TXT"
