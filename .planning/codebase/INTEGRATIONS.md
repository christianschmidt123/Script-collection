---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
# External Integrations

**Analysis Date:** 2026-10-19

## Overview

This repo is a collection of standalone shell scripts plus ESPHome firmware configs. There is **no application backend, no database, and no web API**. Integrations are therefore limited to: external CLI binaries invoked by scripts, the CUPS printing subsystem, the ESPHome/Home Assistant ecosystem, the llama.cpp OpenAI-compatible server, Hugging Face model hosting, and GitHub for version control.

## APIs & External Services

**Printing (CUPS):**
- **CUPS printing subsystem** — Submit and manage print jobs from the photo suite.
  - Client: `lp` (submit job), `lpstat` (enumerate printers)
  - Used in: `media/photoprint/photoprint.sh`
  - Auth: none (local CUPS daemon)

**Local LLM (OpenAI-compatible):**
- **llama.cpp `llama-server`** — Local inference server exposing an OpenAI-compatible REST API.
  - Endpoint: `http://127.0.0.1:8080/v1` (bound to loopback only)
  - Used in: `llm/setup-llm-coding.sh` (generated `~/start-llm-server.sh`)
  - Auth: none (local-only, loopback)
  - Client example: `curl http://127.0.0.1:8080/v1/models`

**OmniRoute (LLM gateway):**
- **OmniRoute** — Routes LLM requests to providers; configured to point at the local llama.cpp server as an "OpenAI-compatible" provider.
  - Config: base URL `http://127.0.0.1:8080/v1`, empty API key.
  - Env var: `OMNIROUTE_ALLOW_PRIVATE_PROVIDER_URLS=true` in `~/.omniroute/.env`.
  - Referenced in: `llm/setup-llm-coding.sh` (documentation comments only)

**Hugging Face Hub:**
- **Hugging Face** — Model weights hosting.
  - Client: `hf download` CLI (from `python-huggingface-hub`).
  - Repos: `unsloth/gemma-4-12b-it-GGUF` (both main model and MTP drafter).
  - Used in: `llm/setup-llm-coding.sh`

**GitHub:**
- **GitHub** — Source hosting / git remote.
  - Remote: `https://github.com/christianschmidt123/Script-collection.git`
  - Referenced in: `git remote -v`

**Google Fonts (ESPHome):**
- **Google Fonts** — Font file fetched by ESPHome at build time.
  - Reference: `gfonts://Roboto` in `esphome/az-touch01-03esp32mcu/test.yaml`.

## Data Storage

**Databases:**
- **None.** No SQL/NoSQL database, no ORM, no connection strings.

**File Storage:**
- **Local filesystem only.** Scripts read/write images and videos in user-specified directories.
  - Photo suite outputs: `druckbereit/`, `skaliert_<W>x<H>cm/` subdirectories (`media/photoprint/`).
  - Temporary montage images via `mktemp -d` in `media/photoprint/photoprint.sh`.
  - Model files in `~/models/` (`llm/setup-llm-coding.sh`).

**Caching:**
- **None** at the application level. System-level caches are *targets* of cleanup, not dependencies:
  - Pacman cache (`/var/cache/pacman/pkg`), Paru/Yay AUR caches, browser caches, thumbnails — see `system/cleanupCachyOS.sh`.

## Authentication & Identity

**Auth Provider:**
- **None for scripts.** All scripts rely on OS-level permissions and `sudo`.
- **ESPHome native API encryption** — `api: encryption: key: !secret api_encryption_key` in `esphome/az-touch01-03esp32mcu/demo.yaml`. This is the ESPHome↔Home Assistant API key, not user auth.
- **Wi-Fi credentials** — `!secret wifi_ssid` / `!secret wifi_password` in both ESPHome YAMLs.
- **llama.cpp** — No API key; loopback-only binding.

## Monitoring & Observability

**Error Tracking:**
- **None.** No Sentry/rollbar/etc.

**Logs:**
- **Console output only.** Scripts use `echo`, `printf`, and ANSI color codes.
- ESPHome `logger:` at `DEBUG` level (`esphome/az-touch01-03esp32mcu/*.yaml`).
- Systemd journal: `journalctl --user -u llama-server -f` and `journalctl --disk-usage` (`llm/setup-llm-coding.sh`, `system/cleanupCachyOS.sh`).
- `clean_videos.sh` collects warnings/errors into an in-memory string and prints a summary.

## CI/CD & Deployment

**Hosting:**
- **GitHub** (`github.com/christianschmidt123/Script-collection`).

**CI Pipeline:**
- **None.** No `.github/workflows/`, no CI config.

**Deployment:**
- Scripts are run manually on the target machine.
- ESPHome firmware deployed via ESPHome **OTA** (`ota: - platform: esphome`) or USB serial.
- llama.cpp server deployed as a **systemd user service** (`~/.config/systemd/user/llama-server.service`), enabled with `systemctl --user enable --now llama-server`.

## Environment Configuration

**Required env vars:**
- `PHOTO_SRC_DIR` — Optional; chains photoprint scripts without interactive prompts (`media/photoprint/photoprint.sh`, `media/photoprint/photoresize.sh`).
- `OMNIROUTE_ALLOW_PRIVATE_PROVIDER_URLS=true` — In `~/.omniroute/.env` for OmniRoute private-URL support (`llm/setup-llm-coding.sh`).
- `GGML_VK_VISIBLE_DEVICES=0` — Set by the generated systemd unit to pin Vulkan device.
- `SUDO_USER` / `USER` — Used to resolve the real user's home under sudo (`system/cleanupCachyOS.sh`).

**Secrets location:**
- **ESPHome secrets** — referenced via `!secret` (`wifi_ssid`, `wifi_password`, `api_encryption_key`). Values live in an ESPHome `secrets.yaml` file that is **not committed** to this repo (only the two YAML configs are present in `esphome/az-touch01-03esp32mcu/`).
- **No `.env`, credential, or secret files are committed** to the repository.
- **No secrets are read by any script**; all auth is delegated to OS/sudo, CUPS, or ESPHome.

## Webhooks & Callbacks

**Incoming:**
- **None.** No HTTP servers or webhook receivers in this repo.

**Outgoing:**
- **ESPHome → Home Assistant** — ESPHome device exposes entities via the native ESPHome API; HA polls/controls them. `homeassistant.service:` calls in `demo.yaml` push commands *to* HA (e.g. `light.turn_on`/`light.turn_off`).
- **Home Assistant → ESPHome** — `sensor.homeassistant` / `text_sensor.homeassistant` platforms in `demo.yaml` pull HA entity states into the device.
- **llama.cpp → OmniRoute** — OmniRoute is configured to call the local OpenAI-compatible endpoint (outbound from OmniRoute's perspective).

## External Binary Dependencies (CLI)

These are not network services but are required external tools invoked by scripts:

| Tool | Purpose | Used in |
|------|---------|---------|
| `magick` / `convert` / `montage` | Image processing | `media/photoprint/*.sh` |
| `lp` / `lpstat` | CUPS printing | `media/photoprint/photoprint.sh` |
| `bc` | Math | `media/photoprint/*.sh` |
| `md5sum`, `awk`, `sort`, `find`, `stat`, `head` | Video dedup | `media/clean/clean_videos.sh` |
| `pacman`, `paccache`, `snapper`, `btrfs`, `journalctl`, `docker` | System maintenance | `system/cleanupCachyOS.sh` |
| `cmake`, `git`, `vulkaninfo`, `hf` | LLM setup | `llm/setup-llm-coding.sh` |

---

*Integration audit: 2026-10-19*
