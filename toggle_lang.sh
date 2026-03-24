#!/usr/bin/env bash
# Toggle dictation profile between smart mixed mode and raw output
# Triggered by: Meta + Shift + H

PROFILE_FILE="/tmp/voice_agent_profile"

if [ ! -f "$PROFILE_FILE" ]; then
    echo "smart" > "$PROFILE_FILE"
fi

CURRENT=$(tr -d '[:space:]' < "$PROFILE_FILE")

if [ "$CURRENT" == "smart" ]; then
    echo "raw" > "$PROFILE_FILE"
    notify-send "Voice Agent" "Dictation mode: Raw"
else
    echo "smart" > "$PROFILE_FILE"
    notify-send "Voice Agent" "Dictation mode: Smart Mix"
fi
