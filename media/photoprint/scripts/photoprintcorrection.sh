#!/bin/bash

# ---------------------------------------------------------------------------
# photoprintcorrection.sh – Konservative Farbkorrektur für Epson ET-2810/ET-2811
#
# Best Practice (Epson EcoTank + glänzendes Fotopapier wie Koala High Glossy):
#   - Die Farbgebung übernimmt weitgehend der Druckertreiber über den
#     Medientyp (MediaType). Deshalb hier nur eine LEICHTE Korrektur, keine
#     aggressive Sättigungsanhebung (die führt zu Übersättigung).
#   - Empfohlene Treiber-Einstellung: MediaType=PMPHOTO_NORMAL (Premium Photo,
#     normal) – bei zu wenig Tinte PMPHOTO_HIGH, bei zu viel PLAIN_NORMAL.
#
# Umgebungsvariablen (für nicht-interaktiven Aufruf, z.B. von main.sh):
#   SRC_DIR     Quellordner mit Originalfotos (Standard: input/)
#   OUT_DIR     Zielordner für korrigierte Fotos (Standard: work/corrected)
#   CONTRAST    Kontrast-Anpassung -25..+25 (Standard: 3)
#   SATURATION  Sättigungs-Anpassung in % (Standard: 0 = keine Änderung)
#   GAMMA       Gamma (Standard: 1.0 = keine Änderung)
# ---------------------------------------------------------------------------

install_dependencies() {
    local missing=()
    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        missing+=("imagemagick")
    fi
    if [ ${#missing[@]} -eq 0 ]; then return 0; fi
    echo "Folgende Pakete werden benötigt: ${missing[*]}"
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}"
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y "${missing[@]}"
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm "${missing[@]}"
    elif command -v brew &>/dev/null; then
        brew install "${missing[@]}"
    else
        echo "FEHLER: Kein unterstützter Paketmanager gefunden."
        exit 1
    fi
}

install_dependencies

if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
else
    MAGICK_CMD="convert"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${SRC_DIR:-}" ]; then
    if [ -d "$PROJECT_DIR/input" ]; then SRC_DIR="$PROJECT_DIR/input"
    else SRC_DIR="."
    fi
fi
if [ -z "${OUT_DIR:-}" ]; then
    if [ -d "$PROJECT_DIR/work" ]; then OUT_DIR="$PROJECT_DIR/work/corrected"
    else OUT_DIR="druckbereit"
    fi
fi
mkdir -p "$OUT_DIR"

if [ ! -d "$SRC_DIR" ]; then
    echo "FEHLER: Quellordner '$SRC_DIR' nicht gefunden."
    exit 1
fi

# Konservative Standardwerte (keine aggressive Sättigung)
CONTRAST="${CONTRAST:-3}"
SATURATION="${SATURATION:-0}"
GAMMA="${GAMMA:-1.0}"

echo "Starte konservative Farbkorrektur für Epson ET-2810/ET-2811..."
echo "Quelle: $SRC_DIR  ->  Ziel: $OUT_DIR"
echo "Einstellungen: Kontrast ${CONTRAST}, Sättigung ${SATURATION}%, Gamma ${GAMMA}"
echo "Hinweis: Feineinstellung erfolgt über den Druckertreiber (MediaType)."
echo "------------------------------------------------------------------------"

count=0
shopt -s nocaseglob
for file in "$SRC_DIR"/*.jpg "$SRC_DIR"/*.jpeg "$SRC_DIR"/*.png "$SRC_DIR"/*.tiff; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    echo "Verarbeite: $filename"

    # Sättigung: 100 = neutral, +N% = Anhebung
    sat_val=$((100 + SATURATION))

    $MAGICK_CMD "$file" \
        -auto-orient \
        -modulate 100,${sat_val},100 \
        -brightness-contrast 0x${CONTRAST} \
        -gamma ${GAMMA} \
        -depth 8 \
        "$OUT_DIR/$filename"
    ((count++))
done
shopt -u nocaseglob

echo "------------------------------------------------------------------------"
echo "Fertig! Es wurden $count Fotos korrigiert und in '$OUT_DIR' gespeichert."