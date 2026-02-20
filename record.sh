#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
source "$SCRIPT_DIR/config.env"

DURATION="${1:-$REC_SECONDS_DEFAULT}"

# Clean old file
rm -f "$AUDIO_WAV"

# Build arecord command
if [[ -n "${ARECORD_DEVICE}" ]]; then
  arecord -D "${ARECORD_DEVICE}" -f cd -t wav -d "$DURATION" "$AUDIO_WAV"
else
  arecord -f cd -t wav -d "$DURATION" "$AUDIO_WAV"
fi
