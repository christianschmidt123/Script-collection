# Domain Pitfalls

**Domain:** Handyman utility shell scripts (bash) — media/photo printing, disk cleanup, system maintenance
**Researched:** 2026-10-19
**Confidence:** HIGH (grounded in the live codebase; external sources corroborate)

> **Scope note:** This file is grounded in the *actual* scripts in this repo (`media/photoprint/*.sh`, `media/clean/clean_videos.sh`, `system/cleanupCachyOS.sh`, `llm/setup-llm-coding.sh`). Every critical pitfall below cites a real file/line where possible. Phase names are **indicative** — the roadmapper should remap them to the final phase list.

---

## Critical Pitfalls

### Pitfall 1: Destructive deletion with no dry-run, no preview, no per-item confirmation

**What goes wrong:**
Files are deleted irreversibly the moment the script runs. `media/clean/clean_videos.sh` deletes anything matching `*_[0-9]*p*` that is under 1 MB or that the awk pipeline decides is a duplicate — with **no confirmation prompt**, no dry-run, and no backup. `system/cleanupCachyOS.sh` runs `docker system prune -a --volumes -f` (destroys ALL unused images **and named volumes**) and `pacman -Rns $ORPHANS --noconfirm` behind a single `y`.

**Why it happens:**
The author is the only user, so "I'll just check before running" feels sufficient. Deletion is written as the default path because it's the shortest code. There is no `--dry-run` flag, so the first run *is* the test run.

**How to avoid:**
- Make **dry-run the default** for any script that deletes, moves, or overwrites. Require `--apply` / `--yes` / `CONFIRM=1` to actually mutate.
- Print a full manifest (path + size + reason) of what *would* be deleted, then require explicit confirmation.
- Prefer moving to a timestamped trash/quarantine dir over `rm` where possible.
- Never chain `-a --volumes -f` / `--noconfirm` without a review step; prune in stages (containers → images → volumes) with separate confirmations.

**Warning signs:**
- Any `rm`, `find -delete`, `xargs rm`, `pacman -R`, `docker prune`, `snapper cleanup` with no preceding preview.
- A script whose only input is a path argument and whose first action is deletion.
- Test coverage: zero tests on the deletion path.

**Phase to address:**
**Foundation & Hardening** (establish the safety contract: dry-run default, confirm gate, trash-first) *before* any cleanup feature ships. Re-verify in every cleanup phase.

**Confidence:** HIGH — confirmed in `media/clean/clean_videos.sh:61,70` and `system/cleanupCachyOS.sh:121,141`.

---

### Pitfall 2: No strict mode → silent failures reported as success

**What goes wrong:**
Scripts lack `set -euo pipefail`, so a failed `magick`, `rm`, or `find` is swallowed and the script continues to print "Fertig!" / "Fotos optimiert". `photoprintcorrection.sh` increments `count` unconditionally and always claims success even when ImageMagick fails on a corrupt image. `photomaster.sh` falls back to the correction output and still reports "Skalierung abgeschlossen" when resize produced nothing.

**Why it happens:**
Strict mode is easy to omit when scripts are written incrementally and tested by hand. Adding it later "breaks" scripts full of `|| true`, so it gets postponed forever.

**How to avoid:**
- Add `set -euo pipefail` to every new script from the start.
- For existing scripts, convert incrementally: replace blanket `|| true` with explicit, justified error handling.
- Check the exit status of every external command whose failure matters (`magick`, `lp`, `rm`, `find`).
- Never increment a success counter without checking the command's return code.

**Warning signs:**
- A summary that always says "N files processed" regardless of input.
- `|| true` / `|| echo` on commands that should be fatal.
- No `set -euo pipefail` anywhere in the script.

**Phase to address:**
**Foundation & Hardening** — make strict mode a repo-wide convention and add a `shellcheck` + `bash -n` gate. Re-verify per feature phase.

**Confidence:** HIGH — confirmed in `photoprintcorrection.sh:60-74`, `photomaster.sh:118-121`; repo-wide absence noted in `.planning/codebase/CONVENTIONS.md`.

---

### Pitfall 3: Unquoted / unvalidated variable expansion in destructive or privileged commands

**What goes wrong:**
`cleanupCachyOS.sh` runs `pacman -Rns $ORPHANS --noconfirm` unquoted (intended word-splitting, but breaks on unusual package output) and interpolates `$REAL_HOME` into a single string passed to `bash -c` inside `run_with_spinner`. If the username or path contains spaces/special characters, commands break or execute unexpectedly. More generally, `rm -rf "${dir}"/*` with an empty `dir` becomes `rm -rf /*`.

**Why it happens:**
Word-splitting is sometimes *wanted* (package lists), so authors learn to leave variables unquoted. The dangerous cases (paths, user-supplied input) look identical.

**How to avoid:**
- Quote every path and user-supplied value: `"$VAR"`, `"${arr[@]}"`.
- For intentional word-splitting, use an array or `read -ra`.
- Guard destructive paths: `rm -rf -- "${dir:?}"/*` and validate the target is inside an allowlisted prefix before deleting.
- Pass commands to `bash -c` as an array or with proper escaping, never by string interpolation of a path.

**Warning signs:**
- `rm -rf $VAR`, `rm -rf ${VAR}/*`, `bash -c "...$HOME..."`.
- Any `rm`/`mv`/`dd`/`pacman -R`/`docker` on a variable that can be empty.

**Phase to address:**
**Foundation & Hardening** (quote-guard + prefix-guard helpers). Enforced by `shellcheck` in CI.

**Confidence:** HIGH — confirmed in `cleanupCachyOS.sh:109-113,121,160-165`; corroborated by community guidance on `rm -rf ${p}/*` empty-variable disasters.

---

### Pitfall 4: ImageMagick v6/v7 "detection" that doesn't verify the binary actually supports the flags used

**What goes wrong:**
Scripts detect `magick` vs `convert`/`montage` by presence only, then use flags that differ between v6 and v7 (`-modulate`, `-brightness-contrast`, montage `-tile`/`-geometry` semantics, HDRI color differences, `-flatten` inheriting the last `-compose`). The result is silently wrong output — or a crash — on the "other" version. `photoprint.sh` also feeds `null:` placeholder tiles into montage, whose handling differs across versions.

**Why it happens:**
The v6→v7 migration is gradual; distros ship either. Presence-detection feels sufficient, but the *flag surface* is what matters.

**How to avoid:**
- Detect and print the **actual version** (`magick -version` / `convert -version`) and warn on unsupported versions.
- Test the exact command lines on both v6 and v7; pin behavior with explicit flags.
- Prefer `magick montage` on v7 and `montage` on v6 (already done) — but verify `-geometry`, `-tile`, `-density`, `-units` behavior per version.
- Add `-clamp` where v6/v7 HDRI results diverge.

**Warning signs:**
- A version check that only tests `command -v`.
- Montage output with unexpected borders, padding, or color shifts on a different machine.
- `null:` placeholder tiles behaving differently across runs.

**Phase to address:**
**Photo Printing Suite** — add a version-detection + compatibility layer and test against both IM majors.

**Confidence:** MEDIUM — confirmed the detection pattern in `photoprint.sh:122-128`; v6/v7 flag differences corroborated by ImageMagick porting docs and montage usage docs.

---

### Pitfall 5: Arithmetic/geometry crashes on edge-case inputs (division by zero, zero tiles)

**What goes wrong:**
`photoprint.sh` computes `COLS`/`ROWS` by dividing paper size by photo size. If the photo format is larger than the paper (e.g. 20×25 photo on A4), `bc` yields `0`, then `TILES_PER_PAGE=0` and `NUM_PAGES=$(( ... / 0 ))` crashes with an arithmetic error. No validation catches this.

**Why it happens:**
The happy path is "many small photos on big paper". Edge cases (photo > paper, zero photos, non-numeric DPI) aren't in the author's mental model.

**How to avoid:**
- Validate inputs before arithmetic: `COLS > 0 && ROWS > 0`, `DPI` numeric, photo ≤ paper.
- Guard every division; fail fast with a clear German error message.
- Add a "largest photo that fits" pre-check and suggest the correct paper size.

**Warning signs:**
- Any `bc`/`$(( ))` division on a computed value.
- Scripts that crash only on specific menu choices.

**Phase to address:**
**Photo Printing Suite** — input-validation pass; add unit tests for the cm→px and orientation math.

**Confidence:** HIGH — confirmed bug in `photoprint.sh:155-156,197-198` (documented in `.planning/codebase/CONCERNS.md`).

---

### Pitfall 6: Relative output paths and CWD assumptions → output lands in the wrong place

**What goes wrong:**
`photoprintcorrection.sh` sets `OUTPUT_DIR="druckbereit"` relative to the current working directory. Run it from anywhere other than the source folder and the output lands in the wrong directory — the comment claims originals are protected, but only because output goes *somewhere else*, not the *right* somewhere. `photoresize.sh` writes to `"${SRC_DIR}/skaliert_*"` (absolute-ish, OK) but `photomaster.sh` assumes the CWD for the correction step.

**Why it happens:**
Scripts are developed by `cd`-ing into the target folder, so relative paths "just work" during development.

**How to avoid:**
- Resolve `SCRIPT_DIR` and derive all paths from it or from an explicit `--output`/`--source` argument.
- Anchor output to the source directory, not CWD.
- Print the absolute output path in the summary so the user can verify.

**Warning signs:**
- `OUTPUT_DIR="something"` without a leading path.
- A script that behaves differently depending on where it's invoked from.
- `cd` into a source folder as the *only* way to get correct output.

**Phase to address:**
**Photo Printing Suite** — normalize path handling across all photo scripts.

**Confidence:** HIGH — confirmed in `photoprintcorrection.sh:48` and `photomaster.sh:47,106`.

---

### Pitfall 7: Temp files created with `mktemp` but never cleaned up on failure/abort

**What goes wrong:**
`photoprint.sh` creates `TMP_DIR=$(mktemp -d)` and only removes it on the success path. If the user aborts at the print confirmation (`n`), the script exits and leaves the temp dir behind — and even tells the user "Temporäre Dateien: $TMP_DIR" so they can clean it manually, which they won't. Interrupts (Ctrl-C) also leak.

**Why it happens:**
Cleanup is written at the end of the happy path; the `trap` idiom is forgotten.

**How to avoid:**
- `trap 'rm -rf "$TMP_DIR"' EXIT` immediately after creating the temp dir.
- Trap `INT`/`TERM`/`HUP` too.
- Never print a temp path expecting the user to clean it.

**Warning signs:**
- `mktemp -d` with no matching `trap`.
- A "cancel" path that exits without cleanup.

**Phase to address:**
**Foundation & Hardening** (trap convention) + **Photo Printing Suite** (apply to `photoprint.sh`).

**Confidence:** HIGH — confirmed in `photoprint.sh:204,258,262`.

---

### Pitfall 8: Interactive-only scripts with no non-interactive / scripted mode → untestable and unrepeatable

**What goes wrong:**
`photomaster.sh` and `cleanupCachyOS.sh` are pure `read`-prompt TUIs. Every run requires a human at the keyboard, so there is no way to verify a fix, run a regression, or automate. The only "test" is manual. This is why bugs like the division-by-zero and silent failures persist.

**Why it happens:**
Interactive prompts are the fastest way to get a working script; batching/flags feel like extra work.

**How to avoid:**
- Separate **logic from I/O**: pure functions for parsing/math/selection, thin prompt layer on top.
- Support a non-interactive mode: env vars (`PHOTO_SRC_DIR` — already used), flags (`--format`, `--dpi`, `--printer`), or `--yes`.
- Add `bats-core` tests that drive the logic with stubbed binaries and temp dirs.
- Add `shellcheck` + `bash -n` as a pre-commit/CI gate.

**Warning signs:**
- A script that cannot run without a TTY.
- No test directory, no CI.
- Business logic mixed into prompt loops.

**Phase to address:**
**Foundation & Hardening** (test/lint scaffolding) — then every feature phase must add tests for its logic.

**Confidence:** HIGH — confirmed by absence of tests/CI (`.planning/codebase/TESTING.md`) and the TUI structure of `photomaster.sh`/`cleanupCachyOS.sh`.

---

### Pitfall 9: Heuristic cleanup that misidentifies files (size thresholds, filename regex)

**What goes wrong:**
`clean_videos.sh` treats any file < 1 MB as "defective" and deletes it, and uses a `_<digits>p` filename regex to group duplicates. Short clips, heavily-compressed formats, or legitimately small files are destroyed. The regex also silently skips files that don't match the pattern.

**Why it happens:**
Heuristics are a shortcut for real content analysis (resolution probing via `ffprobe`, perceptual hashing). They feel precise but are brittle.

**How to avoid:**
- Never delete on size alone — probe actual media properties (`ffprobe`) or at minimum require a second signal.
- Treat the filename regex as a *filter*, not a deletion criterion; log skipped files.
- Default to quarantine/move, not delete; require `--apply`.
- Show the user the exact rule that triggered each deletion.

**Warning signs:**
- A size threshold used as a deletion predicate.
- Regex-based "duplicate" detection with no content hash for the decision (the script hashes only *after* grouping by size).
- Files silently skipped by a pattern.

**Phase to address:**
**Cleanup & Maintenance** — redesign detection to be conservative and auditable.

**Confidence:** HIGH — confirmed in `clean_videos.sh:22,53,61,86-94`.

---

### Pitfall 10: No audit trail / no logging of what changed

**What goes wrong:**
Cleanup and print scripts print a summary but write nothing persistent. If a file is deleted or a print job is sent, there is no record of *what* happened, *when*, or *why*. `clean_videos.sh` accumulates errors in a buffer but never logs the deleted paths.

**Why it happens:**
Logging feels like overhead for personal scripts.

**How to avoid:**
- Log every mutation to a timestamped file (path, size, reason, timestamp).
- Print the log path in the summary.
- For cleanup, log deletions even in dry-run mode.

**Warning signs:**
- Deletions with no persisted record.
- A summary that is the only evidence of what ran.

**Phase to address:**
**Cleanup & Maintenance** (and **Photo Printing Suite** for print jobs).

**Confidence:** HIGH — confirmed: `clean_videos.sh` has no log file; `photoprint.sh` prints but doesn't log.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Copy-pasting `install_dependencies()` into every script | Works immediately, no shared lib needed | 3+ divergent copies; fixing a package-name bug means editing all of them | Acceptable for 2–3 scripts; extract to `lib/deps.sh` once >3 |
| Detecting IM by `command -v` only | Simple, no version parsing | Silent wrong output on the other IM major | Never for image pipelines — verify version + flags |
| Relative `OUTPUT_DIR="druckbereit"` | Works when CWD is the source folder | Wrong output location from any other CWD | Never — anchor to source or `SCRIPT_DIR` |
| `|| true` on every command | Script never dies mid-run | Failures are invisible; summary lies | Only on genuinely optional probes (e.g. "is docker running?") |
| Heuristic size threshold for deletion | Fast, no probing dependency | Destroys legitimate small files | Never as a deletion predicate |
| Interactive-only prompts | Fastest to write | Untestable, unrepeatable, no automation | Only for the outer menu; core logic must be callable |
| `mktemp -d` without `trap` | Less code | Leaked temp dirs on abort/interrupt | Never |
| Hardcoded hardware/env values (`-ngl 999`, thread counts) | Works on the author's machine | Fails or OOMs elsewhere | Only with a documented config block + auto-detection fallback |

---

## Integration Gotchas

Common mistakes when connecting to external services/tools.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| ImageMagick | Assuming `convert`/`montage` exist; ignoring v6/v7 flag differences | Detect version, test both, prefer `magick` on v7 |
| CUPS (`lp`) | Printing without `-o media=` / `-o fit-to-page`, so output is mis-scaled or spills to extra pages | Pass `-o media=A4 -o fit-to-page`; embed correct `-density`/`-units` in the TIFF/PDF |
| CUPS printer selection | `lpstat -p` output parsed with `awk '{print NR") "$2}'` — breaks on printer names with spaces | Parse `lpstat -p` more robustly or use `lpoptions`/`lpstat -a`; quote the printer name |
| `pacman` / AUR | `pacman -Rns $ORPHANS --noconfirm` without review | Review orphan list first; quote; avoid `--noconfirm` in destructive paths |
| `docker` | `docker system prune -a --volumes -f` behind one `y` | Prune in stages with separate confirmations; never prune volumes implicitly |
| `snapper` / `btrfs` | `snapper cleanup` + `btrfs balance` with no snapshot backup check | Warn that cleanup is irreversible; suggest a fresh snapshot first |
| `sudo` | `exec sudo "$0" "$@"` re-runs the whole script as root (all prompts become root prompts) | Request only the privileged sub-commands via `sudo`, keep the rest unprivileged |
| `find` + `xargs`/`rm` | `find ... | xargs rm` without `-print0`/`-0` | Use `find -delete` or `find -print0 \| xargs -0 rm -f --` |

---

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Loading all images into memory at once (`convert` on many files) | OOM / swap thrash on large batches | Process one file at a time; use `mogrify` for in-place batch ops | Hundreds of high-res photos |
| Hashing every file with `md5sum` in Stage 2 | Slow on large libraries | Hash only same-size candidates (already done); consider size+partial-hash prefilter | Tens of thousands of files |
| Re-running `install_dependencies` + `apt-get update` on every invocation | Slow startup, network dependency | Cache a "deps OK" marker; skip if already satisfied | Every run |
| `find` over huge trees repeatedly | Long scan times | Scope `find` to the target dir; use `-maxdepth` (already done in `clean_videos.sh`) | Very large media libraries |
| Generating full-page TIFFs at 600 DPI | Huge temp files, slow montage | Default 300 DPI; offer 600 as opt-in | Large A3 batches |

---

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Deleting files based on unvalidated CLI paths (`"$@""` in `clean_videos.sh`) | A typo or malicious path targets system directories | Validate paths are within an allowlist; refuse `/`, `/home`, `/etc`, `/var` unless explicitly whitelisted |
| `bash -c "...$REAL_HOME..."` string interpolation | Command injection / breakage if path contains special chars | Pass as array or escape properly |
| `sudo` re-exec of the entire script | All subsequent prompts run as root; a later bug runs privileged | Use `sudo` only for the specific privileged commands |
| No `.gitignore` | `secrets.yaml`, `.env`, model caches committed accidentally | Add `.gitignore` with `secrets.yaml`, `*.env`, cache dirs |
| Downloading models/binaries without checksum verification | Tampered/corrupt artifacts run silently | Verify SHA256 or pin revisions |
| Hardcoded personal entity IDs / paths in shared configs | Privacy leak if repo is shared | Move to `!secret` / placeholders |

---

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No `--help` / usage message | User must read source to learn flags | Add a `usage()` function; accept `-h`/`--help` |
| No non-interactive mode | Can't script or automate a routine | Support flags + env vars; keep prompts as fallback |
| Destructive action with no confirmation | Accidental data loss | Dry-run default + explicit confirm |
| Output path not shown | User can't find results | Print absolute output path in summary |
| German-only UI with English identifiers | Fine for this user, confusing for contributors | Keep German UI (per repo convention) but document in README |
| No progress indication on long operations | User thinks it hung | Add progress/spinner (already used in `clean_videos.sh`/`cleanupCachyOS.sh`) |
| Crashing with a raw bash error | User sees `division by zero` | Validate inputs; print a clear German error |
| Cancel path leaves temp files and prints a path | User must manually clean up | `trap` cleanup; don't expose temp paths |

---

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Cleanup scripts:** Often missing a dry-run/preview — verify `clean_videos.sh` and `cleanupCachyOS.sh` cannot delete without `--apply`.
- [ ] **Image pipelines:** Often missing v6/v7 verification — verify the exact `magick` flags run on both majors.
- [ ] **Photo print:** Often missing edge-case validation — verify photo ≤ paper, DPI numeric, ≥1 photo found.
- [ ] **Path handling:** Often missing CWD independence — verify output lands in the source dir regardless of invocation directory.
- [ ] **Temp files:** Often missing `trap` — verify `mktemp -d` dirs are removed on abort/interrupt.
- [ ] **Error handling:** Often missing strict mode — verify a failed `magick`/`rm` does not still print success.
- [ ] **Testability:** Often missing non-interactive mode — verify core logic runs without a TTY.
- [ ] **Audit:** Often missing a log — verify every deletion/print is recorded persistently.
- [ ] **Safety net:** Often missing `.gitignore` — verify secrets/caches are excluded.
- [ ] **Docs:** Often missing `--help` — verify every script prints usage with `-h`.

---

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Accidental deletion (no dry-run) | HIGH (often unrecoverable) | Restore from backup/trash; if quarantine was used, move back; check `~/.local/share/Trash` |
| Wrong output location (CWD) | LOW | Re-run with correct CWD or `--output`; output is duplicated, not lost |
| ImageMagick wrong output | LOW | Re-run with correct version/flags; originals untouched |
| Division-by-zero crash | LOW | Fix validation; re-run |
| Leaked temp dir | LOW | `rm -rf` the printed temp path; add `trap` |
| Silent failure reported as success | MEDIUM | Re-run with strict mode; inspect which files were actually processed |
| Docker volume/package loss | HIGH | Restore volumes from backup; reinstall packages; check `pacman.log` |
| Temp/interrupt during print | LOW | Clear CUPS queue (`cancel -a`), re-run; add `trap` |

---

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls. *(Phase names indicative — remap to final roadmap.)*

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| 1. Destructive deletion w/o dry-run | Foundation & Hardening + Cleanup | `clean_videos.sh`/`cleanupCachyOS.sh` default to dry-run; `--apply` required; test asserts no `rm` without confirm |
| 2. No strict mode | Foundation & Hardening | `set -euo pipefail` present; `shellcheck` passes; failing `magick` no longer prints success |
| 3. Unquoted/unvalidated expansion | Foundation & Hardening | `shellcheck` clean; prefix-guard helper used before every `rm` |
| 4. IM v6/v7 unverified | Photo Printing Suite | Version printed; montage output verified on both majors |
| 5. Geometry division-by-zero | Photo Printing Suite | Unit test: photo > paper exits with clear error, no crash |
| 6. Relative output paths | Photo Printing Suite | Run from `/tmp`; output still lands in source dir |
| 7. Temp files not cleaned | Foundation & Hardening + Photo Printing | Abort path leaves no temp dir; `trap` present |
| 8. Interactive-only / untestable | Foundation & Hardening | `bats` tests exist; logic runs non-interactively |
| 9. Heuristic misidentification | Cleanup & Maintenance | Deletion requires ≥2 signals; quarantine default |
| 10. No audit trail | Cleanup & Maintenance + Photo Printing | Timestamped log written for every mutation |

---

## Sources

**Codebase (HIGH confidence — primary evidence):**
- `media/clean/clean_videos.sh` — destructive auto-deletion, size threshold, regex grouping
- `system/cleanupCachyOS.sh` — `docker system prune -a --volumes -f`, `pacman -Rns $ORPHANS`, `bash -c` interpolation
- `media/photoprint/photoprint.sh` — division by zero, IM v6/v7 detection, `mktemp` without trap
- `media/photoprint/photoprintcorrection.sh` — relative `OUTPUT_DIR`, silent failures
- `media/photoprint/photomaster.sh` — misleading workflow output, CWD assumptions
- `.planning/codebase/CONCERNS.md`, `CONVENTIONS.md`, `TESTING.md` — prior audit findings

**External (corroborating):**
- Bash safety / destructive-command patterns — community best-practice guides (websearch, LOW confidence tier)
- ImageMagick v6→v7 porting & montage usage — `legacy.imagemagick.org/script/porting.php`, `usage.imagemagick.org/montage` (context7, MEDIUM confidence tier)
- CUPS `lp` options & image scaling — `cups.org/doc/options.html`, `cups.org/doc/man-lp.html`, Debian CUPSImageManipulation wiki (websearch, LOW confidence tier)

---
*Pitfalls research for: handyman utility shell scripts (photo printing, disk cleanup, system maintenance)*
*Researched: 2026-10-19*
