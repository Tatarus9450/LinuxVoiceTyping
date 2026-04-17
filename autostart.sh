#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
XB_FILE="${HOME}/.xbindkeysrc"
SESSION_TYPE="$(printf '%s' "${XDG_SESSION_TYPE:-x11}" | tr '[:upper:]' '[:lower:]')"

if [[ "$SESSION_TYPE" == "x11" ]]; then
    # Ensure a single xbindkeys instance owns the global shortcuts on X11.
    pkill -x xbindkeys >/dev/null 2>&1 || true
    xbindkeys -f "$XB_FILE" >/dev/null 2>&1 || true
else
    # Wayland sessions use DE-native shortcuts; ydotoold is only a fallback.
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user start ydotool.service >/dev/null 2>&1 || true
        systemctl --user start ydotoold.service >/dev/null 2>&1 || true
    fi
fi

# Start the Typhoon worker in the background so the first dictation is warm.
python3 "$SCRIPT_DIR/typhoon_client.py" --ensure-service --no-wait >/dev/null 2>&1 || true
