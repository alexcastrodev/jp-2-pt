#!/bin/bash
set -e

INPUT_FILE="/app/input/$1"
BASENAME=$(basename "$1" | cut -d. -f1)
AUDIO_FILE="/tmp/audio.wav"
TRANSCRIPTION_JA="/tmp/$BASENAME.txt"
TRANSLATED_PT="/tmp/$BASENAME.pt.txt"
SRT_FILE="/app/output/$BASENAME.pt.srt"

echo "[1/5] 🔤 Instalando modelo de tradução (ja → pt)..."
argos-translate-cli --install translate-ja_pt

echo "[2/5] 🎧 Extraindo áudio..."
ffmpeg -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$AUDIO_FILE" -y

echo "[3/5] ✍️ Transcrevendo com Whisper..."
whisper "$AUDIO_FILE" --language Japanese --output_format txt --output_dir /tmp --model base

echo "[4/5] 🌍 Traduzindo para português..."
argospm translate --from-lang ja --to-lang pt < "$TRANSCRIPTION_JA" > "$TRANSLATED_PT"

echo "[5/5] 📝 Convertendo para SRT (simplificado)..."
i=0
while IFS= read -r line; do
  start=$((i * 5))
  end=$(((i + 1) * 5))
  printf "%d\n%02d:%02d:%02d,000 --> %02d:%02d:%02d,000\n%s\n\n" \
    "$((i+1))" $((start/3600)) $(((start%3600)/60)) $((start%60)) \
    $((end/3600)) $(((end%3600)/60)) $((end%60)) "$line"
  i=$((i+1))
done < "$TRANSLATED_PT" > "$SRT_FILE"

echo "✅ Legenda gerada: output/$(basename "$SRT_FILE")"
