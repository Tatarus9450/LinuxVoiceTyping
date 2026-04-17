#!/usr/bin/env bash
set -euo pipefail

# Cycle dictation profile: Smart Mix -> Raw -> TH to ENG
# Triggered by: Meta + Shift + H

PROFILE_FILE="/tmp/voice_agent_profile"

if [ ! -f "$PROFILE_FILE" ]; then
    echo "smart" > "$PROFILE_FILE"
fi

CURRENT=$(tr -d '[:space:]' < "$PROFILE_FILE")

if [ "$CURRENT" == "smart" ]; then
    echo "raw" > "$PROFILE_FILE"
    notify-send "Voice Agent" "Dictation mode: Raw"
elif [ "$CURRENT" == "raw" ]; then
    echo "th_to_eng" > "$PROFILE_FILE"
    notify-send "Voice Agent" "Dictation mode: TH to ENG"
else
    echo "smart" > "$PROFILE_FILE"
    notify-send "Voice Agent" "Dictation mode: Smart Mix"
fi
