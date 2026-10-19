#!/bin/bash

# ---------------------------------------------------------------------------
# photomaster.sh – Interaktives Konsolenmenü für alle Foto-Skripte
#
# Steuert:
#   1. photoprintcorrection.sh  – Farbkorrektur für den Epson ET-2811
#   2. photoresize.sh           – Skalierung auf Druckformate
#   3. photoprint.sh            – Platzsparender N-up-Druck
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Sicherstellen, dass die Skripte ausführbar sind
chmod +x "$SCRIPT_DIR/photoprintcorrection.sh" \
         "$SCRIPT_DIR/photoresize.sh" \
         "$SCRIPT_DIR/photoprint.sh" 2>/dev/null

# ---------------------------------------------------------------------------
# Hilfsfunktion: Trennlinie
# ---------------------------------------------------------------------------
line() {
    echo "════════════════════════════════════════════════════════"
}

# ---------------------------------------------------------------------------
# Untermenü: Farbkorrektur
# ---------------------------------------------------------------------------
menu_correction() {
    clear
    line
    echo "  🎨  Farbkorrektur (photoprintcorrection.sh)"
    line
    echo ""
    echo "Dieses Skript passt Helligkeit, Sättigung, Kontrast"
    echo "und Gamma der Fotos für den Epson ET-2811 an."
    echo ""
    read -rp "Quellordner mit Fotos (Enter = $PROJECT_DIR/input): " SRC
    SRC="${SRC:-$PROJECT_DIR/input}"

    if [ ! -d "$SRC" ]; then
        echo "FEHLER: Ordner '$SRC' nicht gefunden."
        read -rp "Weiter mit Enter ..."
        return
    fi

    SRC_DIR="$SRC" bash "$SCRIPT_DIR/photoprintcorrection.sh"
    echo ""
    read -rp "Weiter mit Enter ..."
}

# ---------------------------------------------------------------------------
# Untermenü: Skalierung
# ---------------------------------------------------------------------------
menu_resize() {
    clear
    line
    echo "  📐  Foto-Skalierung (photoresize.sh)"
    line
    SRC_DIR="${PROJECT_DIR}/work/corrected" bash "$SCRIPT_DIR/photoresize.sh"
    echo ""
    read -rp "Weiter mit Enter ..."
}

# ---------------------------------------------------------------------------
# Untermenü: Drucken
# ---------------------------------------------------------------------------
menu_print() {
    clear
    line
    echo "  🖨️   Platzsparender Fotodruck (photoprint.sh)"
    line
    SRC_DIR="${PROJECT_DIR}/work/scaled" bash "$SCRIPT_DIR/photoprint.sh"
    echo ""
    read -rp "Weiter mit Enter ..."
}

# ---------------------------------------------------------------------------
# Untermenü: Kompletter Workflow (alle Schritte nacheinander, Ordner gekettet)
# ---------------------------------------------------------------------------
menu_full_workflow() {
    clear
    line
    echo "  🔄  Kompletter Workflow"
    line
    echo ""
    echo "Der komplette Workflow wird jetzt über main.sh ausgeführt."
    echo "  Eingabe:  $PROJECT_DIR/input"
    echo "  Ausgabe:  $PROJECT_DIR/output"
    echo ""
    read -rp "Workflow starten? [j/N]: " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        return
    fi
    bash "$PROJECT_DIR/main.sh"
    echo ""
    read -rp "Workflow abgeschlossen. Weiter mit Enter ..."
}

# ---------------------------------------------------------------------------
# Hauptmenü
# ---------------------------------------------------------------------------
main_menu() {
    while true; do
        clear
        line
        echo "  📷  Foto-Print-Suite  –  Hauptmenü"
        line
        echo ""
        echo "  1)  Farbkorrektur        (für Epson ET-2811)"
        echo "  2)  Fotos skalieren      (auf Druckformat bringen)"
        echo "  3)  Fotos drucken        (platzsparend, N-up)"
        echo "  4)  Kompletter Workflow  (1 → 2 → 3)"
        echo ""
        echo "  q)  Beenden"
        echo ""
        line
        read -rp "Auswahl: " choice

        case "$choice" in
            1) menu_correction ;;
            2) menu_resize ;;
            3) menu_print ;;
            4) menu_full_workflow ;;
            q|Q|quit|exit)
                echo ""
                echo "Auf Wiedersehen!"
                exit 0
                ;;
            *)
                echo "Ungültige Auswahl. Bitte 1–4 oder q eingeben."
                sleep 1
                ;;
        esac
    done
}

main_menu
