#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Nutzung: $0 /pfad1 [/pfad2 /pfad3 ...]"
    exit 1
fi

PARALLEL_HASH_JOBS=4  # 3-4 Threads optimal für HDDs
kept_count=0
deleted_count=0
errors_and_warnings=""

log_error() {
    local msg="$1"
    errors_and_warnings+="$msg"$'\n'
}

# ==============================================================================
# STUFE 1: Dateisystem scannen und nach Namen & Auflösung bereinigen
# ==============================================================================

echo -n "Zähle Quelldateien..."
total_files=$(find "$@" -maxdepth 1 -type f -name "*_[0-9]*p*" 2>/dev/null | wc -l | tr -d ' ')
echo -e "\rGefundene Dateien für Stufe 1: $total_files"

if [[ -z "$total_files" || "$total_files" -eq 0 ]]; then
    echo "Keine passenden Dateien mit Auflösungsmuster (_<Zahl>p) gefunden."
else
    processed_files=0

    while IFS= read -r -d '' group_block; do
        [[ -z "$group_block" ]] && continue

        file_count=$(grep -c $'\t' <<< "$group_block")
        best_found=0

        ((processed_files += file_count))
        percent=$(( processed_files * 100 / total_files ))
        
        echo -ne "\r[Stufe 1] Verarbeite Dateisystem... [${percent}%] (${processed_files}/${total_files})\033[K"

        while IFS=$'\t' read -r res file; do
            [[ -z "$file" ]] && continue

            if [[ $best_found -eq 0 ]]; then
                if [[ ! -f "$file" ]]; then
                    log_error "WARNUNG: Datei nicht mehr auffindbar: $file"
                    continue
                fi

                local_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)

                if [[ -n "$local_size" && "$local_size" -ge 1048576 ]] && head -c 1024 "$file" &>/dev/null; then
                    if (( file_count > 1 )); then
                        echo -e "\n  [BEHALTEN] $file (${res}p)"
                    fi
                    best_found=1
                    ((kept_count++))
                else
                    echo -e "\n  [DEFEKT - LÖSCHEN] $file"
                    if rm -f -- "$file" 2>/dev/null; then
                        ((deleted_count++))
                    else
                        log_error "FEHLER: Konnte defekte Datei nicht löschen: $file"
                    fi
                fi
            else
                if [[ -f "$file" ]]; then
                    echo -e "\n  [DUPLIKAT - LÖSCHEN] $file"
                    if rm -f -- "$file" 2>/dev/null; then
                        ((deleted_count++))
                    else
                        log_error "FEHLER: Konnte Duplikat nicht löschen: $file"
                    fi
                fi
            fi
        done <<< "$group_block"

    done < <(
        find "$@" -maxdepth 1 -type f -name "*_[0-9]*p*" 2>/dev/null | \
        awk '{
            path = $0
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
        }' | \
        sort -t$'\t' -k1,1 -k2,2nr | \
        awk -F'\t' '
        BEGIN { prev = "" }
        {
            if (NR > 1 && $1 != prev) {
                printf "\0"
            }
            printf "%s\t%s\n", $2, $3
            prev = $1
        }
        END { if (NR > 0) printf "\0" }
        '
    )
    echo -e "\r[Stufe 1] Verarbeite Dateisystem... [100%] Fertig!\033[K"
fi

# ==============================================================================
# STUFE 2: Inhaltsbasierte Prüfungen (High-Speed 2-Phasen Hash)
# ==============================================================================

echo
echo "[Stufe 2] Filter auf exakt gleich große Dateien..."

find_with_size() {
    find "$@" -maxdepth 1 -type f -printf '%s\t%p\n' 2>/dev/null || \
    find "$@" -maxdepth 1 -type f -exec stat -f "%z	%N" {} + 2>/dev/null
}

candidates=$(
    find_with_size "$@" | \
    sort -t$'\t' -k1,1n | \
    awk -F'\t' '
    BEGIN { prev_size = ""; saved = "" }
    {
        if ($1 == prev_size) {
            if (saved != "") { print saved; saved = "" }
            print $0
        } else {
            saved = $0
            prev_size = $1
        }
    }'
)

total_hash_candidates=$(grep -c $'\t' <<< "$candidates")

# Hash-Funktion mit variabler Read-Größe (128 KB oder 1 MB)
chunk_hash() {
    local line="$1"
    local bytes="$2"
    [[ -z "$line" ]] && return

    local size file hash
    size=$(echo "$line" | cut -f1)
    file=$(echo "$line" | cut -f2-)

    [[ -z "$file" || ! -f "$file" ]] && return

    if command -v xxh128sum &>/dev/null; then
        hash=$(head -c "$bytes" "$file" 2>/dev/null | xxh128sum | awk '{print $1}')
    elif command -v xxhsum &>/dev/null; then
        hash=$(head -c "$bytes" "$file" 2>/dev/null | xxhsum | awk '{print $1}')
    else
        hash=$(head -c "$bytes" "$file" 2>/dev/null | md5sum | awk '{print $1}')
    fi

    if [[ -n "$hash" ]]; then
        echo -e "${hash}\t${size}\t${file}"
    fi
}
export -f chunk_hash

dup_files_to_delete=()

if [[ -z "$candidates" || "$total_hash_candidates" -eq 0 ]]; then
    echo "[Stufe 2] Keine Dateien mit identischer Größe gefunden. Überspringe Hash-Prüfung."
else
    echo "Identische Größen für $total_hash_candidates Dateien gefunden."
    
    # --- PHASE 1: Sensationell schneller 128KB Header-Hash ---
    echo "[Stufe 2 - Phase 1/2] Ultra-Fast Header Check (128 KB) mit $PARALLEL_HASH_JOBS Threads..."
    phase1_results=$(
        printf "%s\n" "$candidates" | \
        xargs -d '\n' -P "$PARALLEL_HASH_JOBS" -I {} bash -c 'chunk_hash "{}" 131072'
    )

    # Nur die Dateien herausfiltern, die SELBST IM 128KB HEADER identisch sind
    phase2_candidates=$(
        echo "$phase1_results" | grep -v '^$' | sort -t$'\t' -k1,1 | awk -F'\t' '
        BEGIN { prev_hash = ""; group = "" }
        {
            if ($1 == prev_hash) {
                if (group != "") { print group; group = "" }
                print $2 "\t" $3
            } else {
                group = $2 "\t" $3
                prev_hash = $1
            }
        }'
    )

    total_p2_candidates=$(grep -c $'\t' <<< "$phase2_candidates")

    if [[ -z "$phase2_candidates" || "$total_p2_candidates" -eq 0 ]]; then
        echo "[Stufe 2] Keine echten Header-Kollisionen. Keine Duplikate vorhanden!"
        final_hashed_results=""
    else
        # --- PHASE 2: Nur verbleibende Verdachtsfälle mit 1 MB verifizieren ---
        echo "[Stufe 2 - Phase 2/2] Verifiziere $total_p2_candidates verbleibende Kandidaten (1 MB Check)..."
        final_hashed_results=$(
            printf "%s\n" "$phase2_candidates" | \
            xargs -d '\n' -P "$PARALLEL_HASH_JOBS" -I {} bash -c 'chunk_hash "{}" 1048576'
        )
    fi

    echo -e "[Stufe 2] Abgleich abgeschlossen!\033[K\n"

    # Auswertung und Gruppen-Anzeige
    current_hash=""
    group_counter=0

    echo "================================================"
    echo "GEFUNDENE INHALTLICHE DUPLIKATE (STUFE 2)"
    echo "================================================"

    if [[ -n "$final_hashed_results" ]]; then
        while IFS=$'\t' read -r hash size file; do
            [[ -z "$file" ]] && continue

            if [[ "$hash" != "$current_hash" ]]; then
                current_hash="$hash"
                ((group_counter++))
                echo
                echo "--- Gruppe $group_counter (Größe: $((size / 1024 / 1024)) MB) ---"
                echo "  [REFERENZ - BEHALTEN] $file"
            else
                echo "  [DUPLIKAT - ZUM LÖSCHEN EMPFOHLEN] $file"
                dup_files_to_delete+=("$file")
            fi
        done < <(
            echo "$final_hashed_results" | grep -v '^$' | sort -t$'\t' -k1,1 -k2,2n | awk -F'\t' '
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

    # Interaktives Löschmenü für Stufe 2
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
                        ((deleted_count++))
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
                            ((deleted_count++))
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
