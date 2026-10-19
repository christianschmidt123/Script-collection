---
last_mapped_commit: 28bf4f8d8ff54208d6061937d451f852bdb6e4c5
last_mapped_at: 2026-10-19
---
# Testing Patterns

**Analysis Date:** 2026-10-19

> **Scope:** This repository contains **no automated tests, no test framework, no test runner, and no CI pipeline**. The findings below document the current (absent) state and prescribe the patterns to adopt. Files inspected: `media/photoprint/photomaster.sh`, `photoprint.sh`, `photoprintcorrection.sh`, `photoresize.sh`, `media/clean/clean_videos.sh`, `system/cleanupCachyOS.sh`, `llm/setup-llm-coding.sh`, `esphome/az-touch01-03esp32mcu/demo.yaml`, `esphome/az-touch01-03esp32mcu/test.yaml`, `README.md`.

## Test Framework

**Runner:**
- **Not detected.** No `bats`, `shunit2`, `pytest`, `jest`, `vitest`, or any runner installed or referenced.

**Assertion Library:**
- **Not detected.** No assertion library in use.

**Run Commands:**

```bash

# None exist. No package.json / Makefile / test script is present.

```

No `Makefile`, `package.json`, `requirements.txt`, or CI workflow (`.github/` does not exist) was found.

**Recommendation:** Adopt [`bats-core`](https://github.com/bats-core/bats-core) for shell scripts (available in Arch/CachyOS as the `bats` package):

```bash
bats test/photoprint.bats        # run all tests
bats -f "resize" test/           # filter by name
shellcheck media/photoprint/*.sh # static analysis (complement, not a replacement)
```

## Test File Organization

**Location:**
- **Not detected.** No `test/`, `tests/`, `spec/`, or `__tests__/` directory exists.
- The only filename containing "test" is `esphome/az-touch01-03esp32mcu/test.yaml` — this is an **ESPHome hardware configuration** (a test firmware build), **not** an automated test. Do not treat it as one.

**Naming:**
- No convention exists. **Recommended:** colocate a `test/` directory at the repo root (or per-component) with `<script>.bats` files, e.g. `test/photoprint.bats`, `test/clean_videos.bats`.

**Structure:**

```
Script-collection/
└── test/                 # proposed — does not exist yet
    ├── helpers.bash      # shared setup/assert helpers
    ├── photoprint.bats
    ├── photoresize.bats
    └── clean_videos.bats
```

## Test Structure

**Suite Organization:**
- **Not detected.** No `describe`/`it`/`test` blocks exist anywhere.

**Patterns (recommended, not yet present):**
- Setup/teardown via bats `setup()` / `teardown()` using a temp dir:

```bash
setup() {
    TEST_DIR="$(mktemp -d)"
    export PHOTO_SRC_DIR="$TEST_DIR"
}
teardown() {
    rm -rf "$TEST_DIR"
}
```

- Assertion pattern using bats' `run` + `assert_*`:

```bash
@test "photoresize rejects a missing source folder" {
    run bash media/photoprint/photoresize.sh
    assert_failure
    assert_output --partial "nicht gefunden"
}
```

## Mocking

**Framework:** **Not detected.** No mocking library or stubbing pattern exists.

**Patterns (recommended):**
- Stub external binaries by prepending a `bin/` dir to `PATH` inside `setup()`:

```bash
setup() {
    mkdir -p "$TEST_DIR/bin"
    cat > "$TEST_DIR/bin/magick" <<'STUB'
#!/usr/bin/env bash
echo "magick $*"
STUB
    chmod +x "$TEST_DIR/bin/magick"
    PATH="$TEST_DIR/bin:$PATH"
}
```

- **What to Mock:** `magick`/`convert` (ImageMagick), `lp` (CUPS), `bc`, `md5sum`, `find`/`stat` where filesystem state matters, `docker`, `snapper`, `pacman`, `journalctl`, `hf`, `cmake`.
- **What NOT to Mock:** Pure arithmetic (`bc` expressions can be tested directly), shell builtins, `printf`, and `[[ ]]` conditionals. Prefer real temp files over mocking the filesystem.

## Fixtures and Factories

**Test Data:**
- **Not detected.** No fixtures or factories exist.

**Location (recommended):**
- `test/fixtures/` for sample images (`*.jpg`, `*.png`, `*.tiff`) and sample video names matching the `_<digits>p` pattern used by `media/clean/clean_videos.sh`.
- Generate small synthetic images at test time with ImageMagick rather than committing binaries:

```bash
magick -size 100x100 xc:red "$TEST_DIR/photo_720p_01.mp4.jpg"
```

## Coverage

**Requirements:** **None enforced.** No coverage threshold, no `--cov`/coverage config.

**View Coverage (recommended):**

```bash

# bats does not provide coverage natively; use kcov for shell scripts

kcov --bash --include-path=media/photoprint coverage/ bats test/
```

No coverage tooling is currently installed or configured.

## Test Types

**Unit Tests:**
- **Not detected.** No unit tests. Target candidates: `select_format()`/`select_dpi()` input parsing, cm→pixel conversion math in `photoprint.sh:155-179`, and the `_<digits>p` regex parsing in `clean_videos.sh:86-94`.

**Integration Tests:**
- **Not detected.** No integration tests. Target: the chained workflow in `photomaster.sh:81-131` (`photoprintcorrection.sh` → `photoresize.sh` → `photoprint.sh` via `PHOTO_SRC_DIR`), which currently has no automated verification.

**E2E Tests:**
- **Not detected.** No browser/E2E framework. The interactive TUI scripts (`photomaster.sh`, `cleanupCachyOS.sh`) rely on manual `read` prompts; they would need `expect`/`pexpect`-style tooling to automate and are lower priority.

**Static Analysis (the only de-facto "test" today):**
- Not wired up, but `shellcheck` is the highest-value addition for this repo. It would catch real issues such as unquoted `$ORPHANS` in `system/cleanupCachyOS.sh:121` and missing `trap` cleanup in `media/photoprint/photoprint.sh:204`.

## Common Patterns

**Async Testing:**
- **Not applicable.** All scripts are synchronous and interactive; no async/concurrent test pattern exists or is needed.

**Error Testing (recommended shape):**

```bash
@test "clean_videos exits 1 when no path argument is given" {
    run bash media/clean/clean_videos.sh
    assert_failure 1
    assert_output --partial "Nutzung:"
}

@test "photoresize exits 1 for a non-existent source folder" {
    PHOTO_SRC_DIR="/nonexistent/path/$$" run bash media/photoprint/photoresize.sh
    assert_failure 1
    assert_output --partial "nicht gefunden"
}
```

**Recommended first tests (highest value, lowest effort):**
1. `media/clean/clean_videos.sh` — pure-ish logic, clear `Nutzung:` + exit-1 contract (`:3-6`), regex parsing, and destructive `rm` behavior (test on temp copies only).
2. `media/photoprint/photoresize.sh` — format/DPI selection defaults and cm→px math (`:134-135`).
3. `media/photoprint/photoprint.sh` — orientation selection (portrait vs. landscape) math (`:155-176`) and the no-photos error path (`:191-194`).
4. `llm/setup-llm-coding.sh` — already has `set -euo pipefail`; test the generated `start-llm-server.sh` heredoc contents without executing the install.

---

*Testing analysis: 2026-10-19*
