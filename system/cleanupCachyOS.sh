#!/usr/bin/env bash

# 1. Root-Rechte direkt am Anfang anfordern (verhindert hängende Passwort-Prompts)
if [ "$EUID" -ne 0 ]; then
  echo -e "\033[1;33mFür das Skript werden Administrator-Rechte benötigt.\033[0m"
  exec sudo "$0" "$@"
fi

# Farben & Formatierung
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Hilfsfunktion: Lade-Spinner für Hintergrund-Prozesse
run_with_spinner() {
    local msg="$1"
    shift
    echo -n -e "${YELLOW}${msg}${NC} "

    "$@" &>/dev/null &
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'

    tput civis 2>/dev/null || true
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    tput cnorm 2>/dev/null || true
    printf " [ Fertig ]\n"
}

# Hilfsfunktion für Ja/Nein-Abfragen
confirm() {
    read -rp "$(echo -e "${BOLD}$1${NC} [j/N]: ")" response
    case "$response" in
        [jJ][eE][sS]|[jJ]) true ;;
        *) false ;;
    esac
}

# Tatsächlichen Benutzernamen ermitteln (da das Skript via sudo läuft)
REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

echo -e "${BLUE}${BOLD}=== CachyOS Speicher-Analyse & Aufräum-Helfer ===${NC}\n"

# -----------------------------------------------------------------------------
# 1. ANALYSE-ABSCHNITT
# -----------------------------------------------------------------------------

echo -e "${YELLOW}[1] Festplattenbelegung (ohne Overlay/Virtuelle Mounts):${NC}"
df -h -x tmpfs -x devtmpfs -x squashfs -x overlay
echo ""

echo -e "${YELLOW}[2] Paket-Caches (Pacman & AUR):${NC}"
[ -d /var/cache/pacman/pkg ] && echo -n "  Pacman-Cache: " && du -sh /var/cache/pacman/pkg 2>/dev/null || true
[ -d "$REAL_HOME/.cache/paru/clone" ] && echo -n "  Paru AUR-Cache: " && du -sh "$REAL_HOME/.cache/paru/clone" 2>/dev/null || true
[ -d "$REAL_HOME/.cache/yay" ] && echo -n "  Yay AUR-Cache: " && du -sh "$REAL_HOME/.cache/yay" 2>/dev/null || true
echo ""

echo -e "${YELLOW}[3] Systemd Log-Dateien & Crash-Dumps:${NC}"
echo -n "  Journal Logs: " && journalctl --disk-usage 2>/dev/null || true
[ -d /var/lib/systemd/coredump ] && echo -n "  Crash-Dumps: " && du -sh /var/lib/systemd/coredump 2>/dev/null || true
echo ""

echo -e "${YELLOW}[4] Btrfs & Snapshots:${NC}"
if command -v snapper &>/dev/null; then
    SNAP_COUNT=$(snapper -c root list 2>/dev/null | wc -l || echo "0")
    echo "  Snapper aktiv: $SNAP_COUNT Snapshots vorhanden."
elif [ -d /.snapshots ]; then
    SNAP_COUNT=$(btrfs subvolume list /.snapshots 2>/dev/null | wc -l || echo "0")
    echo "  /.snapshots vorhanden ($SNAP_COUNT Snapshots)."
fi
echo ""

if command -v docker &>/dev/null; then
    echo -e "${YELLOW}[5] Docker Speicherbelegung:${NC}"
    docker system df 2>/dev/null || echo "  Docker-Dienst läuft aktuell nicht."
    echo ""
fi

# -----------------------------------------------------------------------------
# 2. INTERAKTIVER BEREINIGUNGS-ABSCHNITT
# -----------------------------------------------------------------------------

echo -e "${GREEN}${BOLD}=== INTERAKTIVE BEREINIGUNG ===${NC}"
echo -e "Wähle aus, was aufgeräumt werden soll:\n"

# 1. Snapshots aufräumen
if command -v snapper &>/dev/null; then
    if confirm "1. Alte Snapper-Snapshots aufräumen (Empfohlen bei vielen Snapshots)?"; then
        echo "Lösche alte Snapshots via Snapper Cleanup..."
        snapper -c root cleanup timeline || true
        snapper -c root cleanup number || true
        echo -e "${GREEN}Snapshots erfolgreich aufgeräumt.${NC}\n"
    fi
fi

# 2. Pacman & AUR Cache
if confirm "2. Pacman- & Paru/AUR-Cache leeren (behält nur 1 Version)?"; then
    run_with_spinner "Räume Pacman- & AUR-Cache auf..." bash -c "
        paccache -rk1 || true
        rm -rf '$REAL_HOME/.cache/paru/clone/'* 2>/dev/null || true
        rm -rf '$REAL_HOME/.cache/yay/'* 2>/dev/null || true
    "
    echo -e "${GREEN}Paket-Caches geleert.${NC}\n"
fi

# 3. Waisen-Pakete
if confirm "3. Unbenutzte Waisen-Pakete (Orphans) entfernen?"; then
    ORPHANS=$(pacman -Qtdq || true)
    if [ -n "$ORPHANS" ]; then
        pacman -Rns $ORPHANS --noconfirm || true
    else
        echo "Keine Waisen-Pakete vorhanden."
    fi
    echo -e "${GREEN}Fertig.${NC}\n"
fi

# 4. Docker aufräumen
if command -v docker &>/dev/null; then
    EXITED_CONTAINERS=$(docker ps -a -f status=exited --format "{{.Names}} (Image: {{.Image}})" 2>/dev/null || true)

    if [ -n "$EXITED_CONTAINERS" ]; then
        echo -e "${YELLOW}Folgende beendete Container werden entfernt:${NC}"
        echo "$EXITED_CONTAINERS" | sed 's/^/  - /'
        echo ""
    fi

    if confirm "4. Unbenutzte Docker Container/Images/Volumes löschen?"; then
        echo "Lösche unbenutzte Docker-Ressourcen..."
        # Führt Prune aus und gibt nur das Zusammenfassungsergebnis aus (keine Hash-Listen)
        CLEANUP_OUT=$(docker system prune -a --volumes -f 2>&1 || true)
        RECLAIMED=$(echo "$CLEANUP_OUT" | grep "Total reclaimed space:" || echo "")

        if [ -n "$RECLAIMED" ]; then
            echo -e "  ${GREEN}$RECLAIMED${NC}"
        fi
        echo -e "${GREEN}Docker erfolgreich aufgeräumt.${NC}\n"
    fi
fi

# 5. Systemd Logs & Dumps
if confirm "5. Logs auf 100MB begrenzen & Crash-Dumps löschen?"; then
    journalctl --vacuum-size=100M || true
    rm -rf /var/lib/systemd/coredump/* 2>/dev/null || true
    echo -e "${GREEN}Logs aufgeräumt.${NC}\n"
fi

# 6. Browser- & Thumbnail-Cache
if confirm "6. Browser-Caches & Thumbnails im Home-Verzeichnis löschen?"; then
    run_with_spinner "Lösche veraltete Caches..." bash -c "
        rm -rf '$REAL_HOME/.cache/thumbnails/'* 2>/dev/null || true
        rm -rf '$REAL_HOME/.cache/mozilla/firefox/'*.default*/cache2/* 2>/dev/null || true
        rm -rf '$REAL_HOME/.cache/google-chrome/'* 2>/dev/null || true
        rm -rf '$REAL_HOME/.cache/BraveSoftware/Brave-Browser/'* 2>/dev/null || true
    "
    echo -e "${GREEN}Home-Caches geleert.${NC}\n"
fi

# 7. Btrfs Balance
if findmnt -n -o FSTYPE / | grep -q "btrfs"; then
    if confirm "7. Btrfs Balance ausführen (gibt ungenutzten Speicherplatz frei)?"; then
        run_with_spinner "Führe btrfs balance aus..." btrfs balance start -dusage=10 /
        echo -e "${GREEN}Btrfs Balance abgeschlossen.${NC}\n"
    fi
fi

echo -e "\n${BLUE}${BOLD}=== Erfolgreich abgeschlossen! ===${NC}"
