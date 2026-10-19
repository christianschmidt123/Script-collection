# Architecture Research

**Domain:** Handyman utility script collection (shell/bash)
**Researched:** 2026-10-19
**Confidence:** HIGH

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           User / Terminal                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │ Orchestrator │   │  Standalone  │   │  Standalone  │   │  Standalone  │  │
│  │ photomaster  │   │  photoprint  │   │  photoresize │   │ cleanupCachy │  │
│  │   .sh        │   │    .sh       │   │    .sh       │   │   OS.sh      │  │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘   └──────┬───────┘  │
│         │                  │                  │                  │          │
│         │  subprocess      │  subprocess      │  subprocess      │          │
│         │  (bash + env)    │  (bash + env)    │  (bash + env)    │          │
│         ▼                  ▼                  ▼                  ▼          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    Filesystem (shared state)                          │  │
│  │  <src>/ → <src>/druckbereit/ → <src>/druckbereit/skaliert_*/ → lp    │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│         │                  │                  │                  │          │
│         ▼                  ▼                  ▼                  ▼          │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│  │ ImageMagick  │   │ ImageMagick  │   │ ImageMagick  │   │ pacman/snap- │  │
│  │ (external)   │   │ (external)   │   │ (external)   │   │ per/docker   │  │
│  └──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘  │
│                                                                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                     OS / Package Manager / CUPS                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Orchestrator** (`photomaster.sh`) | Menu dispatcher, workflow chaining | `case` statement → `bash "$SCRIPT_DIR/<script>.sh"` |
| **Pipeline scripts** (`photoprintcorrection.sh`, `photoresize.sh`, `photoprint.sh`) | Single-task processing with input/output folders | `install_dependencies()` → `select_*()` prompts → process loop |
| **Standalone utilities** (`cleanupCachyOS.sh`, `clean_videos.sh`) | One-shot system/media maintenance | sudo guard → color/spinner helpers → confirm() → cleanup logic |
| **Filesystem** | Inter-script data handoff | Output folder of stage N = input folder of stage N+1 |
| **Environment variables** | Non-interactive context passing | `PHOTO_SRC_DIR="$OUT" bash next_script.sh` |

## Recommended Project Structure

```
Script-collection/
├── system/                          # System maintenance utilities
│   ├── cleanupCachyOS.sh            # Existing: CachyOS cleanup (sudo, pacman, snapper, docker)
│   ├── cleanup_generic.sh           # Future: distro-agnostic cleanup
│   ├── disk_usage_report.sh         # Future: disk usage analyzer
│   └── find_large_files.sh          # Future: large file finder
├── media/
│   ├── photoprint/                  # Photo printing pipeline
│   │   ├── photomaster.sh           # Orchestrator (menu → dispatch)
│   │   ├── photoprintcorrection.sh  # Stage 1: Color correction
│   │   ├── photoresize.sh           # Stage 2: Resize to print format
│   │   └── photoprint.sh            # Stage 3: N-up montage + CUPS print
│   ├── clean/                       # Media cleanup
│   │   ├── clean_videos.sh          # Existing: Video duplicate cleaner
│   │   ├── clean_photos.sh          # Future: Photo duplicate/orphan cleaner
│   │   └── organize_media.sh        # Future: Sort media by date/type
│   └── convert/                     # Media conversion
│       ├── batch_webp.sh            # Future: Convert images to WebP
│       └── video_compress.sh        # Future: Batch video compression
├── lib/                             # Shared shell functions (future)
│   ├── common.sh                    # install_dependencies(), confirm(), run_with_spinner()
│   ├── logging.sh                   # info(), warn(), error() with colors
│   └── filesystem.sh                # safe_mkdir(), find_with_size(), resolve_path()
├── llm/                             # LLM server setup
│   └── setup-llm-coding.sh          # Existing: llama.cpp + Gemma 4 setup
├── esphome/                         # ESP32 device configurations
│   └── az-touch01-03esp32mcu/
│       ├── demo.yaml
│       └── test.yaml
├── README.md                        # Project overview + script index
└── Makefile                         # Optional: `make photo`, `make cleanup` shortcuts
```

### Structure Rationale

- **`system/`:** Groups all OS-level maintenance. Scripts here need sudo, interact with package managers, and clean system-level artifacts (caches, logs, snapshots).
- **`media/`:** Groups all media processing. Subdivided by task type (`photoprint/`, `clean/`, `convert/`). Each subdirectory is a mini-pipeline with its own orchestrator if needed.
- **`lib/`:** Shared shell functions extracted from duplicated patterns. Not scripts — sourced by other scripts via `source "$SCRIPT_DIR/../lib/common.sh"`. Only introduce when duplication becomes painful (3+ copies of the same function).
- **Top-level categories:** Each top-level directory is a domain the user reaches for. Adding a new domain = new top-level directory.

## Architectural Patterns

### Pattern 1: Pipeline with Filesystem Handoff

**What:** Multi-stage processing where each stage reads from a folder and writes to a new folder. The next stage reads from that output folder.

**When to use:** Any multi-step media processing workflow (correct → resize → print, or dedup → convert → organize).

**Trade-offs:**
- ✅ Simple to understand — each script does one thing
- ✅ Stages can be run independently
- ✅ Intermediate results are inspectable on disk
- ❌ Filesystem coupling — no type safety on what's in the folder
- ❌ Disk usage doubles at each stage

**Example:**
```bash
# Stage 1: correction writes to <src>/druckbereit/
(cd "$SRC_ORIG" && bash "$SCRIPT_DIR/photoprintcorrection.sh")
CORRECTION_OUT="$(realpath "$SRC_ORIG")/druckbereit"

# Stage 2: resize reads from druckbereit/, writes to druckbereit/skaliert_*/
PHOTO_SRC_DIR="$CORRECTION_OUT" bash "$SCRIPT_DIR/photoresize.sh"
RESIZE_OUT=$(ls -dt "$CORRECTION_OUT"/skaliert_* 2>/dev/null | head -1)

# Stage 3: print reads from skaliert_*/
PHOTO_SRC_DIR="$RESIZE_OUT" bash "$SCRIPT_DIR/photoprint.sh"
```

### Pattern 2: Orchestrator / Menu Dispatcher

**What:** A top-level script with an interactive `case` menu that dispatches to individual task scripts via subprocess calls.

**When to use:** When a domain has 3+ related scripts and the user wants a single entry point.

**Trade-offs:**
- ✅ Single entry point — user runs one script, gets all options
- ✅ Each task script remains independently runnable
- ✅ Easy to add new tasks — just add a `case` branch
- ❌ Orchestrator becomes a maintenance burden if it grows too large
- ❌ Subprocess calls mean no shared state (must use env vars or files)

**Example:**
```bash
main_menu() {
    while true; do
        clear
        echo "  1)  Farbkorrektur"
        echo "  2)  Fotos skalieren"
        echo "  3)  Fotos drucken"
        echo "  4)  Kompletter Workflow"
        echo "  q)  Beenden"
        read -rp "Auswahl: " choice
        case "$choice" in
            1) menu_correction ;;
            2) menu_resize ;;
            3) menu_print ;;
            4) menu_full_workflow ;;
            q|Q|quit|exit) exit 0 ;;
            *) echo "Ungültige Auswahl."; sleep 1 ;;
        esac
    done
}
```

### Pattern 3: Subprocess Isolation (No Sourcing)

**What:** Scripts call sibling scripts as subprocesses (`bash "$SCRIPT_DIR/script.sh"`), never via `source`. Context is passed via environment variables.

**When to use:** Always, for inter-script communication in this collection.

**Trade-offs:**
- ✅ Full isolation — a crash in one script doesn't corrupt the caller's state
- ✅ Scripts can be run independently from any directory
- ✅ `SCRIPT_DIR` resolution makes scripts location-independent
- ❌ Environment variables are the only channel (limited to strings)
- ❌ Subprocess startup overhead (negligible for interactive scripts)

**Example:**
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHOTO_SRC_DIR="$RESIZE_OUT" bash "$SCRIPT_DIR/photoprint.sh"
```

### Pattern 4: Duplicated Dependency Bootstrap

**What:** Each script carries its own `install_dependencies()` function that checks for required tools and installs them via the detected package manager.

**When to use:** For standalone scripts that may be run on a fresh system.

**Trade-offs:**
- ✅ Self-contained — grab any script, run it, works
- ✅ No external setup needed
- ❌ Code duplication across scripts
- ❌ Updating the pattern means updating every script

**Example:**
```bash
install_dependencies() {
    local missing=()
    if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
        missing+=("imagemagick")
    fi
    if [ ${#missing[@]} -eq 0 ]; then return 0; fi
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq && sudo apt-get install -y "${missing[@]}"
    elif command -v pacman &>/dev/null; then
        sudo pacman -Sy --noconfirm "${missing[@]}"
    # ... dnf, brew
    fi
}
```

### Pattern 5: Interactive Confirmation with Defaults

**What:** Every destructive or irreversible action is gated behind a `confirm()` prompt with a safe default (No).

**When to use:** Any script that deletes files, modifies system state, or prints.

**Trade-offs:**
- ✅ Prevents accidental data loss
- ✅ Non-interactive mode possible via `echo "j" | script.sh` or env var bypass
- ❌ Adds friction for repeated use
- ❌ Can be bypassed with `|| true` chains (as seen in `cleanupCachyOS.sh`)

**Example:**
```bash
confirm() {
    read -rp "$(echo -e "${BOLD}$1${NC} [j/N]: ")" response
    case "$response" in
        [jJ][eE][sS]|[jJ]) true ;;
        *) false ;;
    esac
}

if confirm "Alte Snapshots aufräumen?"; then
    snapper -c root cleanup timeline
fi
```

## Data Flow

### Pipeline Flow (Photo Printing)

```
User runs photomaster.sh
    ↓
photomaster.sh → menu_correction()
    ↓ (cd "$SRC" && bash photoprintcorrection.sh)
photoprintcorrection.sh reads *.jpg from $SRC
    ↓ writes corrected to $SRC/druckbereit/
photomaster.sh → menu_resize()
    ↓ (PHOTO_SRC_DIR="$SRC/druckbereit" bash photoresize.sh)
photoresize.sh reads *.jpg from $PHOTO_SRC_DIR
    ↓ writes resized to $PHOTO_SRC_DIR/skaliert_<format>/
photomaster.sh → menu_print()
    ↓ (PHOTO_SRC_DIR="$RESIZE_OUT" bash photoprint.sh)
photoprint.sh reads *.jpg from $PHOTO_SRC_DIR
    ↓ creates N-up montage TIFFs in $TMP_DIR
    ↓ sends to CUPS via lp
Print job queued
```

### Standalone Flow (System Cleanup)

```
User runs cleanupCachyOS.sh
    ↓
sudo guard → re-exec as root
    ↓
ANALYSE: df, du, journalctl, docker system df → print report
    ↓
INTERACTIVE: confirm() → run_with_spinner() → cleanup command
    ↓
snapper cleanup / paccache / docker prune / journalctl vacuum
    ↓
Summary printed
```

### Key Data Flows

1. **Filesystem handoff:** Output directory of one pipeline stage becomes the input directory of the next. The orchestrator resolves the path and passes it via `PHOTO_SRC_DIR`.
2. **Environment variable propagation:** `PHOTO_SRC_DIR` is set before calling the next script. The child script checks for it at startup and skips the interactive source-folder prompt.
3. **Subprocess boundary:** Each script is a fresh bash process. No shared memory, no exported functions. All state transfer is via filesystem or environment variables.

## Build Order & Dependencies

### Script Dependency Graph

```
photomaster.sh (orchestrator)
 ├── photoprintcorrection.sh  [no deps]
 ├── photoresize.sh           [no deps]
 └── photoprint.sh            [no deps]
     (all three depend on: imagemagick, bc, cups)

cleanupCachyOS.sh [standalone — depends on: pacman, snapper, docker (optional)]

clean_videos.sh   [standalone — depends on: find, md5sum]

Future scripts:
 ├── clean_photos.sh          [depends on: find, md5sum, imagemagick]
 ├── disk_usage_report.sh     [depends on: df, du, ncdu (optional)]
 ├── find_large_files.sh      [depends on: find, du]
 └── lib/common.sh            [no deps — sourced by all]
```

### Suggested Build Order

1. **Phase 1: Photo pipeline** — Already exists and works. Validate and document.
2. **Phase 2: System utilities** — Build `disk_usage_report.sh` and `find_large_files.sh` alongside existing `cleanupCachyOS.sh`. These are standalone, low-risk, high-value.
3. **Phase 3: Media cleanup** — Build `clean_photos.sh` using patterns from `clean_videos.sh` (duplicate detection via hash).
4. **Phase 4: Extract lib/** — Once 3+ scripts share a pattern (e.g., `install_dependencies()`, `confirm()`, `run_with_spinner()`), extract to `lib/common.sh`. Convert scripts incrementally.

### Build Order Rationale

- **Photo pipeline first:** Already built, proves the architecture, provides reference patterns.
- **System utilities next:** Standalone, no pipeline complexity, immediate daily value.
- **Media cleanup third:** Builds on proven patterns from system utilities + photo pipeline.
- **lib/ extraction last:** Premature abstraction is worse than duplication. Wait for 3+ instances.

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Personal use (current) | Current architecture is fine — flat directories, duplicated helpers, subprocess isolation |
| 5–10 scripts per domain | Add orchestrator script per domain (like `photomaster.sh`) |
| 15+ scripts | Extract `lib/common.sh`, add `Makefile` with domain shortcuts |
| Shared across machines | Add `install.sh` that symlinks scripts to `~/bin/`, moves `lib/` to `~/.config/script-collection/` |

### Scaling Priorities

1. **First bottleneck:** Code duplication in `install_dependencies()` and `confirm()`. Fix by extracting to `lib/common.sh` when the third script needs it.
2. **Second bottleneck:** Orchestrator sprawl. When `photomaster.sh` exceeds ~5 menu items, split into domain-specific orchestrators (e.g., `media-master.sh`, `system-master.sh`).

## Anti-Patterns

### Anti-Pattern 1: Sourcing Sibling Scripts

**What people do:** `source "$SCRIPT_DIR/photoprint.sh"` or `. "$SCRIPT_DIR/photoresize.sh"`
**Why it's wrong:** The sourced script runs in the caller's shell — variables leak, `exit 1` kills the caller, `read` prompts steal stdin from the orchestrator. Subprocess isolation is the correct pattern.
**Do this instead:** `PHOTO_SRC_DIR="$OUT" bash "$SCRIPT_DIR/photoprint.sh"`

### Anti-Pattern 2: Hardcoded Absolute Paths

**What people do:** `SRC="/home/chris/photos"` or `rm -rf /var/cache/pacman/pkg/*`
**Why it's wrong:** Scripts break when moved to another machine or when the user's home differs. Destructive paths without variables are dangerous.
**Do this instead:** Accept paths as arguments or interactive input, default to `.`. Use `rm -rf -- "$VAR"/*` with a variable.

### Anti-Pattern 3: No Confirmation Before Destructive Actions

**What people do:** `rm -rf "$TMP_DIR"` or `docker system prune -a -f` without asking.
**Why it's wrong:** A script that deletes without asking will eventually delete the wrong thing.
**Do this instead:** Gate every `rm`, `prune`, `cleanup`, or `delete` behind `confirm()` with a safe default.

### Anti-Pattern 4: Silent Failure with `|| true` Chains

**What people do:** `pacman -Rns $ORPHANS --noconfirm || true` — swallow all errors.
**Why it's wrong:** When something goes wrong, you can't tell what failed. The `cleanupCachyOS.sh` script is riddled with this pattern.
**Do this instead:** Let errors surface. If failure is expected, add a comment explaining why. Use `|| echo "Warnung: ..."` instead of `|| true`.

### Anti-Pattern 5: Monolithic Scripts

**What people do:** One 500-line script that does analysis + cleanup + reporting + logging.
**Why it's wrong:** Can't reuse the analysis without the cleanup. Can't run cleanup without the analysis. Hard to test, hard to maintain.
**Do this instead:** Split into pipeline stages — one script per concern. Chain them via the orchestrator.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **ImageMagick** | CLI subprocess (`magick`/`convert`) | Detect v6 vs v7 at startup; store command in variable |
| **CUPS** | CLI subprocess (`lp -d <printer>`) | Printer discovery via `lpstat -p`; default to system default printer |
| **Package managers** | CLI subprocess (`pacman`/`apt-get`/`dnf`) | Detect via `command -v`; branch install logic |
| **Snapper/Btrfs** | CLI subprocess (`snapper -c root cleanup`) | Only on CachyOS/Btrfs systems; guard with `command -v snapper` |
| **Docker** | CLI subprocess (`docker system prune -a`) | Only if docker is installed; guard with `command -v docker` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `photomaster.sh` ↔ `photoprint*.sh` | Subprocess + `PHOTO_SRC_DIR` env var | Child script auto-detects env var, skips interactive prompt |
| Pipeline stage N ↔ stage N+1 | Filesystem (output folder → input folder) | Orchestrator resolves output path, passes to next stage |
| `lib/common.sh` ↔ any script | `source "$SCRIPT_DIR/../lib/common.sh"` | Only after extraction; not yet implemented |
| `system/` ↔ `media/` | None (independent domains) | No cross-domain dependencies |

## Patterns to Follow

### Pattern: SCRIPT_DIR Resolution

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```

Always resolve the script's own directory. This makes scripts callable from any working directory.

### Pattern: Environment Variable Override

```bash
if [ -n "${PHOTO_SRC_DIR:-}" ]; then
    SRC_DIR="$PHOTO_SRC_DIR"
    echo "Quellordner (aus Workflow): $SRC_DIR"
else
    read -rp "Ordner mit Fotos (Enter = aktueller Ordner): " SRC_DIR
    SRC_DIR="${SRC_DIR:-.}"
fi
```

Allow interactive input OR environment variable. This enables both standalone use and orchestrator chaining.

### Pattern: Capability Detection

```bash
if command -v magick &>/dev/null; then
    MAGICK_CMD="magick"
    MONTAGE_CMD="magick montage"
else
    MAGICK_CMD="convert"
    MONTAGE_CMD="montage"
fi
```

Detect tools at runtime. Don't assume a specific version or distribution.

### Pattern: Safe Temp Directory

```bash
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT
```

Always clean up temp files, even on error. The existing `photoprint.sh` does NOT do this — it should.

### Pattern: Colored Logging Helpers

```bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
```

Machine-parseable prefixes, consistent colors, errors to stderr.

## Sources

- **Codebase analysis:** Direct examination of all 7 shell scripts in the collection (2026-10-19)
- **Convention analysis:** `.planning/codebase/CONVENTIONS.md` — naming, style, error handling patterns
- **Structure analysis:** `.planning/codebase/STRUCTURE.md` — directory layout and file purposes
- **Pattern source:** `.planning/codebase/ARCHITECTURE.md` — existing architecture observations

---
*Architecture research for: handyman utility script collection (shell/bash)*
*Researched: 2026-10-19*
