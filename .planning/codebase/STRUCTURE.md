---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
# Codebase Structure

**Analysis Date:** 2026-10-19

## Directory Layout

```
Script-collection/
├── esphome/                          # ESP32 device configurations
│   └── az-touch01-03esp32mcu/        # AZ-Touch MOD (01-03) device folder
│       ├── demo.yaml                 # Full LVGL dashboard (369 lines)
│       └── test.yaml                 # Basic hardware test (91 lines)
├── llm/                              # LLM server setup
│   └── setup-llm-coding.sh           # llama.cpp + Gemma 4 setup (182 lines)
├── media/                            # Media processing scripts
│   ├── clean/                        # Media cleanup utilities
│   │   └── clean_videos.sh           # Video duplicate cleaner (220 lines)
│   └── photoprint/                   # Photo printing pipeline
│       ├── photomaster.sh            # Interactive menu orchestrator (171 lines)
│       ├── photoprintcorrection.sh   # Color correction for Epson ET-2811 (79 lines)
│       ├── photoprint.sh             # N-up printing via ImageMagick + CUPS (263 lines)
│       └── photoresize.sh            # Photo resizing to print formats (165 lines)
├── system/                           # System maintenance
│   └── cleanupCachyOS.sh             # CachyOS cleanup helper (177 lines)
├── .planning/                        # GSD planning artifacts
│   └── codebase/                     # Codebase analysis documents
└── README.md                         # Project readme (minimal)
```

## Directory Purposes

**`esphome/az-touch01-03esp32mcu/`:**
- Purpose: ESP32 firmware configurations for the AZ-Touch MOD (01-03) display
- Contains: ESPHome YAML configurations for ILI9341 display + XPT2046 touch
- Key files: `esphome/az-touch01-03esp32mcu/demo.yaml`, `esphome/az-touch01-03esp32mcu/test.yaml`

**`llm/`:**
- Purpose: Local LLM server setup and configuration
- Contains: Setup scripts for llama.cpp with Vulkan backend
- Key files: `llm/setup-llm-coding.sh`

**`media/clean/`:**
- Purpose: Media file cleanup and deduplication
- Contains: Shell scripts for scanning and removing duplicate video files
- Key files: `media/clean/clean_videos.sh`

**`media/photoprint/`:**
- Purpose: Photo printing pipeline (correction → resize → print)
- Contains: Interactive shell scripts for Epson ET-2811 photo printing
- Key files: `media/photoprint/photomaster.sh`, `media/photoprint/photoprintcorrection.sh`, `media/photoprint/photoresize.sh`, `media/photoprint/photoprint.sh`

**`system/`:**
- Purpose: System maintenance and cleanup
- Contains: Shell scripts for CachyOS system optimization
- Key files: `system/cleanupCachyOS.sh`

## Key File Locations

**Entry Points:**
- `media/photoprint/photomaster.sh`: Main photo-print menu (orchestrator)
- `media/clean/clean_videos.sh`: Video deduplication tool
- `system/cleanupCachyOS.sh`: System cleanup (requires sudo)
- `llm/setup-llm-coding.sh`: LLM server one-time setup
- `esphome/az-touch01-03esp32mcu/demo.yaml`: ESP32 production firmware
- `esphome/az-touch01-03esp32mcu/test.yaml`: ESP32 test firmware

**Configuration:**
- `esphome/az-touch01-03esp32mcu/demo.yaml`: All device config via `substitutions:` block (lines 9–24)
- `esphome/az-touch01-03esp32mcu/test.yaml`: Hardware test config with pin assignments

**Core Logic:**
- `media/photoprint/photoprint.sh`: N-up montage calculation and CUPS printing
- `media/photoprint/photoresize.sh`: Format selection and ImageMagick resize pipeline
- `media/photoprint/photoprintcorrection.sh`: ImageMagick color correction parameters
- `media/clean/clean_videos.sh`: Two-stage duplicate detection (filename + MD5)
- `system/cleanupCachyOS.sh`: Interactive system maintenance with spinner UI
- `llm/setup-llm-coding.sh`: llama.cpp compilation and model download

**Testing:**
- `esphome/az-touch01-03esp32mcu/test.yaml`: Hardware validation (display, backlight)
- No automated tests exist for any script

## Naming Conventions

**Files:**
- Shell scripts: `lowercase_with_underscores.sh` (e.g., `clean_videos.sh`, `setup-llm-coding.sh`)
- ESPHome configs: `lowercase-with-dashes.yaml` (e.g., `demo.yaml`, `test.yaml`)
- Mixed conventions: some use underscores (`photomaster.sh`), some use hyphens (`setup-llm-coding.sh`)

**Directories:**
- All lowercase: `esphome/`, `llm/`, `media/`, `system/`
- Device-specific subdirs use hyphens: `az-touch01-03esp32mcu/`

**Functions (Shell):**
- `snake_case`: `install_dependencies`, `select_format`, `menu_correction`
- German comments and echo messages throughout

**Functions (ESPHome YAML):**
- `snake_case` for component IDs: `my_display`, `my_touch`, `backlight_pwm`
- `snake_case` for global IDs: `cold_boot_handled`, `touch_calibrated_once`

## Where to Add New Code

**New Photo Processing Script:**
- Primary code: `media/photoprint/<script-name>.sh`
- Register in menu: Add case in `media/photoprint/photomaster.sh` `main_menu()` function
- Follow pattern: `install_dependencies()` → `select_*()` → main loop

**New Media Cleanup Script:**
- Primary code: `media/clean/<script-name>.sh`
- Follow pattern: Argument validation → scan → process → summary report

**New System Utility:**
- Primary code: `system/<script-name>.sh`
- Follow pattern: sudo check → color definitions → confirm() → run_with_spinner()

**New ESP32 Device:**
- Create directory: `esphome/<device-name>/`
- Copy template from: `esphome/az-touch01-03esp32mcu/demo.yaml`
- Customize: `substitutions:` block for device-specific entities and names

**New LLM Configuration:**
- Primary code: `llm/<setup-script>.sh`
- Follow pattern: Config variables → dependency install → compile → download → start script → systemd service

## Special Directories

**`.planning/`:**
- Purpose: GSD workflow planning artifacts (ROADMAP, PLAN, codebase analysis)
- Generated: Partially (by GSD commands)
- Committed: Yes

**`media/photoprint/orginal/`:**
- Purpose: Original binary image assets (reference photos)
- Generated: No
- Committed: Yes (binary files)
- Note: Excluded from codebase analysis

---

*Structure analysis: 2026-10-19*
