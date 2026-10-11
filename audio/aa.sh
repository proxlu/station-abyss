#!/usr/bin/env bash

AUDIO_DIR="audio"
if [ ! -d "$AUDIO_DIR" ]; then
    AUDIO_DIR="."
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Erro: O 'ffmpeg' não está instalado."
    exit 1
fi

echo "===================================================================================="
echo "                   RELATÓRIO DE DIAGNÓSTICO DE VOLUME DE ÁUDIO"
echo "===================================================================================="
printf "%-32s | %-12s | %-12s | %s\n" "ARQUIVO" "PICO (MAX)" "MÉDIO (RMS)" "STATUS"
echo "------------------------------------------------------------------------------------"

# Lê arquivo por arquivo sem deixar o ffmpeg consumir o stdin
while IFS= read -r file; do
    [ -z "$file" ] && continue
    filename=$(basename "$file")

    # -nostdin impede que o ffmpeg pule os arquivos da lista
    analysis=$(ffmpeg -nostdin -i "$file" -af "volumedetect" -vn -sn -dn -f null - 2>&1)

    max_vol=$(echo "$analysis" | grep -m 1 "max_volume:" | sed -E 's/.*max_volume: *([-0-9.]+) dB.*/\1/')
    mean_vol=$(echo "$analysis" | grep -m 1 "mean_volume:" | sed -E 's/.*mean_volume: *([-0-9.]+) dB.*/\1/')

    if [ -z "$max_vol" ]; then
        max_vol="N/A"
        mean_vol="N/A"
        status="ERRO AO LER"
    else
        # Compara os decibéis usando awk para não dar erro de número
        status=$(awk -v m="$max_vol" 'BEGIN {
            val = m + 0.0
            if (val >= -0.5) {
                print "🔴 ESTOURANDO / NO LIMITE"
            } else if (val < -13.0) {
                print "🔵 MUITO BAIXO"
            } else {
                print "🟢 EQUILIBRADO"
            }
        }')
    fi

    printf "%-32s | %-9s dB | %-9s dB | %s\n" "$filename" "$max_vol" "$mean_vol" "$status"
done < <(find "$AUDIO_DIR" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.ogg" \) | sort)

echo "===================================================================================="
echo "Legenda:"
echo " • 🔴 ESTOURANDO (Pico >= -0.5 dB): Áudio gravado muito alto, pode distorcer."
echo " • 🟢 EQUILIBRADO (Pico entre -0.6 dB e -13.0 dB): Volume saudável."
echo " • 🔵 MUITO BAIXO (Pico < -13.0 dB): Som sumido, precisa de ganho."
