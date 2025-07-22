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
SRT_JA="$WORKDIR/audio.srt"
SRT_EN="/app/output/$BASENAME.en.srt"
SRT_PT="/app/output/$BASENAME.pt.srt"
SRT_JA_OUT="/app/output/$BASENAME.ja.srt"

echo "📁 Usando pasta de trabalho: $WORKDIR"

# Etapa 0: atualizar índice
echo "[0/6] 🌐 Atualizando índice de pacotes Argos..."
python3 -c "import argostranslate.package as pkg; pkg.update_package_index()"

# Etapa 1: instalar modelos
install_model() {
  if ! argospm list | grep -q "$1 -> $2"; then
    echo "📦 Instalando modelo $1 → $2"
    argospm install translate-$1_$2
  else
    echo "📦 Modelo $1 → $2 já instalado"
  fi
}
echo "[1/6] 📦 Verificando modelos..."
install_model ja en
install_model en pt

# Etapa 2: extrair áudio
if [ ! -f "$AUDIO_FILE" ]; then
  echo "[2/6] 🎧 Extraindo áudio..."
  ffmpeg -i "$INPUT_FILE" -ar 16000 -ac 1 -c:a pcm_s16le "$AUDIO_FILE" -y
else
  echo "[2/6] 🎧 Áudio já extraído, pulando..."
fi

# Etapa 3: transcrição SRT com Whisper
echo $SRT_JA

if [ ! -f "$SRT_JA" ]; then
  echo "[3/6] ✍️ Transcrevendo com Whisper (timestamps reais)..."
  whisper "$AUDIO_FILE" --language Japanese --output_format srt --output_dir "$WORKDIR" --model base
else
  echo "[3/6] ✍️ SRT já existente, pulando..."
fi

# Copia a original japonesa para output
cp "$SRT_JA" "$SRT_JA_OUT"

# Etapa 4: traduzir SRT ja → en
if [ ! -f "$SRT_EN" ]; then
  echo "[4/6] 🌍 Traduzindo Japonês → Inglês (com timestamps)..."
  awk 'BEGIN{RS="";ORS="\n\n"} NR>0 {
    split($0, lines, "\n");
    print lines[1]; print lines[2];
    cmd = "echo \"" lines[3] "\" | argos-translate --from-lang ja --to-lang en";
    cmd | getline translation;
    close(cmd);
    print translation
  }' "$SRT_JA" > "$SRT_EN"
else
  echo "[4/6] 🌍 SRT en já existe, pulando..."
fi

# Etapa 5: traduzir SRT en → pt
if [ ! -f "$SRT_PT" ]; then
  echo "[5/6] 🌍 Traduzindo Inglês → Português (com timestamps)..."
  awk 'BEGIN{RS="";ORS="\n\n"} NR>0 {
    split($0, lines, "\n");
    print lines[1]; print lines[2];
    cmd = "echo \"" lines[3] "\" | argos-translate --from-lang en --to-lang pt";
    cmd | getline translation;
    close(cmd);
    print translation
  }' "$SRT_EN" > "$SRT_PT"
else
  echo "[5/6] 🌍 SRT pt já existe, pulando..."
fi

echo "✅ Legendas geradas:"
ls -1 /app/output/*.srt
