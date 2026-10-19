---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
<!-- refreshed: 2026-10-19 -->

# Architecture

**Analysis Date:** 2026-10-19

## System Overview

```text
┌─────────────────────────────────────────────────────────────┐
│                    User / Terminal                            │
├──────────────────┬──────────────────┬───────────────────────┤
│  Photo-Print     │  System & Media  │  ESP32 / LLM Setup    │
│  Suite           │  Utilities       │                       │
│  `media/         │  `media/clean/`  │  `esphome/`           │
│   photoprint/`   │  `system/`       │  `llm/`               │
└────────┬─────────┴────────┬─────────┴──────────┬────────────┘
         │                  │                     │
         ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────┐
│              External Tools & Services                       │
│  ImageMagick │ CUPS (lp) │ pacman │ Docker │ Snapper       │
│  llama.cpp   │ HuggingFace │ ESPHome │ Home Assistant      │
└─────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Photo Master | Interactive menu orchestrator for all photo scripts | `media/photoprint/photomaster.sh` |
| Photo Correction | Color correction (brightness, saturation, contrast, gamma) for Epson ET-2811 | `media/photoprint/photoprintcorrection.sh` |
| Photo Resize | Scale photos to standard print formats (9x13–30x45 cm) | `media/photoprint/photoresize.sh` |
| Photo Print | N-up montage printing via ImageMagick + CUPS | `media/photoprint/photoprint.sh` |
| Video Cleaner | Duplicate detection and cleanup of video files | `media/clean/clean_videos.sh` |
| System Cleanup | CachyOS system maintenance (caches, snapshots, Docker, Btrfs) | `system/cleanupCachyOS.sh` |
| LLM Setup | Local LLM server setup (llama.cpp + Vulkan + Gemma 4) | `llm/setup-llm-coding.sh` |
| ESP32 Demo | Full LVGL touchscreen dashboard for Home Assistant | `esphome/az-touch01-03esp32mcu/demo.yaml` |
| ESP32 Test | Basic hardware test configuration | `esphome/az-touch01-03esp32mcu/test.yaml` |

## Pattern Overview

**Overall:** Standalone Script Collection with Orchestrator Subsystem

**Key Characteristics:**
- Each script is fully self-contained with its own dependency checking and auto-installation
- No shared libraries or common modules — each script duplicates the `install_dependencies` pattern
- The photo-print subsystem uses an orchestrator (`photomaster.sh`) that chains worker scripts via environment variables
- All scripts are interactive CLI tools using `read -rp` for user input
- German-language UI throughout (prompts, messages, comments)
- ESPHome configurations are declarative YAML, not procedural scripts

## Layers

**Orchestration Layer:**
- Purpose: Menu-driven control flow and workflow chaining
- Location: `media/photoprint/photomaster.sh`
- Contains: Menu functions, user interaction, script invocation
- Depends on: Worker scripts in same directory
- Used by: End user

**Processing Layer (Photo Pipeline):**
- Purpose: Image manipulation (correction, resizing, printing)
- Location: `media/photoprint/photoprintcorrection.sh`, `media/photoprint/photoresize.sh`, `media/photoprint/photoprint.sh`
- Contains: ImageMagick commands, format selection, batch processing
- Depends on: ImageMagick, CUPS, bc
- Used by: `photomaster.sh` (orchestrator) or standalone

**System Utilities Layer:**
- Purpose: System maintenance and file cleanup
- Location: `media/clean/clean_videos.sh`, `system/cleanupCachyOS.sh`
- Contains: File system scanning, duplicate detection, package cache management
- Depends on: Standard Unix tools, pacman, docker, snapper, btrfs
- Used by: End user (standalone)

**Infrastructure Setup Layer:**
- Purpose: Development environment and IoT device provisioning
- Location: `llm/setup-llm-coding.sh`, `esphome/az-touch01-03esp32mcu/`
- Contains: LLM server compilation, model download, systemd service creation, ESP32 firmware configuration
- Depends on: git, cmake, Vulkan, ESPHome, Home Assistant
- Used by: End user (one-time setup)

## Data Flow

### Photo Print Workflow (Primary Pipeline)

1. User selects workflow in `photomaster.sh` (`media/photoprint/photomaster.sh:136`)
2. Correction: `photoprintcorrection.sh` processes images → outputs to `druckbereit/` (`media/photoprint/photoprintcorrection.sh:48`)
3. Resize: `photoresize.sh` receives `PHOTO_SRC_DIR` env var → outputs to `skaliert_*/` (`media/photoprint/photoresize.sh:114`)
4. Print: `photoprint.sh` receives `PHOTO_SRC_DIR` env var → creates N-up montage → sends to CUPS (`media/photoprint/photoprint.sh:131`)

**State Management:**
- Inter-script communication via `PHOTO_SRC_DIR` environment variable
- File-based handoff: each stage writes to a known subdirectory (`druckbereit/`, `skaliert_*/`)
- No in-memory state persists between script invocations

### Video Cleanup Flow

1. Stage 1: Scan filesystem for resolution-pattern files (`_<N>p`), group by base name (`media/clean/clean_videos.sh:22`)
2. Stage 1: Keep highest resolution, delete duplicates and corrupt files (`media/clean/clean_videos.sh:30`)
3. Stage 2: Find files with identical byte sizes (`media/clean/clean_videos.sh:119`)
4. Stage 2: MD5 hash comparison to find content duplicates (`media/clean/clean_videos.sh:153`)
5. Summary report with kept/deleted counts (`media/clean/clean_videos.sh:197`)

### LLM Setup Flow

1. Install system dependencies via pacman (`llm/setup-llm-coding.sh:34`)
2. Clone/update llama.cpp repository (`llm/setup-llm-coding.sh:49`)
3. Compile with Vulkan backend (`llm/setup-llm-coding.sh:60`)
4. Download Gemma 4 12B model + MTP drafter via HuggingFace (`llm/setup-llm-coding.sh:75`)
5. Generate start script (`llm/setup-llm-coding.sh:97`)
6. Create optional systemd user service (`llm/setup-llm-coding.sh:145`)

## Key Abstractions

**Dependency Auto-Installer:**
- Purpose: Self-healing scripts that install missing packages
- Examples: `media/photoprint/photoprint.sh:14`, `media/photoprint/photoprintcorrection.sh:6`, `media/photoprint/photoresize.sh:12`
- Pattern: Check with `command -v`, install via detected package manager (apt-get/dnf/pacman/brew)

**ImageMagick Version Abstraction:**
- Purpose: Support both ImageMagick v6 and v7
- Examples: `media/photoprint/photoprint.sh:122`, `media/photoprint/photoresize.sh:107`
- Pattern: `if command -v magick → v7, else → v6`

**Environment Variable Handoff:**
- Purpose: Pass context between pipeline stages without interactive prompts
- Examples: `media/photoprint/photoresize.sh:114`, `media/photoprint/photoprint.sh:131`
- Pattern: `PHOTO_SRC_DIR` env var overrides interactive folder prompt

**ESPHome Substitutions:**
- Purpose: Centralized configuration for ESP32 device
- Examples: `esphome/az-touch01-03esp32mcu/demo.yaml:9`
- Pattern: `substitutions:` block with device-specific values, referenced via `${var}`

## Entry Points

**Photo Print Suite:**
- Location: `media/photoprint/photomaster.sh`
- Triggers: User runs `bash photomaster.sh` or `./photomaster.sh`
- Responsibilities: Menu display, script orchestration, workflow chaining

**Individual Photo Scripts:**
- Location: `media/photoprint/photoprintcorrection.sh`, `media/photoprint/photoresize.sh`, `media/photoprint/photoprint.sh`
- Triggers: Direct execution or via `photomaster.sh`
- Responsibilities: Specific image processing tasks

**Video Cleaner:**
- Location: `media/clean/clean_videos.sh`
- Triggers: `bash clean_videos.sh /path/to/videos`
- Responsibilities: Duplicate detection and removal

**System Cleanup:**
- Location: `system/cleanupCachyOS.sh`
- Triggers: `sudo bash cleanupCachyOS.sh`
- Responsibilities: Interactive system maintenance

**LLM Setup:**
- Location: `llm/setup-llm-coding.sh`
- Triggers: `bash setup-llm-coding.sh`
- Responsibilities: One-time LLM server provisioning

**ESP32 Firmware:**
- Location: `esphome/az-touch01-03esp32mcu/demo.yaml`, `esphome/az-touch01-03esp32mcu/test.yaml`
- Triggers: ESPHome compile/flash via `esphome run` or `esphome dashboard`
- Responsibilities: ESP32 device firmware configuration

## Architectural Constraints

- **No shared code:** Each script duplicates the dependency-check pattern; no common library exists
- **Interactive only:** All scripts require terminal interaction; no non-interactive/CI mode
- **Single-platform:** Scripts target Linux (specifically CachyOS/Arch for system scripts)
- **No error recovery:** Scripts exit on first error; no retry or rollback mechanism
- **File-based handoff:** Pipeline stages communicate via filesystem, not APIs or message queues
- **ESPHome secrets:** WiFi and API keys use `!secret` directive requiring `secrets.yaml`

## Anti-Patterns

### Duplicated Dependency Installation

**What happens:** Each photo script contains its own copy of `install_dependencies()` with identical logic
**Why it's wrong:** Maintenance burden — a bug fix or new package manager must be applied in multiple places
**Do this instead:** Extract to a shared `lib/install-deps.sh` sourced by each script (future refactor)

### Environment Variable as Implicit Contract

**What happens:** `PHOTO_SRC_DIR` is used to pass state between scripts but is undocumented in the scripts themselves
**Why it's wrong:** Users calling scripts directly may not know about this variable; no validation
**Do this instead:** Document in script header comments or use explicit command-line arguments

### No Input Validation

**What happens:** User inputs (folder paths, numeric values) are used without sanitization
**Why it's wrong:** Paths with spaces or special characters may break commands
**Do this instead:** Quote all variable expansions and validate numeric inputs with regex

## Error Handling

**Strategy:** Fail-fast with user-friendly German error messages

**Patterns:**
- Check command existence before use (`command -v`)
- Validate directory existence before processing (`[ -d "$DIR" ]`)
- Exit with status 1 on critical errors
- Confirmation prompts before destructive actions (printing, deletion)
- `|| true` for non-critical operations in system cleanup

## Cross-Cutting Concerns

**Logging:** `echo` with emoji prefixes (🎨, 📐, 🖨️) for visual distinction; `ESP_LOGI`/`ESP_LOGD` in ESPHome lambdas
**Validation:** Minimal — directory existence checks, file count checks; no input sanitization
**Authentication:** None for scripts; ESPHome uses `!secret` for WiFi/API keys; LLM server binds to localhost only

---

*Architecture analysis: 2026-10-19*
