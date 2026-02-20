#!/usr/bin/env bash
# Toggle language between Thai and English
# Triggered by: Meta + Shift + H

LANG_FILE="/tmp/voice_agent_lang"

if [ ! -f "$LANG_FILE" ]; then
    echo "th" > "$LANG_FILE"
fi

CURRENT=$(cat "$LANG_FILE")

if [ "$CURRENT" == "th" ]; then
    echo "en" > "$LANG_FILE"
    notify-send "Voice Agent" "Switched to English 🇺🇸"
else
    echo "th" > "$LANG_FILE"
    notify-send "Voice Agent" "Switched to Thai 🇹🇭"
fi
