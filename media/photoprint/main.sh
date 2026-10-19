#!/bin/bash

# ===========================================================================
# main.sh – Foto-Print-Suite: kompletter Workflow mit einem Befehl
# ===========================================================================
#
# Ordnerstruktur (wird automatisch angelegt):
#   input/            -> Originalfotos hier ablegen
#   work/corrected/   -> Farbkorrigierte Fotos
#   work/scaled/      -> Auf Druckformat skalierte Fotos
#   output/           -> Druckfertige Seiten (Montage-TIFFs, zu Debug-Zwecken)
#
# Standards (aus dem bisherigen Workflow abgeleitet):
#   Fotogröße:  13 x 18 cm
#   Papier:     A4 (21 x 29.7 cm)
#   Auflösung:  600 dpi
#   Drucker:    EPSON_ET-2810_Series
#
# Aufruf:
#   ./main.sh                          # alles mit Standards
#   INPUT_DIR=~/Fotos ./main.sh        # eigener Eingabeordner
#   PHOTO_W=10 PHOTO_H=15 ./main.sh    # eigenes Fotofomat
#   DPI=300 ./main.sh                 # andere Auflösung
#   AUTO_PRINT=1 ./main.sh            # ohne Rückfrage drucken
# ===========================================================================

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Standards (können per Umgebungsvariable überschrieben werden)
# Die Format-/Papier-/DPI-/Druckerwahl erfolgt interaktiv in den Skripten;
# hier nur der Eingabeordner und der Auto-Druck-Schalter.
# ---------------------------------------------------------------------------
INPUT_DIR="${INPUT_DIR:-$SCRIPT_DIR/input}"
AUTO_PRINT="${AUTO_PRINT:-0}"

WORK_DIR="$SCRIPT_DIR/work"
CORRECTED_DIR="$WORK_DIR/corrected"
SCALED_DIR="$WORK_DIR/scaled"
OUTPUT_DIR="${OUTPUT_DIR:-$SCRIPT_DIR/output}"

# ---------------------------------------------------------------------------
# Hilfsfunktionen
# ---------------------------------------------------------------------------
line() { echo "════════════════════════════════════════════════════════"; }
step() { echo ""; line; echo "  $1"; line; }

# ---------------------------------------------------------------------------
# Abhängigkeiten
# ---------------------------------------------------------------------------
for cmd in magick bc lp; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "FEHLER: '$cmd' nicht gefunden. Bitte installieren."
        exit 1
    fi
done

# ---------------------------------------------------------------------------
# Ordner anlegen
# ---------------------------------------------------------------------------
mkdir -p "$INPUT_DIR" "$CORRECTED_DIR" "$SCALED_DIR" "$OUTPUT_DIR"

if [ ! -d "$INPUT_DIR" ]; then
    echo "FEHLER: Eingabeordner '$INPUT_DIR' konnte nicht angelegt werden."
    exit 1
fi

# Prüfen, ob Fotos vorhanden sind
shopt -s nocaseglob
photo_count=0
for f in "$INPUT_DIR"/*.jpg "$INPUT_DIR"/*.jpeg "$INPUT_DIR"/*.png "$INPUT_DIR"/*.tiff; do
    [ -e "$f" ] && ((photo_count++))
done
shopt -u nocaseglob

if [ "$photo_count" -eq 0 ]; then
    echo ""
    echo "Keine Fotos im Eingabeordner gefunden:"
    echo "  $INPUT_DIR"
    echo ""
    echo "Bitte lege deine Originalfotos dort ab und starte main.sh erneut."
    exit 0
fi

echo ""
line
echo "  📷  Foto-Print-Suite – Kompletter Workflow"
line
echo "  Eingabe:     $INPUT_DIR  ($photo_count Fotos)"
echo "  Ausgabe:     $OUTPUT_DIR"
echo "  (Format, Papier, DPI und Drucker werden im jeweiligen Schritt gewählt)"
line

# ---------------------------------------------------------------------------
# Schritt 1: Farbkorrektur
# ---------------------------------------------------------------------------
step "Schritt 1/3: Farbkorrektur"
SRC_DIR="$INPUT_DIR" OUT_DIR="$CORRECTED_DIR" \
    bash "$SCRIPT_DIR/scripts/photoprintcorrection.sh"

# ---------------------------------------------------------------------------
# Schritt 2: Skalierung
# ---------------------------------------------------------------------------
step "Schritt 2/3: Skalierung"
SRC_DIR="$CORRECTED_DIR" OUT_DIR="$SCALED_DIR" \
    bash "$SCRIPT_DIR/scripts/photoresize.sh"

# ---------------------------------------------------------------------------
# Schritt 3: Drucken
# ---------------------------------------------------------------------------
step "Schritt 3/3: Drucken (N-up)"
SRC_DIR="$SCALED_DIR" \
    AUTO_PRINT="$AUTO_PRINT" \
    OUTPUT_DIR="$OUTPUT_DIR" \
    bash "$SCRIPT_DIR/scripts/photoprint.sh"

echo ""
line
echo "  ✅  Workflow abgeschlossen."
echo "  Skalierte Fotos: $SCALED_DIR"
echo "  Druckaufträge wurden gesendet (sofern bestätigt)."
line