#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Nutzung: $0 /pfad1 [/pfad2 /pfad3 ...]"
    exit 1
fi

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

                # Integritäts-Check (Größe >= 1MB + 1KB Header)
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
# STUFE 2: Inhaltsbasierte Prüfungen (Größe + MD5-Hash)
# ==============================================================================

echo
echo "[Stufe 2] Filter auf exakt gleich große Dateien..."

find_with_size() {
    find "$@" -maxdepth 1 -type f -printf '%s\t%p\n' 2>/dev/null || \
    find "$@" -maxdepth 1 -type f -exec stat -f "%z	%N" {} + 2>/dev/null
}

# Kandidaten (Dateien mit identischer Byte-Größe) in temporären Speicher laden
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

content_duplicates=""

if [[ -z "$candidates" || "$total_hash_candidates" -eq 0 ]]; then
    echo "[Stufe 2] Keine Dateien mit identischer Größe gefunden. Überspringe Hash-Prüfung."
else
    echo "Identische Größen gefunden für $total_hash_candidates Dateien. Starte Hash-Berechnung..."

    processed_hash_files=0

    # Kandidaten hashen und Fortschritt anzeigen
    hashed_results=$(
        while IFS=$'\t' read -r size file; do
            [[ -z "$file" ]] && continue
            
            ((processed_hash_files++))
            hash_percent=$(( processed_hash_files * 100 / total_hash_candidates ))
            
            # Ausgabe auf stderr (&2), damit es die Pipeline-Variable $hashed_results nicht verschmutzt
            echo -ne "\r[Stufe 2] Berechne Hashes... [${hash_percent}%] (${processed_hash_files}/${total_hash_candidates})\033[K" >&2

            hash=$(md5sum "$file" 2>/dev/null | awk '{print $1}')
            if [[ -n "$hash" ]]; then
                echo -e "${hash}\t${size}\t${file}"
            fi
        done <<< "$candidates"
    )
    echo -e "\r[Stufe 2] Berechne Hashes... [100%] Fertig!\033[K"

    # Auswertung der Hash-Ergebnisse auf Duplikate
    while read -r line; do
        [[ -z "$line" ]] && continue
        echo -e "\n$line"
        content_duplicates+="$line"$'\n'
    done < <(
        echo "$hashed_results" | sort | awk -F'\t' '
        BEGIN { prev_hash = "" }
        {
            hash = $1
            size = $2
            file = $3
            
            if (hash == prev_hash) {
                print "  [INHALTLICHES DUPLIKAT GEFUNDEN] " file
            } else {
                prev_hash = hash
            }
        }'
    )
fi

# ==============================================================================
# ZUSAMMENFASSUNG
# ==============================================================================

echo
echo "================================================"
echo "ZUSAMMENFASSUNG"
echo "================================================"
echo "$kept_count Dateien nach Namensschema behalten"
echo "$deleted_count Dateien gelöscht"
echo

if [[ -n "$content_duplicates" ]]; then
    echo "Gefundene inhaltliche Duplikate (andere Namen, identischer Inhalt):"
    echo -n "$content_duplicates"
    echo
else
    echo "Keine zusätzlichen inhaltlichen Duplikate gefunden."
    echo
fi

echo "Folgende Fehlermeldungen und Warnungen gab es:"
if [[ -n "$errors_and_warnings" ]]; then
    echo -n "$errors_and_warnings"
else
    echo "Keine Fehler oder Warnungen aufgetreten."
fi
echo "================================================"
