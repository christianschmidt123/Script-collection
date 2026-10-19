#!/bin/bash

# ---------------------------------------------------------------------------
# photoresize.sh – Fotos auf Druckformate skalieren
#
# Umgebungsvariablen (für nicht-interaktiven Aufruf, z.B. von main.sh):
#   SRC_DIR    Quellordner (Standard: .)
#   OUT_DIR    Zielordner (Standard: <SRC_DIR>/skaliert_WxHcm)
#   FORMAT_W   Breite in cm (Standard: 13)
#   FORMAT_H   Höhe in cm   (Standard: 18)
#   DPI        Auflösung    (Standard: 600)
# ---------------------------------------------------------------------------

install_dependencies() {
    local missing=()
    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        missing+=("imagemagick")
    fi
    if ! command -v bc &>/dev/null; then
        missing+=("bc")
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
    if [ -d "$PROJECT_DIR/work/corrected" ]; then SRC_DIR="$PROJECT_DIR/work/corrected"
    elif [ -d "$PROJECT_DIR/input" ]; then SRC_DIR="$PROJECT_DIR/input"
    else SRC_DIR="."
    fi
fi
if [ ! -d "$SRC_DIR" ]; then
    echo "FEHLER: Quellordner '$SRC_DIR' nicht gefunden."
    exit 1
fi

# ---------------------------------------------------------------------------
# Formatwahl (interaktiv nur, wenn nicht per Env gesetzt)
# ---------------------------------------------------------------------------
if [ -z "${FORMAT_W:-}" ] || [ -z "${FORMAT_H:-}" ]; then
    echo ""
    echo "Welches Druckformat soll verwendet werden?"
    echo "  1)  9 x 13 cm"
    echo "  2) 10 x 15 cm"
    echo "  3) 13 x 18 cm  (Standard)"
    echo "  4) 15 x 20 cm"
    echo "  5) 20 x 25 cm"
    echo "  6) 20 x 30 cm"
    echo "  7) 30 x 40 cm"
    echo "  8) 30 x 45 cm"
    echo "  9) Eigenes Format"
    echo ""
    read -rp "Auswahl [1-9]: " choice
    case "$choice" in
        1) FORMAT_W=9;  FORMAT_H=13 ;;
        2) FORMAT_W=10; FORMAT_H=15 ;;
        3) FORMAT_W=13; FORMAT_H=18 ;;
        4) FORMAT_W=15; FORMAT_H=20 ;;
        5) FORMAT_W=20; FORMAT_H=25 ;;
        6) FORMAT_W=20; FORMAT_H=30 ;;
        7) FORMAT_W=30; FORMAT_H=40 ;;
        8) FORMAT_W=30; FORMAT_H=45 ;;
        9) read -rp "Breite in cm: " FORMAT_W; read -rp "Höhe in cm:   " FORMAT_H ;;
        *) FORMAT_W=13; FORMAT_H=18 ;;
    esac
fi

# ---------------------------------------------------------------------------
# DPI (interaktiv nur, wenn nicht per Env gesetzt)
# ---------------------------------------------------------------------------
if [ -z "${DPI:-}" ]; then
    echo ""
    echo "Welche Druckauflösung soll verwendet werden?"
    echo "  1) 300 dpi"
    echo "  2) 600 dpi  (Standard)"
    echo "  3) Eigene Auflösung"
    read -rp "Auswahl [1-3]: " dchoice
    case "$dchoice" in
        1) DPI=300 ;;
        2) DPI=600 ;;
        3) read -rp "DPI eingeben: " DPI ;;
        *) DPI=600 ;;
    esac
fi

# Ausgabeordner
if [ -z "${OUT_DIR:-}" ]; then
    OUT_DIR="${SRC_DIR}/skaliert_${FORMAT_W}x${FORMAT_H}cm"
fi
mkdir -p "$OUT_DIR"

# cm → Pixel
PX_W=$(echo "$FORMAT_W * $DPI / 2.54" | bc)
PX_H=$(echo "$FORMAT_H * $DPI / 2.54" | bc)

echo ""
echo "Zielgröße: ${FORMAT_W}x${FORMAT_H} cm  =  ${PX_W}x${PX_H} px @ ${DPI} dpi"
echo "Quelle: $SRC_DIR  ->  Ziel: $OUT_DIR"
echo "--------------------------------------------------------------"

count=0
shopt -s nocaseglob
for file in "$SRC_DIR"/*.jpg "$SRC_DIR"/*.jpeg "$SRC_DIR"/*.png "$SRC_DIR"/*.tiff; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    echo "Skaliere: $filename"
    # 1) EXIF-Orientierung auswerten -> Bild richtig drehen
    # 2) Wenn das Bild im Querformat ist (Breite > Höhe), um 90° drehen,
    #    damit es im Hochformat-Rahmen (z.B. 13x18) ohne große Balken passt.
    read -r img_w img_h < <(magick "$file" -auto-orient -format "%w %h" info: 2>/dev/null)
    ROTATE_OPT=""
    if [ -n "$img_w" ] && [ -n "$img_h" ] && [ "$img_w" -gt "$img_h" ]; then
        ROTATE_OPT="-rotate 90"
        echo "  (Querformat ${img_w}x${img_h} -> 90° gedreht)"
    fi

    # -resize (ohne ^): proportional einpassen (kein Zuschneiden)
    # -extent: auf Zielgröße auffüllen (weißer Rand statt Abschneiden)
    $MAGICK_CMD "$file" \
        -auto-orient \
        $ROTATE_OPT \
        -resize "${PX_W}x${PX_H}" \
        -gravity Center \
        -background white \
        -extent "${PX_W}x${PX_H}" \
        -density "$DPI" \
        -units PixelsPerInch \
        -depth 8 \
        "$OUT_DIR/$filename"
    ((count++))
done
shopt -u nocaseglob

echo "--------------------------------------------------------------"
echo "Fertig! $count Fotos wurden auf ${FORMAT_W}x${FORMAT_H} cm skaliert."
echo "Ergebnis: $OUT_DIR"