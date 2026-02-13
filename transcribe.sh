#!/usr/bin/env bash
set -euo pipefail
source "/home/task/Documents/LinuxVoiceTyping/config.env"

WAV="${1:-$AUDIO_WAV}"
OUT_TXT="/tmp/voice_agent.txt"

rm -f "$OUT_TXT"

# whisper.cpp main outputs to stdout; we'll capture text only.
# -nt: no timestamps
# -l : language
# -m : model
# -f : input file
# Note: Path adjusted to build/bin/whisper-cli based on recent whisper.cpp build structure
# Fix WAV header if corrupt (copying valid audio to new file)
ffmpeg -y -hide_banner -loglevel error -i "$WAV" -c copy "${WAV}_fixed.wav"
FIXED_WAV="${WAV}_fixed.wav"

# Check if language toggle file exists
LANG_FILE="/tmp/voice_agent_lang"
if [ -f "$LANG_FILE" ]; then
    CURRENT_LANG=$(cat "$LANG_FILE")
    # Clean whitespace
    CURRENT_LANG=$(echo "$CURRENT_LANG" | tr -d '[:space:]')
    WHISPER_LANG="$CURRENT_LANG"
fi

if [[ "$WHISPER_LANG" == "auto" ]]; then
  LANG_ARG=""
else
  LANG_ARG="-l $WHISPER_LANG"
fi


timeout 60s "/home/task/Documents/LinuxVoiceTyping/whisper.cpp/build/bin/whisper-cli" \
  -t "$WHISPER_THREADS" \
  -m "$WHISPER_MODEL" \
  $LANG_ARG \
  -f "$FIXED_WAV" \
  -nt \
  > "$OUT_TXT" || { echo "Transcription timed out"; exit 1; }

# Normalize: remove excessive newlines
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("/tmp/voice_agent.txt")
if p.exists():
    t = p.read_text(encoding="utf-8", errors="ignore")
    t = t.replace("\r\n", "\n")
    t = re.sub(r"\n{2,}", "\n", t).strip()
    p.write_text(t, encoding="utf-8")
PY

echo "$OUT_TXT"
