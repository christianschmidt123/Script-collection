#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Nutzung: $0 /pfad1 [/pfad2 /pfad3 ...]"
    exit 1
fi

PARALLEL_HASH_JOBS=4          # 3-4 Threads optimal für HDDs, mehr für SSDs
HASH_BATCH_SIZE=50            # Dateien pro bash -c Aufruf
USE_TWO_PHASE_HASH=1          # 1 = 128KB-Header-Check vor Vollhash, 0 = direkt voll hashen
PHASE1_BYTES=131072           # 128 KB
PHASE2_BYTES=1048576          # 1 MB
MIN_SIZE_BYTES=1048576        # 1 MB - kleinere Dateien gelten als defekt in Stufe 1

kept_count=0
deleted_count=0
errors_and_warnings=""

log_error() {
    errors_and_warnings+="$1"$'\n'
}

# Temporäre Dateien anlegen und bei Exit aufräumen
SCAN_FILE=$(mktemp -t mediadup_scan.XXXXXX)
PHASE1_FILE=$(mktemp -t mediadup_p1.XXXXXX)
PHASE2_FILE=$(mktemp -t mediadup_p2.XXXXXX)
FINAL_FILE=$(mktemp -t mediadup_final.XXXXXX)
trap 'rm -f "$SCAN_FILE" "$PHASE1_FILE" "$PHASE2_FILE" "$FINAL_FILE"' EXIT

# ==============================================================================
# VORBEREITUNG: Dateisystem EINMAL scannen
# ==============================================================================

echo "Scanne Dateisystem (rekursiv)..."

# Eine Zeile pro Datei: <size>\t<path>
# GNU find bevorzugt, BSD-Fallback via stat
if find "$@" -type f -printf '%s\t%p\n' > "$SCAN_FILE" 2>/dev/null; then
    :
else
    # BSD/macOS Fallback
    find "$@" -type f -exec stat -f "%z %N" {} + > "$SCAN_FILE" 2>/dev/null
fi

total_scanned=$(wc -l < "$SCAN_FILE" | tr -d ' ')
echo "Insgesamt $total_scanned Dateien gefunden (rekursiv)."
echo

if [[ "$total_scanned" -eq 0 ]]; then
    echo "Keine Dateien gefunden. Abbruch."
    exit 0
fi

# ==============================================================================
# STUFE 1: Nach Namen & Auflösung bereinigen (nur Dateien mit _<Zahl>p im Namen)
# ==============================================================================

echo "[Stufe 1] Filtere nach Namensmuster *_<Zahl>p*..."

# Kandidaten aus Scan-Datei extrahieren: nur der Pfad (Spalte 2)
# Muster: Dateiname enthält _<Zahl>p
awk -F'\t' '
{
    path = $2
    n = split(path, parts, "/")
    filename = parts[n]

    if (match(filename, /_[0-9]+p/)) {
        res_str = substr(filename, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", res_str)
        base = substr(filename, 1, RSTART - 1)
        if (base != "" && res_str != "") {
            print base "\t" res_str "\t" path
        }
    }
}
' "$SCAN_FILE" > "$PHASE1_FILE"

total_files=$(wc -l < "$PHASE1_FILE" | tr -d ' ')
echo "Gefundene Dateien für Stufe 1: $total_files"

if [[ "$total_files" -eq 0 ]]; then
    echo "Keine passenden Dateien mit Auflösungsmuster (_<Zahl>p) gefunden."
else
    # Sortieren: Basisname aufsteigend, Auflösung absteigend (höchste zuerst)
    # Danach mit \0 als Gruppentrenner ausgeben
    sorted_grouped=$(
        sort -t$'\t' -k1,1 -k2,2nr "$PHASE1_FILE" | \
        awk -F'\t' '
        BEGIN { prev = "" }
        {
            if (NR > 1 && $1 != prev) printf "\0"
            printf "%s\t%s\n", $2, $3
            prev = $1
        }
        END { if (NR > 0) printf "\0" }
        '
    )

    processed_files=0

    while IFS= read -r -d '' group_block; do
        [[ -z "$group_block" ]] && continue

        file_count=$(wc -l <<< "$group_block" | tr -d ' ')
        best_found=0

        ((processed_files += file_count))
        percent=$(( processed_files * 100 / total_files ))

        echo -ne "\r[Stufe 1] Verarbeite... [${percent}%] (${processed_files}/${total_files})\033[K"

        while IFS=$'\t' read -r res file; do
            [[ -z "$file" ]] && continue

            if [[ $best_found -eq 0 ]]; then
                if [[ ! -f "$file" ]]; then
                    log_error "WARNUNG: Datei nicht mehr auffindbar: $file"
                    continue
                fi

                local_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)

                if [[ -n "$local_size" && "$local_size" -ge "$MIN_SIZE_BYTES" ]] && head -c 1024 "$file" &>/dev/null; then
                    if (( file_count > 1 )); then
                        echo -e "\n  [BEHALTEN] $file (${res}p)"
                    fi
                    best_found=1
                    ((kept_count++)) || true
                else
                    echo -e "\n  [DEFEKT - LÖSCHEN] $file"
                    if rm -f -- "$file" 2>/dev/null; then
                        ((deleted_count++)) || true
                    else
                        log_error "FEHLER: Konnte defekte Datei nicht löschen: $file"
                    fi
                fi
            else
                if [[ -f "$file" ]]; then
                    echo -e "\n  [DUPLIKAT - LÖSCHEN] $file"
                    if rm -f -- "$file" 2>/dev/null; then
                        ((deleted_count++)) || true
                    else
                        log_error "FEHLER: Konnte Duplikat nicht löschen: $file"
                    fi
                fi
            fi
        done <<< "$group_block"

    done < <(printf '%s' "$sorted_grouped")

    echo -e "\r[Stufe 1] Verarbeite... [100%] Fertig!\033[K"
fi

# ==============================================================================
# STUFE 2: Inhaltsbasierte Prüfungen
# ==============================================================================

echo
echo "[Stufe 2] Filter auf exakt gleich große Dateien..."

# Aus Scan-Datei nur Größen mit >= 2 Vorkommen extrahieren
# Format: <size>\t<path>
candidates_file=$(mktemp -t mediadup_cand.XXXXXX)
trap 'rm -f "$SCAN_FILE" "$PHASE1_FILE" "$PHASE2_FILE" "$FINAL_FILE" "$candidates_file"' EXIT

sort -t$'\t' -k1,1n "$SCAN_FILE" | awk -F'\t' '
BEGIN { prev_size = ""; saved = "" }
{
    if ($1 == prev_size) {
        if (saved != "") { print saved; saved = "" }
        print $0
    } else {
        saved = $0
        prev_size = $1
    }
}
' > "$candidates_file"

total_hash_candidates=$(wc -l < "$candidates_file" | tr -d ' ')

# Hash-Funktion mit variabler Read-Größe
# Wird via xargs batched aufgerufen
chunk_hash() {
    local bytes="$1"
    shift
    local line size file hash

    for line in "$@"; do
        [[ -z "$line" ]] && continue

        size=$(cut -f1 <<< "$line")
        file=$(cut -f2- <<< "$line")

        [[ -z "$file" || ! -f "$file" ]] && continue

        if command -v xxh128sum &>/dev/null; then
            hash=$(head -c "$bytes" "$file" 2>/dev/null | xxh128sum | awk '{print $1}')
        elif command -v xxhsum &>/dev/null; then
            hash=$(head -c "$bytes" "$file" 2>/dev/null | xxhsum | awk '{print $1}')
        else
            hash=$(head -c "$bytes" "$file" 2>/dev/null | md5sum | awk '{print $1}')
        fi

        if [[ -n "$hash" ]]; then
            printf '%s\t%s\t%s\n' "$hash" "$size" "$file"
        fi
    done
}
export -f chunk_hash

dup_files_to_delete=()

if [[ "$total_hash_candidates" -eq 0 ]]; then
    echo "[Stufe 2] Keine Dateien mit identischer Größe gefunden. Überspringe Hash-Prüfung."
else
    echo "Identische Größen für $total_hash_candidates Dateien gefunden."

    if [[ "$USE_TWO_PHASE_HASH" -eq 1 ]]; then
        # --- PHASE 1: 128 KB Header-Hash ---
        echo "[Stufe 2 - Phase 1/2] Ultra-Fast Header Check (128 KB) mit $PARALLEL_HASH_JOBS Threads..."

        # Batch-Verarbeitung: alle Zeilen an einen bash -c Aufruf übergeben
        xargs -d '\n' -P "$PARALLEL_HASH_JOBS" -n "$HASH_BATCH_SIZE" \
            bash -c 'chunk_hash "$0" "$@"' "$PHASE1_BYTES" \
            < "$candidates_file" > "$PHASE1_FILE"

        # Nur Dateien behalten, die im 128KB-Header identisch sind (>= 2 pro Hash)
        sort -t$'\t' -k1,1 "$PHASE1_FILE" | awk -F'\t' '
        BEGIN { prev_hash = ""; group = "" }
        {
            if ($1 == prev_hash) {
                if (group != "") { print group; group = "" }
                print $2 "\t" $3
            } else {
                group = $2 "\t" $3
                prev_hash = $1
            }
        }
        ' > "$PHASE2_FILE"

        total_p2_candidates=$(wc -l < "$PHASE2_FILE" | tr -d ' ')

        if [[ "$total_p2_candidates" -eq 0 ]]; then
            echo "[Stufe 2] Keine echten Header-Kollisionen. Keine Duplikate vorhanden!"
            : > "$FINAL_FILE"
        else
            # --- PHASE 2: 1 MB Verify ---
            echo "[Stufe 2 - Phase 2/2] Verifiziere $total_p2_candidates verbleibende Kandidaten (1 MB Check)..."
            xargs -d '\n' -P "$PARALLEL_HASH_JOBS" -n "$HASH_BATCH_SIZE" \
                bash -c 'chunk_hash "$0" "$@"' "$PHASE2_BYTES" \
                < "$PHASE2_FILE" > "$FINAL_FILE"
        fi
    else
        # --- DIREKT: Vollhash (schneller bei SSDs oder wenn xxh128 verfügbar) ---
        echo "[Stufe 2] Direkter Vollhash mit $PARALLEL_HASH_JOBS Threads..."
        # Größe = ganze Datei: wir nutzen eine sehr große Zahl, head liest bis EOF
        xargs -d '\n' -P "$PARALLEL_HASH_JOBS" -n "$HASH_BATCH_SIZE" \
            bash -c 'chunk_hash "$0" "$@"' "9999999999999" \
            < "$candidates_file" > "$FINAL_FILE"
    fi

    echo "[Stufe 2] Abgleich abgeschlossen!"

    # Auswertung und Gruppen-Anzeige
    current_hash=""
    group_counter=0

    echo "================================================"
    echo "GEFUNDENE INHALTLICHE DUPLIKATE (STUFE 2)"
    echo "================================================"

    if [[ -s "$FINAL_FILE" ]]; then
        while IFS=$'\t' read -r hash size file; do
            [[ -z "$file" ]] && continue

            if [[ "$hash" != "$current_hash" ]]; then
                current_hash="$hash"
                ((group_counter++)) || true
                echo
                echo "--- Gruppe $group_counter (Größe: $((size / 1024 / 1024)) MB) ---"
                echo "  [REFERENZ - BEHALTEN] $file"
            else
                echo "  [DUPLIKAT - ZUM LÖSCHEN EMPFOHLEN] $file"
                dup_files_to_delete+=("$file")
            fi
        done < <(
            sort -t$'\t' -k1,1 -k2,2n "$FINAL_FILE" | awk -F'\t' '
            BEGIN { prev_hash = ""; group = "" }
            {
                if ($1 == prev_hash) {
                    if (group != "") { print group; group = "" }
                    print $0
                } else {
                    group = $0
                    prev_hash = $1
                }
            }'
        )
    fi

    echo "================================================"
    echo

    # Interaktives Löschmenü
    if [[ ${#dup_files_to_delete[@]} -gt 0 ]]; then
        echo "Es wurden ${#dup_files_to_delete[@]} inhaltliche Duplikate in $group_counter Gruppen gefunden."
        echo
        echo "Wie möchtest du mit den inhaltlichen Duplikaten verfahren?"
        echo "  [1] Alle gefundene Duplikate automatisch löschen (Referenz-Dateien bleiben erhalten)"
        echo "  [2] Jede Duplikat-Datei einzeln bestätigen"
        echo "  [3] Gar nichts löschen (nur anzeigen)"
        echo
        read -p "Deine Auswahl [1/2/3]: " choice < /dev/tty

        case "$choice" in
            1)
                echo "Lösche ${#dup_files_to_delete[@]} inhaltliche Duplikate..."
                for f in "${dup_files_to_delete[@]}"; do
                    if rm -f -- "$f" 2>/dev/null; then
                        echo "  [GELÖSCHT] $f"
                        ((deleted_count++)) || true
                    else
                        log_error "FEHLER: Konnte inhaltliches Duplikat nicht löschen: $f"
                    fi
                done
                ;;
            2)
                for f in "${dup_files_to_delete[@]}"; do
                    read -p "Soll '$f' gelöscht werden? [y/N]: " confirm < /dev/tty
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        if rm -f -- "$f" 2>/dev/null; then
                            echo "  [GELÖSCHT] $f"
                            ((deleted_count++)) || true
                        else
                            log_error "FEHLER: Konnte $f nicht löschen."
                        fi
                    else
                        echo "  [ÜBERSPRUNGEN] $f"
                    fi
                done
                ;;
            *)
                echo "Keine inhaltlichen Duplikate gelöscht."
                ;;
        esac
    else
        echo "Keine inhaltlichen Duplikate gefunden."
    fi
fi

# ==============================================================================
# ZUSAMMENFASSUNG
# ==============================================================================

echo
echo "================================================"
echo "ZUSAMMENFASSUNG"
echo "================================================"
echo "$kept_count Dateien aus Stufe 1 behalten"
echo "$deleted_count Dateien insgesamt gelöscht"
echo

echo "Folgende Fehlermeldungen und Warnungen gab es:"
if [[ -n "$errors_and_warnings" ]]; then
    echo -n "$errors_and_warnings"
else
    echo "Keine Fehler oder Warnungen aufgetreten."
fi
echo "================================================"
