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
# Untermenü: Kompletter Workflow (alle Schritte nacheinander, Ordner gekettet)
# ---------------------------------------------------------------------------
menu_full_workflow() {
    clear
    line
    echo "  🔄  Kompletter Workflow"
    line
    echo ""
    echo "Schritt 1: Farbkorrektur  → Ausgabe in '<quellordner>/druckbereit/'"
    echo "Schritt 2: Skalierung     → Eingabe: 'druckbereit/', Ausgabe: 'druckbereit/skaliert_*/'"
    echo "Schritt 3: Druck          → Eingabe: skalierter Ordner aus Schritt 2"
    echo ""
    read -rp "Workflow starten? [j/N]: " confirm
    if [[ ! "$confirm" =~ ^[jJyY]$ ]]; then
        return
    fi

    # --- Schritt 1: Farbkorrektur ---
    echo ""
    echo "══ Schritt 1/3: Farbkorrektur ══════════════════════════"
    read -rp "Quellordner mit Originalfotos (Enter = aktueller Ordner): " SRC_ORIG
    SRC_ORIG="${SRC_ORIG:-.}"
    if [ ! -d "$SRC_ORIG" ]; then
        echo "FEHLER: Ordner '$SRC_ORIG' nicht gefunden."
        read -rp "Weiter mit Enter ..."
        return
    fi
    (cd "$SRC_ORIG" && bash "$SCRIPT_DIR/photoprintcorrection.sh")
    CORRECTION_OUT="$(realpath "$SRC_ORIG")/druckbereit"
    echo ""
    echo "✓ Farbkorrektur abgeschlossen. Ergebnis: $CORRECTION_OUT"
    read -rp "Weiter mit Enter ..."

    # --- Schritt 2: Skalierung (PHOTO_SRC_DIR gesetzt → kein manueller Quellordner-Prompt) ---
    echo ""
    echo "══ Schritt 2/3: Skalierung ═════════════════════════════"
    PHOTO_SRC_DIR="$CORRECTION_OUT" bash "$SCRIPT_DIR/photoresize.sh"

    # Letzten erstellten skaliert_*-Ordner ermitteln
    RESIZE_OUT=$(ls -dt "$CORRECTION_OUT"/skaliert_* 2>/dev/null | head -1)
    RESIZE_OUT="${RESIZE_OUT:-$CORRECTION_OUT}"
    echo ""
    echo "✓ Skalierung abgeschlossen. Ergebnis: $RESIZE_OUT"
    read -rp "Weiter mit Enter ..."

    # --- Schritt 3: Drucken (PHOTO_SRC_DIR gesetzt) ---
    echo ""
    echo "══ Schritt 3/3: Drucken ════════════════════════════════"
    PHOTO_SRC_DIR="$RESIZE_OUT" bash "$SCRIPT_DIR/photoprint.sh"

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
