#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
source "$SCRIPT_DIR/config.env"

TXT_FILE="${1:-/tmp/voice_agent.txt}"
TEXT="$(cat "$TXT_FILE" 2>/dev/null || true)"
PREVIOUS_CLIPBOARD_FILE=""
KLIPPER_STATE_FILE=""
RESTORE_DELAY="${CLIPBOARD_RESTORE_DELAY:-0.15}"

if [[ -z "$TEXT" ]]; then
  notify-send "Voice Agent" "No text recognized."
  exit 0
fi

cleanup_previous_clipboard_file() {
  if [[ -n "$PREVIOUS_CLIPBOARD_FILE" && -f "$PREVIOUS_CLIPBOARD_FILE" ]]; then
    rm -f "$PREVIOUS_CLIPBOARD_FILE"
  fi
  if [[ -n "$KLIPPER_STATE_FILE" && -f "$KLIPPER_STATE_FILE" ]]; then
    rm -f "$KLIPPER_STATE_FILE"
  fi
}

has_klipper() {
  command -v qdbus >/dev/null 2>&1 && qdbus org.kde.klipper /klipper >/dev/null 2>&1
}

snapshot_clipboard() {
  if has_klipper; then
    KLIPPER_STATE_FILE="$(mktemp)"
    python3 - "$KLIPPER_STATE_FILE" <<'PY'
import json
import subprocess
import sys

state_path = sys.argv[1]

def qdbus_call(method: str, *args: str) -> str:
    proc = subprocess.run(
        ["qdbus", "org.kde.klipper", "/klipper", method, *args],
        text=True,
        capture_output=True,
        check=False,
    )
    return proc.stdout

history: list[str] = []
for index in range(200):
    item = qdbus_call("org.kde.klipper.klipper.getClipboardHistoryItem", str(index))
    if item in {"", "\n"}:
        break
    history.append(item[:-1] if item.endswith("\n") else item)

state = {
    "history": history,
}

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(state, handle, ensure_ascii=False)
PY
    return
  fi

  PREVIOUS_CLIPBOARD_FILE="$(mktemp)"
  if ! xclip -selection clipboard -o >"$PREVIOUS_CLIPBOARD_FILE" 2>/dev/null; then
    rm -f "$PREVIOUS_CLIPBOARD_FILE"
    PREVIOUS_CLIPBOARD_FILE=""
  fi
}

restore_clipboard() {
  sleep "$RESTORE_DELAY"

  if [[ -n "$KLIPPER_STATE_FILE" && -f "$KLIPPER_STATE_FILE" ]]; then
    python3 - "$KLIPPER_STATE_FILE" <<'PY'
import json
import subprocess
import sys

state_path = sys.argv[1]

with open(state_path, encoding="utf-8") as handle:
    state = json.load(handle)

history = state.get("history") or []

subprocess.run(
    ["qdbus", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.clearClipboardHistory"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
)

if history:
    for item in reversed(history):
        subprocess.run(
            ["qdbus", "org.kde.klipper", "/klipper", "org.kde.klipper.klipper.setClipboardContents", item],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
else:
    subprocess.run(
        ["xclip", "-selection", "clipboard"],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
PY
    cleanup_previous_clipboard_file
    return
  fi

  if [[ -n "$PREVIOUS_CLIPBOARD_FILE" && -f "$PREVIOUS_CLIPBOARD_FILE" ]]; then
    xclip -selection clipboard <"$PREVIOUS_CLIPBOARD_FILE" 2>/dev/null || true
    cleanup_previous_clipboard_file
    return
  fi

  if has_klipper; then
    xclip -selection clipboard </dev/null 2>/dev/null || true
  else
    printf '' | xclip -selection clipboard 2>/dev/null || true
  fi
}

trap cleanup_previous_clipboard_file EXIT

snapshot_clipboard

# Prioritize clipboard paste to avoid keyboard layout mapping issues (especially for Thai)
printf "%s" "$TEXT" | xclip -selection clipboard

# Primary: Ctrl+V paste (works with Thai and Unicode correctly)
if xdotool key --clearmodifiers ctrl+v; then
  restore_clipboard
  exit 0
fi

# Fallback: xdotool type (may not work well with Thai)
xdotool type --delay "$TYPE_DELAY" -- "$TEXT" 2>/dev/null
restore_clipboard
