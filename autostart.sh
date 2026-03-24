#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
XB_FILE="${HOME}/.xbindkeysrc"

# xbindkeys daemonizes on success. Only start it if it is not already running.
if ! pgrep -x xbindkeys >/dev/null 2>&1; then
  xbindkeys -f "$XB_FILE" >/dev/null 2>&1 || true
fi

# Start the Typhoon worker in the background so the first dictation is warm.
python3 "$SCRIPT_DIR/typhoon_client.py" --ensure-service --no-wait >/dev/null 2>&1 || true
