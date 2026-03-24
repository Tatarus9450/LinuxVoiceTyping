#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
XB_FILE="${HOME}/.xbindkeysrc"

# Ensure a single xbindkeys instance owns the global shortcuts.
pkill -x xbindkeys >/dev/null 2>&1 || true
xbindkeys -f "$XB_FILE" >/dev/null 2>&1 || true

# Start the Typhoon worker in the background so the first dictation is warm.
python3 "$SCRIPT_DIR/typhoon_client.py" --ensure-service --no-wait >/dev/null 2>&1 || true
