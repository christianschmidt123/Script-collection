#!/bin/bash

# ---------------------------------------------------------------------------
# photoprint.sh – Fotos platzsparend auf Fotopapier drucken
#
# Strategie: Alle Fotos werden auf ein gemeinsames Druckformat zugeschnitten
# und dann per ImageMagick zu einem N-up-Montage-Bild zusammengesetzt,
# das anschließend über CUPS (lp) gedruckt wird.
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
    if ! command -v lp &>/dev/null; then
        missing+=("cups")
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
        echo "Bitte installiere ImageMagick und CUPS manuell."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Druckgröße jedes einzelnen Fotos wählen
# ---------------------------------------------------------------------------
select_photo_format() {
    echo ""
    echo "Welches Format hat jedes einzelne Foto auf dem Ausdruck?"
    echo "  1)  9 x 13 cm"
    echo "  2) 10 x 15 cm  (Standard)"
    echo "  3) 13 x 18 cm"
    echo "  4) 15 x 20 cm"
    echo "  5) 20 x 25 cm"
    echo "  6) Eigenes Format"
    read -rp "Auswahl [1-6]: " choice
    case "$choice" in
        1) PHOTO_W=9;  PHOTO_H=13 ;;
        2) PHOTO_W=10; PHOTO_H=15 ;;
        3) PHOTO_W=13; PHOTO_H=18 ;;
        4) PHOTO_W=15; PHOTO_H=20 ;;
        5) PHOTO_W=20; PHOTO_H=25 ;;
        6)
            read -rp "Breite in cm: " PHOTO_W
            read -rp "Höhe in cm:   " PHOTO_H
            ;;
        *) PHOTO_W=10; PHOTO_H=15 ;;
    esac
}

# ---------------------------------------------------------------------------
# Papierformat wählen
# ---------------------------------------------------------------------------
select_paper_format() {
    echo ""
    echo "Welches Papierformat wird verwendet?"
    echo "  1) A4  (21 x 29.7 cm)"
    echo "  2) A3  (29.7 x 42 cm)"
    echo "  3) 10 x 15 cm (Einzelbogen)"
    echo "  4) 13 x 18 cm"
    echo "  5) 20 x 25 cm"
    echo "  6) Eigenes Format"
    read -rp "Auswahl [1-6]: " choice
    case "$choice" in
        1) PAPER_W=21;   PAPER_H=29.7; PAPER_NAME="A4" ;;
        2) PAPER_W=29.7; PAPER_H=42;   PAPER_NAME="A3" ;;
        3) PAPER_W=10;   PAPER_H=15;   PAPER_NAME="10x15" ;;
        4) PAPER_W=13;   PAPER_H=18;   PAPER_NAME="13x18" ;;
        5) PAPER_W=20;   PAPER_H=25;   PAPER_NAME="20x25" ;;
        6)
            read -rp "Papierbreite in cm: " PAPER_W
            read -rp "Papierhöhe in cm:   " PAPER_H
            PAPER_NAME="${PAPER_W}x${PAPER_H}"
            ;;
        *) PAPER_W=21; PAPER_H=29.7; PAPER_NAME="A4" ;;
    esac
}

# ---------------------------------------------------------------------------
# Drucker auswählen
# ---------------------------------------------------------------------------
select_printer() {
    echo ""
    echo "Verfügbare Drucker:"
    lpstat -p 2>/dev/null | awk '{print NR") "$2}' || echo "  (keine CUPS-Drucker gefunden)"
    echo ""
    read -rp "Druckername (Enter = Standard-Drucker): " PRINTER
}

# ---------------------------------------------------------------------------
# Hauptprogramm
# ---------------------------------------------------------------------------
install_dependencies

# ImageMagick-Befehl ermitteln
if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
else
    MAGICK_CMD="convert"
fi

# Quellordner
read -rp "Ordner mit den druckfertigen Fotos (Enter = aktueller Ordner): " SRC_DIR
SRC_DIR="${SRC_DIR:-.}"
if [ ! -d "$SRC_DIR" ]; then
    echo "FEHLER: Ordner '$SRC_DIR' nicht gefunden."
    exit 1
fi

select_photo_format
select_paper_format

echo ""
read -rp "Druckauflösung in DPI [300]: " DPI
DPI="${DPI:-300}"

select_printer

# ---------------------------------------------------------------------------
# Berechnung: Wie viele Fotos passen auf ein Blatt?
# ---------------------------------------------------------------------------
COLS=$(echo "scale=0; $PAPER_W / $PHOTO_W" | bc)
ROWS=$(echo "scale=0; $PAPER_H / $PHOTO_H" | bc)
# Hochformat und Querformat vergleichen (Portrait)
COLS_L=$(echo "scale=0; $PAPER_H / $PHOTO_W" | bc)
ROWS_L=$(echo "scale=0; $PAPER_W / $PHOTO_H" | bc)

PHOTOS_P=$((COLS * ROWS))
PHOTOS_L=$((COLS_L * ROWS_L))

if [ "$PHOTOS_L" -gt "$PHOTOS_P" ]; then
    # Querformat ist besser: Papier rotieren
    COLS=$COLS_L
    ROWS=$ROWS_L
    # Effektive Pixelgröße des Papiers im Querformat
    PAPER_PX_W=$(echo "$PAPER_H * $DPI / 2.54" | bc)
    PAPER_PX_H=$(echo "$PAPER_W * $DPI / 2.54" | bc)
    echo "(Querformat gewählt: $COLS Spalten x $ROWS Zeilen = $PHOTOS_L Fotos pro Blatt)"
else
    PAPER_PX_W=$(echo "$PAPER_W * $DPI / 2.54" | bc)
    PAPER_PX_H=$(echo "$PAPER_H * $DPI / 2.54" | bc)
    echo "(Hochformat gewählt: $COLS Spalten x $ROWS Zeilen = $PHOTOS_P Fotos pro Blatt)"
fi

PHOTO_PX_W=$(echo "$PHOTO_W * $DPI / 2.54" | bc)
PHOTO_PX_H=$(echo "$PHOTO_H * $DPI / 2.54" | bc)

# ---------------------------------------------------------------------------
# Alle Fotos sammeln
# ---------------------------------------------------------------------------
declare -a PHOTOS
shopt -s nocaseglob
for f in "$SRC_DIR"/*.jpg "$SRC_DIR"/*.jpeg "$SRC_DIR"/*.png "$SRC_DIR"/*.tiff; do
    [ -e "$f" ] && PHOTOS+=("$f")
done
shopt -u nocaseglob

if [ ${#PHOTOS[@]} -eq 0 ]; then
    echo "FEHLER: Keine Fotos in '$SRC_DIR' gefunden."
    exit 1
fi

echo "Gefundene Fotos: ${#PHOTOS[@]}"
TILES_PER_PAGE=$((COLS * ROWS))
NUM_PAGES=$(( (${#PHOTOS[@]} + TILES_PER_PAGE - 1) / TILES_PER_PAGE ))
echo "Seiten gesamt:   $NUM_PAGES"

# ---------------------------------------------------------------------------
# Montage-PDFs erstellen und drucken
# ---------------------------------------------------------------------------
TMP_DIR=$(mktemp -d)
PRINT_FILES=()

for ((page=0; page<NUM_PAGES; page++)); do
    START=$((page * TILES_PER_PAGE))
    PAGE_PHOTOS=("${PHOTOS[@]:$START:$TILES_PER_PAGE}")

    # Fehlende Kacheln mit transparentem Platzhalter auffüllen
    while [ ${#PAGE_PHOTOS[@]} -lt "$TILES_PER_PAGE" ]; do
        PAGE_PHOTOS+=("null:")
    done

    OUT_FILE="$TMP_DIR/seite_$(printf '%04d' $((page+1))).tiff"
    echo "Erstelle Seite $((page+1))/$NUM_PAGES ..."

    $MAGICK_CMD montage "${PAGE_PHOTOS[@]}" \
        -geometry "${PHOTO_PX_W}x${PHOTO_PX_H}+0+0" \
        -tile "${COLS}x${ROWS}" \
        -background white \
        -density "$DPI" \
        -units PixelsPerInch \
        -resize "${PAPER_PX_W}x${PAPER_PX_H}" \
        "$OUT_FILE"

    PRINT_FILES+=("$OUT_FILE")
done

# ---------------------------------------------------------------------------
# Druckvorschau und Bestätigung
# ---------------------------------------------------------------------------
echo ""
echo "========================================================"
echo "  Druckauftrag-Zusammenfassung"
echo "========================================================"
echo "  Fotos:          ${#PHOTOS[@]}"
echo "  Fotogröße:      ${PHOTO_W}x${PHOTO_H} cm"
echo "  Papierformat:   $PAPER_NAME"
echo "  Fotos/Seite:    $TILES_PER_PAGE  ($COLS x $ROWS)"
echo "  Seiten:         $NUM_PAGES"
echo "  Auflösung:      ${DPI} dpi"
echo "  Drucker:        ${PRINTER:-Standard}"
echo "========================================================"
read -rp "Jetzt drucken? [j/N]: " confirm

if [[ "$confirm" =~ ^[jJyY]$ ]]; then
    for pfile in "${PRINT_FILES[@]}"; do
        if [ -n "$PRINTER" ]; then
            lp -d "$PRINTER" "$pfile"
        else
            lp "$pfile"
        fi
    done
    echo "Druckauftrag gesendet."
else
    echo "Druckauftrag abgebrochen. Temporäre Dateien: $TMP_DIR"
    exit 0
fi

# Temporäre Dateien aufräumen
rm -rf "$TMP_DIR"
echo "Fertig!"
