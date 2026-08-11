#!/bin/bash

# ---------------------------------------------------------------------------
# photoresize.sh – Fotos auf gängige Druckformate skalieren
# Unterstützte Formate (Breite x Höhe in cm):
#   9x13, 10x15, 13x18, 15x20, 20x25, 20x30, 30x40, 30x45
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Abhängigkeiten prüfen und ggf. installieren
# ---------------------------------------------------------------------------
install_dependencies() {
    echo "Prüfe Abhängigkeiten..."
    local missing=()

    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        missing+=("imagemagick")
    fi
    if ! command -v bc &>/dev/null; then
        missing+=("bc")
    fi

    if [ ${#missing[@]} -eq 0 ]; then
        echo "Alle Abhängigkeiten sind bereits installiert."
        return 0
    fi

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
        echo "Bitte installiere ImageMagick und bc manuell."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Formatauswahl-Dialog
# ---------------------------------------------------------------------------
select_format() {
    echo ""
    echo "Welches Druckformat soll verwendet werden?"
    echo "  1)  9 x 13 cm  (Briefumschlag-Format)"
    echo "  2) 10 x 15 cm  (Postkarten-Format)"
    echo "  3) 13 x 18 cm  (Classic)"
    echo "  4) 15 x 20 cm"
    echo "  5) 20 x 25 cm"
    echo "  6) 20 x 30 cm"
    echo "  7) 30 x 40 cm"
    echo "  8) 30 x 45 cm"
    echo "  9) Eigenes Format eingeben"
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
        9)
            read -rp "Breite in cm: " FORMAT_W
            read -rp "Höhe in cm:   " FORMAT_H
            ;;
        *)
            echo "Ungültige Auswahl. Standardformat 10x15 wird verwendet."
            FORMAT_W=10; FORMAT_H=15
            ;;
    esac
}

# ---------------------------------------------------------------------------
# DPI-Auflösung abfragen
# ---------------------------------------------------------------------------
select_dpi() {
    echo ""
    echo "Welche Druckauflösung soll verwendet werden?"
    echo "  1) 300 dpi  (Standard Fotodruck)"
    echo "  2) 600 dpi  (Hohe Qualität)"
    echo "  3) Eigene Auflösung eingeben"
    read -rp "Auswahl [1-3]: " dchoice
    case "$dchoice" in
        1) DPI=300 ;;
        2) DPI=600 ;;
        3) read -rp "DPI eingeben: " DPI ;;
        *) DPI=300 ;;
    esac
}

# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------
install_dependencies

# ImageMagick-Befehl ermitteln (v7 = magick, v6 = convert)
if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
else
    MAGICK_CMD="convert"
fi

# Quellordner bestimmen (env-Variable PHOTO_SRC_DIR hat Vorrang)
if [ -n "${PHOTO_SRC_DIR:-}" ]; then
    SRC_DIR="$PHOTO_SRC_DIR"
    echo "Quellordner (aus Workflow): $SRC_DIR"
else
    read -rp "Quellordner mit Fotos (Enter = aktueller Ordner): " SRC_DIR
    SRC_DIR="${SRC_DIR:-.}"
fi
if [ ! -d "$SRC_DIR" ]; then
    echo "FEHLER: Ordner '$SRC_DIR' nicht gefunden."
    exit 1
fi

select_format
select_dpi

# Ausgabeordner
OUTPUT_DIR="${SRC_DIR}/skaliert_${FORMAT_W}x${FORMAT_H}cm"
mkdir -p "$OUTPUT_DIR"

# cm → Pixel umrechnen
PX_W=$(echo "$FORMAT_W * $DPI / 2.54" | bc)
PX_H=$(echo "$FORMAT_H * $DPI / 2.54" | bc)

echo ""
echo "Zielgröße: ${FORMAT_W}x${FORMAT_H} cm  =  ${PX_W}x${PX_H} px @ ${DPI} dpi"
echo "Ausgabeordner: $OUTPUT_DIR"
echo "--------------------------------------------------------------"

count=0
shopt -s nocaseglob
for file in "$SRC_DIR"/*.jpg "$SRC_DIR"/*.jpeg "$SRC_DIR"/*.png "$SRC_DIR"/*.tiff; do
    [ -e "$file" ] || continue
    filename=$(basename "$file")
    echo "Skaliere: $filename"

    # Foto proportional so skalieren, dass es in den Rahmen passt,
    # dann auf exakte Größe zuschneiden (Mitte).
    $MAGICK_CMD "$file" \
        -resize "${PX_W}x${PX_H}^" \
        -gravity Center \
        -extent "${PX_W}x${PX_H}" \
        -density "$DPI" \
        -units PixelsPerInch \
        "$OUTPUT_DIR/$filename"

    ((count++))
done
shopt -u nocaseglob

echo "--------------------------------------------------------------"
echo "Fertig! $count Fotos wurden auf ${FORMAT_W}x${FORMAT_H} cm skaliert."
echo "Ergebnis: $OUTPUT_DIR"
