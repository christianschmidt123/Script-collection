#!/bin/bash

# ---------------------------------------------------------------------------
# Abhängigkeiten prüfen und ggf. installieren
# ---------------------------------------------------------------------------
install_dependencies() {
    echo "Prüfe Abhängigkeiten..."
    local missing=()

    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        missing+=("imagemagick")
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
        echo "Bitte installiere ImageMagick manuell: https://imagemagick.org/script/download.php"
        exit 1
    fi
}

install_dependencies

# ---------------------------------------------------------------------------
# ImageMagick-Befehl ermitteln (v7 = magick, v6 = convert)
# ---------------------------------------------------------------------------
if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
else
    MAGICK_CMD="convert"
fi

# Ordner für die fertigen Fotos erstellen (damit die Originale nicht überschrieben werden)
OUTPUT_DIR="druckbereit"
mkdir -p "$OUTPUT_DIR"

# Zähler für die bearbeiteten Bilder
count=0

echo "Starte Optimierung der Fotos für den Epson ET-2811..."
echo "Ziel: Sättigung +12%, Helligkeit -3%, Kontrast +7%, Gamma 0.9 (Mitteltöne satter)"
echo "------------------------------------------------------------------------"

# Loop über alle gängigen Bildformate (Groß- und Kleinschreibung ignoriert)
shopt -s nocaseglob
for file in *.jpg *.jpeg *.png *.tiff; do
    # Prüfen, ob überhaupt Dateien vorhanden sind
    [ -e "$file" ] || continue
    
    echo "Verarbeite: $file"
    
    # Der eigentliche ImageMagick-Optimierungsbefehl
    $MAGICK_CMD "$file" \
        -modulate 100,112,100 \
        -brightness-contrast -3x7 \
        -gamma 0.9 \
        "$OUTPUT_DIR/$file"
        
    ((count++))
done
shopt -u nocaseglob

echo "------------------------------------------------------------------------"
echo "Fertig! Es wurden $count Fotos optimiert und im Ordner '$OUTPUT_DIR' gespeichert."
echo "Diese Bilder kannst du jetzt direkt in Darktable laden und drucken."
