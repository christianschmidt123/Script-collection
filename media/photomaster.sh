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
    read -rp "Quellordner mit Fotos (Enter = aktueller Ordner): " SRC
    SRC="${SRC:-.}"

    if [ ! -d "$SRC" ]; then
        echo "FEHLER: Ordner '$SRC' nicht gefunden."
        read -rp "Weiter mit Enter ..."
        return
    fi

    (cd "$SRC" && bash "$SCRIPT_DIR/photoprintcorrection.sh")
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
    bash "$SCRIPT_DIR/photoresize.sh"
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
    bash "$SCRIPT_DIR/photoprint.sh"
    echo ""
    read -rp "Weiter mit Enter ..."
}

# ---------------------------------------------------------------------------
# Untermenü: Kompletter Workflow (alle Schritte nacheinander)
# ---------------------------------------------------------------------------
menu_full_workflow() {
    clear
    line
    echo "  🔄  Kompletter Workflow"
    line
    echo ""
    echo "Schritt 1: Farbkorrektur"
    echo "Schritt 2: Skalierung auf Druckformat"
    echo "Schritt 3: Platzsparender Druck"
    echo ""
    echo "Hinweis: Jedes Skript fragt dich nach dem passenden Ordner."
    echo "Starte Schritt 1 zuerst, dann gib den Ausgabeordner"
    echo "('druckbereit') als Eingabe für Schritt 2 an."
    echo ""
    read -rp "Workflow starten? [j/N]: " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        return
    fi

    echo ""
    echo "══ Schritt 1/3: Farbkorrektur ══════════════════════════"
    menu_correction

    echo ""
    echo "══ Schritt 2/3: Skalierung ═════════════════════════════"
    menu_resize

    echo ""
    echo "══ Schritt 3/3: Drucken ════════════════════════════════"
    menu_print
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
