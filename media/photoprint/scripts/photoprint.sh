#!/bin/bash

# ---------------------------------------------------------------------------
# photoprint.sh – Fotos platzsparend auf Fotopapier drucken (N-up)
#
# Umgebungsvariablen (für nicht-interaktiven Aufruf, z.B. von main.sh):
#   SRC_DIR     Quellordner mit skalierten Fotos (Standard: .)
#   PHOTO_W     Fotobreite in cm (Standard: 13)
#   PHOTO_H     Fotohöhe in cm   (Standard: 18)
#   PAPER_W     Papierbreite cm  (Standard: 21)
#   PAPER_H     Papierhöhe cm    (Standard: 29.7)
#   PAPER_NAME  Papiername       (Standard: A4)
#   DPI         Auflösung        (Standard: 600)
#   PRINTER     Druckername      (Standard: EPSON_ET-2810_Series)
#   AUTO_PRINT  1 = ohne Rückfrage drucken (Standard: 0)
# ---------------------------------------------------------------------------

install_dependencies() {
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
    MONTAGE_CMD="magick montage"
else
    MAGICK_CMD="convert"
    MONTAGE_CMD="montage"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -z "${SRC_DIR:-}" ]; then
    if [ -d "$PROJECT_DIR/work/scaled" ]; then SRC_DIR="$PROJECT_DIR/work/scaled"
    elif [ -d "$PROJECT_DIR/input" ]; then SRC_DIR="$PROJECT_DIR/input"
    else SRC_DIR="."
    fi
fi
if [ ! -d "$SRC_DIR" ]; then
    echo "FEHLER: Ordner '$SRC_DIR' nicht gefunden."
    exit 1
fi

# ---------------------------------------------------------------------------
# Fotogröße wählen (interaktiv nur, wenn nicht per Env gesetzt)
# ---------------------------------------------------------------------------
if [ -z "${PHOTO_W:-}" ] || [ -z "${PHOTO_H:-}" ]; then
    echo ""
    echo "Welches Format hat jedes einzelne Foto auf dem Ausdruck?"
    echo "  1)  9 x 13 cm"
    echo "  2) 10 x 15 cm"
    echo "  3) 13 x 18 cm  (Standard)"
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
        6) read -rp "Breite in cm: " PHOTO_W; read -rp "Höhe in cm:   " PHOTO_H ;;
        *) PHOTO_W=13; PHOTO_H=18 ;;
    esac
fi

# ---------------------------------------------------------------------------
# Papierformat (interaktiv nur, wenn nicht per Env gesetzt)
# ---------------------------------------------------------------------------
if [ -z "${PAPER_W:-}" ] || [ -z "${PAPER_H:-}" ] || [ -z "${PAPER_NAME:-}" ]; then
    echo ""
    echo "Welches Papierformat wird verwendet?"
    echo "  1) A4  (21 x 29.7 cm)  (Standard)"
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
        6) read -rp "Papierbreite in cm: " PAPER_W; read -rp "Papierhöhe in cm:   " PAPER_H; PAPER_NAME="${PAPER_W}x${PAPER_H}" ;;
        *) PAPER_W=21; PAPER_H=29.7; PAPER_NAME="A4" ;;
    esac
fi

# ---------------------------------------------------------------------------
# DPI (interaktiv nur, wenn nicht per Env gesetzt)
# ---------------------------------------------------------------------------
if [ -z "${DPI:-}" ]; then
    echo ""
    read -rp "Druckauflösung in DPI [600]: " DPI
    DPI="${DPI:-600}"
fi

# ---------------------------------------------------------------------------
# Drucker (interaktiv nur, wenn nicht per Env gesetzt)
# ---------------------------------------------------------------------------
if [ -z "${PRINTER:-}" ]; then
    echo ""
    echo "Verfügbare Drucker:"
    PRINTER_NAMES=()
    i=1
    while IFS= read -r pname; do
        [ -z "$pname" ] && continue
        PRINTER_NAMES+=("$pname")
        echo "  $i) $pname"
        ((i++))
    done < <(lpstat -p 2>/dev/null | awk '{print $2}')
    if [ ${#PRINTER_NAMES[@]} -eq 0 ]; then
        echo "  (keine CUPS-Drucker gefunden)"
    fi
    echo ""
    read -rp "Drucker (Nummer oder Name, Enter = Standard-Drucker): " PRINTER
    if [[ "$PRINTER" =~ ^[0-9]+$ ]] \
       && [ "$PRINTER" -ge 1 ] \
       && [ "$PRINTER" -le "${#PRINTER_NAMES[@]}" ]; then
        PRINTER="${PRINTER_NAMES[$((PRINTER-1))]}"
    fi
fi

# ---------------------------------------------------------------------------
# Medientyp (interaktiv nur, wenn nicht per Env gesetzt)
# Best Practice für glänzendes Fotopapier (z.B. Koala High Glossy):
# PMPHOTO_HIGH (Premium Photo, hohe Qualität) oder PSGLOS_HIGH (Photo Glossy).
# ---------------------------------------------------------------------------
if [ -z "${MEDIA_TYPE:-}" ]; then
    echo ""
    echo "Welches Papier/Medientyp wird verwendet?"
    echo "  1) PMPHOTO_NORMAL – Premium Photo, normal (Standard, ausgewogen)"
    echo "  2) PMPHOTO_HIGH   – Premium Photo, hohe Qualität (mehr Tinte)"
    echo "  3) PSGLOS_HIGH    – Photo Glossy, hohe Qualität"
    echo "  4) PLATINA_HIGH   – Platina (Premium Glossy), hohe Qualität"
    echo "  5) PLAIN_NORMAL   – Normalpapier (wenig Tinte, blass)"
    echo "  6) Eigener Wert"
    read -rp "Auswahl [1-6]: " mchoice
    case "$mchoice" in
        1) MEDIA_TYPE="PMPHOTO_NORMAL" ;;
        2) MEDIA_TYPE="PMPHOTO_HIGH" ;;
        3) MEDIA_TYPE="PSGLOS_HIGH" ;;
        4) MEDIA_TYPE="PLATINA_HIGH" ;;
        5) MEDIA_TYPE="PLAIN_NORMAL" ;;
        6) read -rp "Medientyp (z.B. PMPHOTO_NORMAL): " MEDIA_TYPE ;;
        *) MEDIA_TYPE="PMPHOTO_NORMAL" ;;
    esac
fi

# Defaults (falls nicht gesetzt und nicht interaktiv)
: "${PHOTO_W:=13}"
: "${PHOTO_H:=18}"
: "${PAPER_W:=21}"
: "${PAPER_H:=29.7}"
: "${PAPER_NAME:=A4}"
: "${DPI:=600}"
: "${PRINTER:=EPSON_ET-2810_Series}"
: "${MEDIA_TYPE:=PMPHOTO_NORMAL}"

# ---------------------------------------------------------------------------
# Berechnung: Wie viele Fotos passen auf ein Blatt?
# ---------------------------------------------------------------------------
COLS=$(echo "scale=0; $PAPER_W / $PHOTO_W" | bc)
ROWS=$(echo "scale=0; $PAPER_H / $PHOTO_H" | bc)
COLS_L=$(echo "scale=0; $PAPER_H / $PHOTO_W" | bc)
ROWS_L=$(echo "scale=0; $PAPER_W / $PHOTO_H" | bc)

PHOTOS_P=$((COLS * ROWS))
PHOTOS_L=$((COLS_L * ROWS_L))

if [ "$PHOTOS_L" -gt "$PHOTOS_P" ]; then
    COLS=$COLS_L
    ROWS=$ROWS_L
    PAPER_PX_W=$(echo "$PAPER_H * $DPI / 2.54" | bc)
    PAPER_PX_H=$(echo "$PAPER_W * $DPI / 2.54" | bc)
    echo "(Querformat gewählt: $COLS Spalten x $ROWS Zeilen)"
else
    PAPER_PX_W=$(echo "$PAPER_W * $DPI / 2.54" | bc)
    PAPER_PX_H=$(echo "$PAPER_H * $DPI / 2.54" | bc)
    echo "(Hochformat gewählt: $COLS Spalten x $ROWS Zeilen)"
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
# Montage-TIFFs erstellen (in OUTPUT_DIR, falls gesetzt, sonst Temp-Ordner)
# ---------------------------------------------------------------------------
if [ -n "${OUTPUT_DIR:-}" ]; then
    MONTAGE_DIR="$OUTPUT_DIR"
    mkdir -p "$MONTAGE_DIR"
    KEEP_MONTAGES=1
else
    MONTAGE_DIR=$(mktemp -d)
    KEEP_MONTAGES=0
fi
PRINT_FILES=()

for ((page=0; page<NUM_PAGES; page++)); do
    START=$((page * TILES_PER_PAGE))
    PAGE_PHOTOS=("${PHOTOS[@]:$START:$TILES_PER_PAGE}")
    while [ ${#PAGE_PHOTOS[@]} -lt "$TILES_PER_PAGE" ]; do
        PAGE_PHOTOS+=("null:")
    done

    OUT_FILE="$MONTAGE_DIR/seite_$(printf '%04d' $((page+1))).tiff"
    echo "Erstelle Seite $((page+1))/$NUM_PAGES ..."
    # -auto-orient: EXIF-Orientierung der Eingabebilder berücksichtigen
    $MONTAGE_CMD -auto-orient "${PAGE_PHOTOS[@]}" \
        -geometry "${PHOTO_PX_W}x${PHOTO_PX_H}+0+0" \
        -tile "${COLS}x${ROWS}" \
        -background white \
        -density "$DPI" \
        -units PixelsPerInch \
        -depth 8 \
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
echo "  Medientyp:      ${MEDIA_TYPE}"
echo "  Drucker:        ${PRINTER:-Standard}"
echo "========================================================"

if [ "${AUTO_PRINT:-0}" != "1" ]; then
    read -rp "Jetzt drucken? [j/N]: " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        echo "Druck abgebrochen. Montage-Seiten wurden in '$MONTAGE_DIR' gespeichert."
        exit 0
    fi
fi

for pfile in "${PRINT_FILES[@]}"; do
    if [ -n "$PRINTER" ]; then
        # Medientyp (für Fotopapier: PMPHOTO_HIGH / PSGLOS_HIGH / ...).
        # Farbregler NICHT explizit setzen – der Treiber nutzt seine Defaults
        # (0 = neutral). Explizites Setzen auf 0 führte zu Schwarzdruck.
        # fit-to-page: Bild in die Seite einpassen, ohne Ränder abzuschneiden.
        lp -d "$PRINTER" \
            -o "MediaType=${MEDIA_TYPE}" \
            -o "fit-to-page" \
            "$pfile"
    else
        lp -o "MediaType=${MEDIA_TYPE}" \
            -o "fit-to-page" \
            "$pfile"
    fi
done
echo "Druckauftrag gesendet."

if [ "${KEEP_MONTAGES:-0}" != "1" ]; then
    rm -rf "$MONTAGE_DIR"
fi
echo "Fertig!"
if [ "${KEEP_MONTAGES:-0}" = "1" ]; then
    echo "Montage-Seiten gespeichert in: $MONTAGE_DIR"
fi