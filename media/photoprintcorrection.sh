#!/bin/bash

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
    magick "$file" \
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
