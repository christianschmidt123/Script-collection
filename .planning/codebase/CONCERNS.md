---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
# Codebase Concerns

**Analysis Date:** 2026-10-19

## Tech Debt

**clean_videos.sh — destructive auto-deletion:**
- Issue: Stage 1 deletes files matching `*_[0-9]*p*` naming pattern that are < 1 MB (`-ge 1048576` threshold), plus lower-resolution duplicates. No confirmation prompt beyond passing CLI args. Files are irreversibly deleted without preview or dry-run.
- Files: `media/clean/clean_videos.sh`
- Impact: Data loss risk on misidentified files; a 1 MB threshold is aggressive for short clips or heavily-compressed formats.
- Fix approach: Add `--dry-run` default, interactive confirmation before any `rm`, and a size-threshold prompt. Make deletion opt-in.

**cleanupCachyOS.sh — irreversible system operations:**
- Issue: `docker system prune -a --volumes -f` removes ALL unused images and named volumes (data loss). `pacman -Rns $ORPHANS --noconfirm` removes packages without per-item review. `pacman -Syu --noconfirm` performs a full unconfirmed system upgrade. `snapper cleanup` deletes snapshots.
- Files: `system/cleanupCachyOS.sh`
- Impact: Single `y` answer can destroy Docker volumes, remove needed packages, or upgrade the whole system.
- Fix approach: Require explicit per-item confirmation; default to dry-run/review mode; add a summary of what will be deleted before executing.

**setup-llm-coding.sh — hardcoded hardware profile:**
- Issue: GPU (RX 7800 XT), CPU (Ryzen 7 5800X), VRAM (16 GB), thread count, and context size are all hardcoded. Script will fail or OOM on different hardware.
- Files: `llm/setup-llm-coding.sh`
- Impact: Not portable; silently incorrect on other GPUs/CPUs.
- Fix approach: Auto-detect CPU threads, query GPU VRAM via `vulkaninfo`, or expose configuration variables at the top with clear documentation.

**setup-llm-coding.sh — unresolved `[reference:N]` placeholders:**
- Issue: Comments and the generated start-script contain `[reference:3]` through `[reference:10]` — these are placeholder citations that were never filled with actual sources.
- Files: `llm/setup-llm-coding.sh` (lines 58–59, 74, 82, 101–110)
- Impact: Misleading documentation; claims about "3x Speedup" and "80–90 tok/s" are unsourced.
- Fix approach: Replace with actual URLs or remove the references.

**demo.yaml — undefined font references:**
- Issue: Widgets reference `montserrat_14` and `montserrat_20` fonts (lines 214, 227, 257, 263, 281, 319, 347), but only `mdi_16` is defined in the `font:` section. No Montserrat font file is declared.
- Files: `esphome/az-touch01-03esp32mcu/demo.yaml`
- Impact: ESPHome build will fail with "font not found" errors, or labels will render blank.
- Fix approach: Add Montserrat TTF font definitions (e.g., `gfonts://Montserrat`) with matching IDs, or replace `text_font: montserrat_*` with a defined font.

**test.yaml — debug logger + leftover test card:**
- Issue: `logger: level: DEBUG` at line 30; `show_test_card: true` at line 76 (comment says "vorübergehend" / temporary). Neither has been reverted.
- Files: `esphome/az-touch01-03esp32mcu/test.yaml`
- Impact: Excessive log output fills flash storage over time; test card is not suitable for production use.
- Fix approach: Change to `logger: INFO` or `WARN`; remove `show_test_card` line.

## Known Bugs

**photoprint.sh — division by zero when photo > paper:**
- Symptoms: If the photo dimensions exceed paper dimensions (e.g., 20x25 photo on A4 paper), `bc` returns 0 for COLS/ROWS. The script then divides by `TILES_PER_PAGE` (which is 0), causing an arithmetic error and crash.
- Files: `media/photoprint/photoprint.sh` (lines 155–156, 197–198)
- Trigger: Select a photo format larger than the selected paper format.
- Workaround: None — script crashes.

**photoprintcorrection.sh — silent failures:**
- Symptoms: If ImageMagick fails on a file (corrupt image, permission denied), the script continues silently. `count` increments regardless of success, so the summary always claims success.
- Files: `media/photoprint/photoprintcorrection.sh` (lines 60–74)
- Trigger: Any unreadable or corrupt source image.
- Workaround: None — misleading output.

**photoprintcorrection.sh — relative output directory:**
- Symptoms: `OUTPUT_DIR="druckbereit"` is relative to CWD. If the script is invoked from a directory other than the source photos folder, output lands in the wrong place. The comment claims originals are protected, but only because output goes elsewhere — not to the correct elsewhere.
- Files: `media/photoprint/photoprintcorrection.sh` (line 48)
- Trigger: Running `bash /path/to/photoprintcorrection.sh` from a different CWD.
- Workaround: `cd` to source folder first (the menu script does this correctly).

**photomaster.sh — misleading workflow output:**
- Symptoms: If `photoresize.sh` produces no `skaliert_*` directory, `RESIZE_OUT` falls back to `CORRECTION_OUT` and the script still reports "Skalierung abgeschlossen" with the correction output path, silently skipping the resize step.
- Files: `media/photoprint/photomaster.sh` (lines 118–121)
- Trigger: Empty source folder or resize failure.
- Workaround: None — user believes all 3 steps ran.

## Security Considerations

**test.yaml — unencrypted ESPHome API:**
- Risk: The `api:` block has no `encryption: key:` directive. Any device on the local network can control the ESP32 (toggle lights, read sensor data, trigger reboots).
- Files: `esphome/az-touch01-03esp32mcu/test.yaml`
- Current mitigation: None.
- Recommendations: Add `api: encryption: key: !secret api_encryption_key` (as demo.yaml already does) and provide a `secrets.yaml`.

**setup-llm-coding.sh — no model checksum verification:**
- Risk: 12.4 GB of GGUF model files are downloaded from HuggingFace with no SHA256 or checksum verification. Corrupted or tampered downloads would silently produce a broken server.
- Files: `llm/setup-llm-coding.sh` (lines 75–91)
- Current mitigation: None.
- Recommendations: Add `huggingface-cli download` with `--revision` pinning, or verify checksums post-download.

**demo.yaml — hardcoded personal entity IDs:**
- Risk: Real Home Assistant entity names (`light.kajplats_e14_ws_globe_806lm`, `sensor.alpstuga_air_quality_monitor_temperatur_2`) expose room names and device topology if the repo is shared.
- Files: `esphome/az-touch01-03esp32mcu/demo.yaml` (lines 14, 16)
- Current mitigation: None.
- Recommendations: Move to `!secret` or substitutions with placeholder values.

**No .gitignore:**
- Risk: No `.gitignore` file exists. Sensitive files (`secrets.yaml`, `.env`, model caches) could be accidentally committed.
- Files: repository root
- Current mitigation: None.
- Recommendations: Add `.gitignore` with `secrets.yaml`, `*.env`, `orginal/` patterns.

## Performance Bottlenecks

**demo.yaml — DEBUG logger on production device:**
- Problem: `logger: level: DEBUG` generates high-volume log output on an ESP32 with limited flash.
- Files: `esphome/az-touch01-03esp32mcu/demo.yaml` (line 68)
- Cause: Verbose logging was likely left over from development.
- Improvement path: Set to `INFO` or `WARN` for production; reserve `DEBUG` for troubleshooting.

**setup-llm-coding.sh — full VRAM offload without memory guard:**
- Problem: `-ngl 999` puts all layers on GPU with no fallback for models larger than VRAM. On a 16 GB card with 32k context, OOM is likely.
- Files: `llm/setup-llm-coding.sh` (line 119–135)
- Cause: No runtime memory checking or graceful degradation.
- Improvement path: Add `nvidia-smi` / `vulkaninfo` memory check, or parameterize `-ngl` based on available VRAM.

## Fragile Areas

**clean_videos.sh — complex awk pipeline:**
- Files: `media/clean/clean_videos.sh` (lines 79–108, 125–139)
- Why fragile: Multi-stage `awk` + `sort` pipeline with tab-delimited records; subtle changes to filename patterns or sort behavior can break grouping logic silently. No error handling if `find` returns empty or awk fails.
- Safe modification: Test with sample filename sets; consider adding `set -euo pipefail` and validating pipeline output.
- Test coverage: None.

**cleanupCachyOS.sh — unquoted variable expansion:**
- Files: `system/cleanupCachyOS.sh` (lines 109–113, 160–165)
- Why fragile: `run_with_spinner` passes a single string to `bash -c` with embedded `$REAL_HOME` expansion. If username contains spaces or special characters, commands break or execute unexpectedly.
- Safe modification: Use array-based argument passing or proper quoting; test with usernames containing special characters.
- Test coverage: None.

**photoprint.sh — ImageMagick v6/v7 compatibility:**
- Files: `media/photoprint/photoprint.sh` (lines 122–128, 219–225)
- Why fragile: Relies on `magick` vs `convert`/`montage` detection but doesn't verify the detected binary actually supports the flags used (e.g., `-modulate`, `-brightness-contrast` syntax differs between v6 and v7).
- Safe modification: Test on both IM v6 and v7; add version detection with warnings.
- Test coverage: None.

## Scaling Limits

**setup-llm-coding.sh — single-model, single-server:**
- Current capacity: One Gemma 4 12B model on one GPU, one server instance.
- Limit: No support for model switching, multi-GPU, or request queuing under load.
- Scaling path: Parameterize model/config; consider `llama-server`'s multi-slot support.

## Dependencies at Risk

**ESPHome ili9xxx display driver:**
- Risk: `ili9xxx` platform is deprecated upstream (successor: `mipi_spi`). The comment documents that mipi_spi has regressions, but eventually ili9xxx will be removed.
- Impact: Display stops working after a future ESPHome release.
- Migration plan: Track ESPHome upstream for stable mipi_spi ILI9341 support; plan migration.

**llama.cpp Vulkan backend:**
- Risk: Vulkan backend on AMD (RADV) is less mature than CUDA. Performance claims may not hold across driver updates.
- Impact: Speed degradation or build failures after system/driver updates.
- Migration plan: Pin `vulkan-radeon` version; consider HIP backend as fallback.

**Python `huggingface-hub` via pacman:**
- Risk: `python-huggingface-hub` from pacman may lag behind PyPI releases; `hf` CLI may have breaking changes.
- Impact: Download failures or API incompatibility.
- Migration plan: Pin version or use a virtualenv with `pip install huggingface-hub==X.Y.Z`.

## Missing Critical Features

**No input validation on user-supplied paths:**
- Problem: `clean_videos.sh` accepts arbitrary paths via `"$@"` with no validation. A typo could target system directories. `photoprint.sh` / `photoresize.sh` accept any directory without checking for symlinks or permission issues.
- Blocks: Safe use by non-technical users.

**No dry-run or preview mode:**
- Problem: None of the destructive scripts (`clean_videos.sh`, `cleanupCachyOS.sh`) offer a dry-run mode. Users cannot preview what will be deleted before committing.
- Blocks: Confident use of cleanup scripts.

**No error handling / set -e in most scripts:**
- Problem: `clean_videos.sh`, `cleanupCachyOS.sh`, `photoprint.sh`, `photoresize.sh`, `photoprintcorrection.sh` lack `set -euo pipefail`. Failures are silent; scripts continue after errors.
- Blocks: Reliable automation; scripts may report success despite partial failure.

**No `secrets.yaml` template:**
- Problem: ESPHome configs reference `!secret wifi_ssid`, `!secret wifi_password`, `!secret api_encryption_key`, but no `secrets.yaml` or `secrets.yaml.example` is provided.
- Blocks: New users cannot compile the YAML without creating their own secrets file.

## Test Coverage Gaps

**Entire codebase — zero tests:**
- What's not tested: All shell scripts and both ESPHome YAML configs have no automated tests, no shellcheck, no CI pipeline.
- Files: all `.sh` files and both `.yaml` files
- Risk: Regressions go undetected; bugs like the undefined font references would be caught by a CI build.
- Priority: High — add shellcheck linting, `bash -n` syntax checks, and ESPHome CI build (`esphome config`) as a minimum.

---

*Concerns audit: 2026-10-19*
