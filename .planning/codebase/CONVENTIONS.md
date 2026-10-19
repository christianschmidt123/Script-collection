---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
# Coding Conventions

**Analysis Date:** 2026-10-19

> **Scope:** This is a personal shell-script collection. There is **no package manager, no linter, no formatter, and no CI** configured. Conventions below are derived from observed patterns across `media/photoprint/*.sh`, `media/clean/clean_videos.sh`, `system/cleanupCachyOS.sh`, `llm/setup-llm-coding.sh`, and `esphome/az-touch01-03esp32mcu/*.yaml`.

## Naming Patterns

**Files:**
- Shell scripts: lowercase, mostly **snake_case** — `photoprint.sh`, `photoprintcorrection.sh`, `photoresize.sh`, `photomaster.sh`, `clean_videos.sh`, `cleanupCachyOS.sh` (exception: camelCase), `setup-llm-coding.sh` (exception: kebab-case)
- ESPHome configs: lowercase with hyphens/digits — `demo.yaml`, `test.yaml`
- **Rule:** New scripts → `lowercase_snake_case.sh`. Do not mix kebab-case and camelCase; `cleanupCachyOS.sh` and `setup-llm-coding.sh` are legacy outliers to leave alone.

**Functions:**
- `snake_case`, verb-led, lowercase: `install_dependencies()`, `select_photo_format()`, `select_paper_format()`, `select_printer()`, `menu_correction()`, `menu_resize()`, `menu_print()`, `menu_full_workflow()`, `main_menu()`, `select_format()`, `select_dpi()`, `run_with_spinner()`, `confirm()`, `log_error()`, `find_with_size()`
- Single-word helpers allowed: `line()`
- **Rule:** Name interactive prompts `select_*`, menu handlers `menu_*`, the entrypoint `main_menu()`.

**Variables:**
- Constants / environment / computed config: `UPPER_SNAKE_CASE` — `SCRIPT_DIR`, `SRC_DIR`, `PHOTO_W`, `PHOTO_H`, `PAPER_W`, `PAPER_NAME`, `DPI`, `MAGICK_CMD`, `MONTAGE_CMD`, `TMP_DIR`, `OUTPUT_DIR`, `REAL_USER`, `REAL_HOME`, `LLAMA_DIR`, `MODEL_FILE`, `PORT`, `CTX_SIZE`, `NGL`
- Local mutable state / loop vars: `lowercase` — `count`, `file`, `f`, `choice`, `confirm`, `response`, `missing`, `page`, `start`
- ANSI colors as constants: `RED`, `GREEN`, `YELLOW`, `BLUE`, `BOLD`, `NC`
- **Rule:** Never lowercase a variable that is effectively a constant (e.g. `DPI`, `OUTPUT_DIR`). Use `local` inside functions.

**Types / IDs (ESPHome YAML):**
- Component `id:` values: `snake_case` — `my_display`, `my_touch`, `spi_bus`, `back_light`, `ha_temp_1`, `cold_boot_handled`
- Substitution keys: `snake_case` — `device_name`, `friendly_name`, `light_1_entity`, `color_bg`
- **Rule:** Quote entity IDs and substitution strings; keep ids stable (referenced by `id(...)` in lambdas).

## Code Style

**Formatting:**
- Indentation: **4 spaces** (dominant — all `media/photoprint/*.sh`, `media/clean/clean_videos.sh`, `llm/setup-llm-coding.sh`)
- Inconsistency: `system/cleanupCachyOS.sh` uses **2 spaces** (legacy — do not propagate)
- Line length: unbounded; wide box-drawing separators are normal
- **Rule:** New/edited scripts → 4 spaces, matching the photoprint suite.

**Linting:**
- No `shellcheck`, `.shellcheckrc`, `.editorconfig`, `.prettierrc`, `biome.json`, or `yamllint` config detected
- **Rule:** Run `shellcheck <script>` before committing new shell scripts (not yet wired into any pipeline).

**Shebangs:**
- `#!/bin/bash` — used by `media/photoprint/*.sh` and `media/clean/clean_videos.sh`
- `#!/usr/bin/env bash` — used by `system/cleanupCachyOS.sh` and `llm/setup-llm-coding.sh`
- **Rule:** New scripts → `#!/usr/bin/env bash` (portable). Mark executable with `chmod +x`.

**Language of comments & UI:**
- Comments and user-facing strings are **German**. Keep German for UI/comments in this repo; code identifiers stay English.

**Section separators (dominant pattern):**

```bash

# ---------------------------------------------------------------------------

# photoprint.sh – Fotos platzsparend auf Fotopapier drucken

# ---------------------------------------------------------------------------

```

Use the same `──` ruler style and a leading header block describing purpose in every script. Interactive TUIs additionally use Unicode box-drawing (`═`) and emoji in `photomaster.sh`.

## Script Structure & Execution Model

**Order (follow this):**
1. Shebang
2. `set -euo pipefail` (see note below)
3. Header comment block
4. Constants / config
5. Helper functions (all defined before first call)
6. Main logic / menu loop / entrypoint call

**Strict mode:**
- `set -euo pipefail` is used **only** in `llm/setup-llm-coding.sh` (line 7) and the generated `start-llm-server.sh` (line 112)
- The photoprint suite, `clean_videos.sh`, and `cleanupCachyOS.sh` run **without** strict mode
- **Rule:** New scripts → `set -euo pipefail`. When editing existing scripts, do not add it blindly (it can break unchecked `|| true` chains); convert incrementally.

**Subprocess invocation (no sourcing):**
- Scripts call sibling scripts as **subprocesses**, never `source`:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
(cd "$SRC_ORIG" && bash "$SCRIPT_DIR/photoprintcorrection.sh")
PHOTO_SRC_DIR="$RESIZE_OUT" bash "$SCRIPT_DIR/photoprint.sh"
```

- **Rule:** Use `SCRIPT_DIR` resolution + `bash "$SCRIPT_DIR/<script>.sh"`. Pass inter-script context via environment variables (`PHOTO_SRC_DIR`), not by sourcing.

**Dependency bootstrap (duplicated pattern):**
- `install_dependencies()` is copy-pasted across `photoprint.sh`, `photoprintcorrection.sh`, `photoresize.sh`
- Pattern: build a `missing=()` array via `command -v` checks, then branch on `apt-get` / `dnf` / `pacman` / `brew`, `exit 1` if none
- **Rule:** Reuse this shape for new scripts; consider extracting to a shared `lib/` helper eventually.

## Error Handling

**Patterns:**
- **Capability check before use:** `if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then ...` (`media/photoprint/*.sh`)
- **Fatal errors:** `echo "FEHLER: ..." >&2` + `exit 1` — e.g. missing folder in `photoprint.sh:138-141`, `photoresize.sh:121-124`, `clean_videos.sh:3-6`
- **Optional failure suppression:** `|| true` / `|| echo "..."` throughout `system/cleanupCachyOS.sh` (e.g. `snapper -c root cleanup timeline || true`)
- **Per-item error accumulation:** `log_error()` appends to an `errors_and_warnings` buffer, printed in the summary (`media/clean/clean_videos.sh:12-15`, `:214-219`)
- **Explicit return codes:** `return 0` when deps satisfied (`photoprint.sh:30`)
- **Privilege guard:** `if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi` (`system/cleanupCachyOS.sh:4-7`)
- **No `trap` for temp cleanup:** `photoprint.sh` creates `TMP_DIR=$(mktemp -d)` (line 204) but only removes it on the success path (line 262); an abort at the print confirmation (line 258) leaves temp files behind
- **Rule:** Use `exit 1` for unrecoverable, `|| true` only where failure is genuinely acceptable. Add `trap 'rm -rf "$TMP_DIR"' EXIT` when a script creates `mktemp -d`.

## Logging

**Framework:** Plain `echo` / `echo -e` (no logging library).

**Patterns:**
- **Colored helper functions** — `llm/setup-llm-coding.sh:28-30`:

```bash
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
```

- **Accumulating logger** — `media/clean/clean_videos.sh:12-15`:

```bash
log_error() {
    local msg="$1"
    errors_and_warnings+="$msg"$'\n'
}
```

- **Progress spinners** with `\r` and ANSI erase — `clean_videos.sh:39`, `:161`; `system/cleanupCachyOS.sh:18-38` (`run_with_spinner`)
- **ANSI palette** defined as constants at top: `RED/GREEN/YELLOW/BLUE/BOLD/NC`
- **Rule:** Prefix machine-parseable tags (`[INFO]`, `[WARN]`, `[ERROR]`) and reset color with `${NC}`. Send warnings/errors to `>&2` when they must not pollute piped output (`clean_videos.sh:161`).

## Comments

**When to Comment:**
- Every script starts with a header block: purpose, author-facing notes, supported formats, warnings
- Section dividers before each major block (`# ----`, `# STUFE 1: ...`, `# 1. ANALYSE-ABSCHNITT`)
- Inline German explanations for non-obvious logic (e.g. `photoprint.sh:121` v6/v7 note, `demo.yaml:118` LVGL rotation note)
- Hardware warnings as prominent comments (`demo.yaml:7` "Buzzer noch sehr heiß!", `test.yaml:10` white-screen workaround)
- **Rule:** Comment *why*, not *what*. Keep German for prose. Preserve `ACHTUNG`/`WICHTIG` warnings verbatim.

**JSDoc/TSDoc:**
- Not applicable (no JS/TS). No doc-comment standard exists.

## Function Design

**Size:** Functions are short and single-purpose (10–40 lines). `main_menu()` in `photomaster.sh` is the largest at ~34 lines and is a loop dispatcher.

**Parameters:**
- Positional only; use `local msg="$1"; shift` when forwarding (`run_with_spinner`, `cleanupCachyOS.sh:18-20`)
- Arrays passed via `"$@"` (`find "$@" ...`, `clean_videos.sh:22`)
- Prompts use `read -rp "..." var` and default via `${var:-default}` (`photomaster.sh:38-39`, `photoprint.sh:147-148`)

**Return Values:**
- `return 0` for success; `exit 1` for fatal; `true`/`false` from predicate helpers (`confirm()` returns via `case` — `cleanupCachyOS.sh:41-47`)
- No numeric return codes beyond 0/1

## Module Design

**Exports:** None — no `source`/import mechanism. Inter-script coupling is via subprocess + environment variables.

**Barrel Files:** Not applicable.

**Shared config:** ESPHome uses a `substitutions:` block as the single source of tunable values (`esphome/az-touch01-03esp32mcu/demo.yaml:9-24`). Mirror this "central config block at top" idea in shell scripts (constants block at top).

## Shell-Specific Conventions

- **Quote expansions:** `"$file"`, `"$SRC_DIR"`, `"${missing[@]}"`, `"${PHOTOS[@]:$START:$TILES_PER_PAGE}"`. Avoid unquoted word-splitting except where intentional (e.g. `$ORPHANS` in `cleanupCachyOS.sh:121` is an intentional split).
- **Arrays:** `declare -a PHOTOS`; append with `missing+=("imagemagick")`; length `${#arr[@]}`.
- **Default values:** `${VAR:-default}` for optional inputs.
- **Case menus:** `case "$choice" in 1) ... ;; q|Q|quit|exit) exit 0 ;; *) ... ;; esac`.
- **Confirmation:** `[[ "$confirm" =~ ^[jJyY]$ ]]` (accepts j/J/y/Y).
- **ImageMagick v6/v7 compat:** detect once and store the command:

```bash
if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"; MONTAGE_CMD="magick montage"
else
    MAGICK_CMD="convert"; MONTAGE_CMD="montage"
fi
```

  (`media/photoprint/photoprint.sh:122-128`)
- **Case-insensitive globs:** `shopt -s nocaseglob` … `shopt -u nocaseglob` around `*.jpg *.jpeg *.png *.tiff` loops (`photoresize.sh:143-161`).
- **Path safety:** `rm -f -- "$file"` to guard leading dashes (`clean_videos.sh:61`).

## ESPHome / YAML Conventions

- **Secrets:** never inline — use `!secret wifi_ssid`, `!secret api_encryption_key` (`demo.yaml:71-79`).
- **Central tunables:** `substitutions:` block at top with `${var}` references throughout (`demo.yaml:9-24`).
- **Lambdas:** single-quoted for simple returns (`lambda: 'return x;'`), block style `lambda: |-` for multi-line C++ (`demo.yaml:129-130`, `:363-369`).
- **GPIO:** reference pins by name (`GPIO18`, `GPIO23`) with comments explaining wiring (`test.yaml:44-47`).
- **Restore behavior:** explicit `restore_value` / `restore_mode` on globals and lights (`demo.yaml:51-57`, `:150`).
- **Rule:** Keep hardware gotchas documented as comments directly above the affected block (see `test.yaml:23-27` brick-risk warning).

---

*Convention analysis: 2026-10-19*
