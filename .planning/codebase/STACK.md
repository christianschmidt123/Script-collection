---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
# Technology Stack

**Analysis Date:** 2026-10-19

## Overview

This repository is a **collection of standalone shell scripts** — not an application. There is no package manager manifest, no build system, no lockfile, and no test suite. Each script is self-contained and run directly on the host. The only declarative (non-script) code is two ESPHome YAML firmware configurations for an ESP32 touch display.

## Languages

**Primary:**
- **Bash** (POSIX-ish + Bash 4 features) — All operational tooling. Shebangs are either `#!/bin/bash` or `#!/usr/bin/env bash`. Uses `bash` explicitly when re-invoking child scripts.
  - `media/photoprint/photomaster.sh`, `media/photoprint/photoprint.sh`, `media/photoprint/photoprintcorrection.sh`, `media/photoprint/photoresize.sh`, `media/clean/clean_videos.sh` use `#!/bin/bash`
  - `system/cleanupCachyOS.sh`, `llm/setup-llm-coding.sh` use `#!/usr/bin/env bash`

**Secondary:**
- **YAML** (ESPHome DSL) — ESP32 device firmware definitions only.
  - `esphome/az-touch01-03esp32mcu/demo.yaml`
  - `esphome/az-touch01-03esp32mcu/test.yaml`
  - Note: the `substitutions:`/`!lambda` blocks inside these files contain **C++** snippets (LVGL + ESPHome lambdas), e.g. `std::string`, `snprintf`, `id(...).state`. Treat these as embedded C++ within YAML.

**Markup:**
- **Markdown** — `README.md` (currently a single line: `# Script-collection`).

**No TypeScript, JavaScript, Python, Go, Rust, or compiled languages present in the repo.** The only compilation happens via `cmake` in `llm/setup-llm-coding.sh`, which clones and builds the external `llama.cpp` project at runtime.

## Runtime

**Environment:**
- Linux (primarily **CachyOS** / Arch-based, per `system/cleanupCachyOS.sh` and `llm/setup-llm-coding.sh`; also supports Debian/Ubuntu (`apt-get`), Fedora (`dnf`), and macOS (`brew`)).
- Embedded: **ESP32** (ESP32 Dev Kit C V4, `esp32dev` board) running ESPHome firmware.

**Interpreters / Shells:**
- Bash (version 4+ features used: `shopt -s nocaseglob`, arrays `declare -a`, associative-free arrays, `read -rp`, `[[ ]]` conditionals, process substitution `< <(...)`).
- `awk` (POSIX + GNU), `sed`, `sort`, `find`, `stat`, `head`, `wc`, `tr`, `grep`, `getent`, `cut`, `df`, `du`, `printf`.

**Package Manager:**
- **No package manager for the repo itself.** Dependencies are external system binaries installed on demand by each script.
- System package managers invoked at runtime: `pacman` (Arch/CachyOS), `apt-get` (Debian), `dnf` (Fedora), `brew` (macOS).
- Lockfile: **Not applicable** (no manifest).

## Frameworks & Core Tools

**Core:**
- **ImageMagick** — Image processing for photo correction, resizing, and N-up montage printing.
  - Binaries: `magick` (v7), `convert` (v6), `montage` (v6). Scripts auto-detect: prefer `magick`, fall back to `convert`.
  - Used in: `media/photoprint/photoprintcorrection.sh`, `media/photoprint/photoresize.sh`, `media/photoprint/photoprint.sh`
- **CUPS** — Printing subsystem.
  - Binaries: `lp` (submit jobs), `lpstat` (list printers).
  - Used in: `media/photoprint/photoprint.sh`
- **bc** — Arbitrary-precision calculator for cm→pixel and layout math.
  - Used in: `media/photoprint/photoresize.sh`, `media/photoprint/photoprint.sh`
- **ESPHome** — ESP32 firmware generator/compiler. ESPHome consumes the YAML and produces firmware; `esphome:` / `esp32:` / `lvgl:` / `api:` / `ota:` / `wifi:` keys are ESPHome DSL.
  - Used in: `esphome/az-touch01-03esp32mcu/*.yaml`
- **LVGL** — Graphics library used by ESPHome for the display UI (widgets: `obj`, `label`, `switch`, `button`, `style_definitions`, `pages`, `top_layer`).
  - Used in: `esphome/az-touch01-03esp32mcu/demo.yaml`
- **llama.cpp** — Local LLM inference server (cloned and compiled at runtime).
  - Used in: `llm/setup-llm-coding.sh` (builds `build-vulkan/bin/llama-server`)

**Testing:**
- **None.** No test framework, no test files, no CI. See TESTING.md (if generated) / CONCERNS.md.

**Build/Dev:**
- **Git** — Version control. Remote: `https://github.com/christianschmidt123/Script-collection.git`.
- **cmake** + **gcc/base-devel** — Build llama.cpp (invoked inside `llm/setup-llm-coding.sh`).
- **No linter, formatter, or CI pipeline configured** (no `.eslintrc`, `.prettierrc`, `biome.json`, `.github/workflows/`).

## Key Dependencies

**Critical (external binaries, installed on demand):**
- `imagemagick` (`magick`/`convert`/`montage`) — Photo processing; missing in a fresh env breaks all photoprint scripts.
- `cups` (`lp`, `lpstat`) — Printing; only needed for `photoprint.sh`.
- `bc` — Math; needed by `photoresize.sh` and `photoprint.sh`.
- `md5sum`, `awk`, `find`, `sort`, `stat`, `head` — Video duplicate detection in `media/clean/clean_videos.sh`.
- `pacman` — Arch/CachyOS package operations in `system/cleanupCachyOS.sh` and `llm/setup-llm-coding.sh`.

**Infrastructure / optional (runtime-detected):**
- `docker` — Optional; only if present does `system/cleanupCachyOS.sh` prune containers/images.
- `snapper`, `btrfs` — Optional; Btrfs snapshot cleanup in `system/cleanupCachyOS.sh`.
- `paccache` — Optional; Pacman cache cleanup.
- `journalctl` — systemd journal management.
- `vulkaninfo` — Vulkan driver check in `llm/setup-llm-coding.sh`.
- `hf` (Hugging Face Hub CLI, `python-huggingface-hub`) — Model download in `llm/setup-llm-coding.sh`.
- `vulkan-headers`, `vulkan-icd-loader`, `vulkan-tools`, `vulkan-radeon`, `spirv-headers`, `spirv-tools` — GPU build/runtime deps for llama.cpp Vulkan backend.

**ESPHome platform components (resolved by ESPHome at build time):**
- `ili9xxx` (ILI9341 display driver) — marked deprecated upstream, intentionally retained; see `esphome/az-touch01-03esp32mcu/test.yaml`.
- `xpt2046` touchscreen driver.
- `ledc` PWM output, `gpio` output, `monochromatic` light.
- `homeassistant` sensor/text_sensor platforms (pull entities from HA).
- `sntp` time platform.
- `restart` button platform.

## Configuration

**Environment:**
- No `.env` files or central config. Configuration is via:
  - Interactive prompts (`read -rp`) at runtime.
  - Environment variables (only `PHOTO_SRC_DIR` to chain workflows in `media/photoprint/`).
  - ESPHome `substitutions:` block in `esphome/az-touch01-03esp32mcu/demo.yaml` (device name, entity IDs, colors).
  - ESPHome `!secret` references (see INTEGRATIONS.md).
- `llm/setup-llm-coding.sh` hardcodes config in shell variables at the top (lines 10–20): `LLAMA_DIR`, `MODEL_DIR`, `MODEL_FILE`, `MTP_FILE`, `MODEL_REPO`, `MTP_REPO`, `PORT`, `CTX_SIZE`, `NGL`, `THREADS`, `SPEC_DRAFT_N_MAX`.

**Key configs required:**
- ESPHome secrets: `wifi_ssid`, `wifi_password`, `api_encryption_key` (referenced via `!secret`; values live in an untracked `secrets.yaml` — not present in repo).
- llama.cpp: model files `gemma-4-12b-it-Q4_K_M.gguf` (~7.4 GB) and `mtp-gemma-4-12b-it-Q8_0.gguf` (~5 GB) downloaded to `~/models`.

**Build:**
- No repo-level build config. llama.cpp build config is inline in `llm/setup-llm-coding.sh` (cmake flags `-DGGML_VULKAN=ON`, `-DGGML_HIP=OFF`, `Release`).

## Platform Requirements

**Development:**
- Bash 4+ on Linux.
- `imagemagick`, `cups`, `bc` for the photoprint suite.
- ESPHome CLI (`esphome`) to compile/flash the YAML configs.
- `cmake`, `git`, `vulkan-*` packages and `hf` CLI for the LLM setup.

**Production / Target:**
- **Desktop Linux** (CachyOS/Arch primary) for system cleanup and LLM scripts.
- **ESP32 microcontroller** (AZ-Delivery ESP32 Dev Kit C V4 + AZ-Touch MOD 01-03, 2.4" ILI9341 + XPT2046) for the ESPHome firmware, deployed via ESPHome OTA or USB serial.
- **GPU:** AMD RX 7800 XT (RDNA3) with RADV/Vulkan for llama.cpp inference (16 GB VRAM target).

---

*Stack analysis: 2026-10-19*
