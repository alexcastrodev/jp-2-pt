#!/bin/bash
set -e

INPUT_FILE="/app/input/$1"

if [ ! -f "$INPUT_FILE" ]; then
  echo "❌ Arquivo $INPUT_FILE não encontrado. Coloque-o em ./input/"
  exit 1
fi

BASENAME=$(basename "$1" | cut -d. -f1)
WORKDIR="/app/workspace/$BASENAME"

mkdir -p "$WORKDIR" /app/output

AUDIO_FILE="$WORKDIR/audio.wav"
TRANSCRIPTION_JA="$WORKDIR/transcription.ja.txt"
TRANSLATED_EN="$WORKDIR/translated.en.txt"
TRANSLATED_PT="$WORKDIR/translated.pt.txt"

SRT_JA="/app/output/$BASENAME.ja.srt"
SRT_EN="/app/output/$BASENAME.en.srt"
SRT_PT="/app/output/$BASENAME.pt.srt"

echo "📁 Usando pasta de trabalho: $WORKDIR"

# Etapa 0: atualizar índice de pacotes
echo "[0/7] 🌐 Atualizando índice de pacotes Argos..."
python3 -c "import argostranslate.package; argostranslate.package.update_package_index()"

# Etapa 1: instalar modelos
install_model() {
  if ! argospm list | grep -q "$1 -> $2"; then
    echo "📦 Instalando modelo $1 → $2"
    argospm install translate-$1_$2
  else
    echo "📦 Modelo $1 → $2 já instalado"
  fi
}
echo "[1/7] 📦 Verificando modelos necessários..."
install_model ja en
install_model en pt

# Etapa 2: extração de áudio
if [ ! -f "$AUDIO_FILE" ]; then
  echo "[2/7] 🎧 Extraindo áudio..."
  ffmpeg -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$AUDIO_FILE" -y
else
  echo "[2/7] 🎧 Áudio já extraído, pulando..."
fi

# Etapa 3: transcrição
if [ ! -f "$TRANSCRIPTION_JA" ]; then
  echo "[3/7] ✍️ Transcrevendo com Whisper..."
  whisper "$AUDIO_FILE" --language Japanese --output_format txt --output_dir "$WORKDIR" --model base
  mv "$WORKDIR/audio.txt" "$TRANSCRIPTION_JA"
else
  echo "[3/7] ✍️ Transcrição já existente, pulando..."
fi

# Etapa 4: tradução ja → en
if [ ! -f "$TRANSLATED_EN" ]; then
  echo "[4/7] 🌍 Traduzindo Japonês → Inglês..."
  argospm translate --from-lang ja --to-lang en < "$TRANSCRIPTION_JA" > "$TRANSLATED_EN"
else
  echo "[4/7] 🌍 Tradução ja→en já existente, pulando..."
fi

# Etapa 5: tradução en → pt
if [ ! -f "$TRANSLATED_PT" ]; then
  echo "[5/7] 🌍 Traduzindo Inglês → Português..."
  argospm translate --from-lang en --to-lang pt < "$TRANSLATED_EN" > "$TRANSLATED_PT"
else
  echo "[5/7] 🌍 Tradução en→pt já existente, pulando..."
fi

# Etapa 6: gerar SRTs simplificados
generate_srt() {
  INPUT_FILE="$1"
  OUTPUT_FILE="$2"
  echo "📝 Gerando $OUTPUT_FILE..."
  i=0
  while IFS= read -r line; do
    start=$((i * 5))
    end=$(((i + 1) * 5))
    printf "%d\n%02d:%02d:%02d,000 --> %02d:%02d:%02d,000\n%s\n\n" \
      "$((i+1))" $((start/3600)) $(((start%3600)/60)) $((start%60)) \
      $((end/3600)) $(((end%3600)/60)) $((end%60)) "$line"
    i=$((i+1))
  done < "$INPUT_FILE" > "$OUTPUT_FILE"
}

if [ ! -f "$SRT_JA" ]; then generate_srt "$TRANSCRIPTION_JA" "$SRT_JA"; else echo "📝 $SRT_JA já existe."; fi
if [ ! -f "$SRT_EN" ]; then generate_srt "$TRANSLATED_EN" "$SRT_EN"; else echo "📝 $SRT_EN já existe."; fi
if [ ! -f "$SRT_PT" ]; then generate_srt "$TRANSLATED_PT" "$SRT_PT"; else echo "📝 $SRT_PT já existe."; fi

echo "✅ Legendas geradas:"
ls -1 /app/output/*.srt
