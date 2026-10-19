# Stack Research

**Domain:** Handyman utility shell scripts (photo printing, HDD cleanup, system maintenance)
**Researched:** 2026-10-19
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Bash | 5.3+ | Script interpreter | Universal on Linux, no build step, matches existing workflow. Strict mode (`set -Eeuo pipefail`) catches errors early. Arrays, associative arrays, and `[[ ]]` conditionals are essential for robust scripts. |
| GNU coreutils | 9.x | `find`, `du`, `df`, `xargs`, `sort`, `mktemp` | Zero-install, available on every Linux system. `find -print0` + `xargs -0` handles filenames with spaces/newlines safely. `xargs -P` provides zero-install parallelism. |
| ImageMagick | 7.1.2-34 | Photo resize, montage, format conversion | The standard CLI for image processing in shell scripts. v7's `magick` command replaces `convert`/`montage`. HDRI by default for accurate photo output. Existing photoprint.sh already uses it. |
| CUPS | 2.4.20 | Printing via `lp`/`lpstat`/`lpoptions` | The standard Linux printing system. Handles image files natively. `-o media=A4 -o fit-to-page` for photo printing. `lpstat -p` lists printers. |
| exiftool | 13.59 | Read/write photo EXIF/IPTC/XMP metadata | The de facto standard for metadata in shell scripts. Supports JPEG, TIFF, HEIC, RAW. `-s` short output, `-j` JSON, `-r` recursive. Essential for photo organization scripts. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| jq | 1.8.2 | Parse JSON output from system tools | Parsing `docker system df`, `docker ps --format`, or any tool that outputs JSON. `-r` for raw strings, `-c` for compact. |
| fdupes | 2.x | Find duplicate files by content hash | HDD cleanup scripts. Compares by MD5 then byte-by-byte. Available in all distro repos. Safer than rdfind (which was retired from Fedora). |
| shellcheck | 0.11.0 | Static analysis / linting | Catches quoting bugs, SC2086 word splitting, unused variables, common pitfalls. Run on every script. Pre-commit hook available. |
| shfmt | 3.14.1 | Auto-format shell scripts | Like `gofmt` for bash. `-i 2` for 2-space indent, `-ci` for case indent, `-s` for simplify. Enforces consistent style. |
| bats-core | 1.11+ | TAP-compliant testing framework | Test shell scripts. `setup`/`teardown` hooks, `@test` syntax, `run` + `assert` pattern. Most popular shell test framework. |
| ncdu | 2.9 | Interactive disk usage analyzer (ncurses TUI) | Manual exploration of disk usage. Not scriptable (interactive), but the go-to tool for finding space hogs by hand. |
| dust | 1.1+ | Visual `du` replacement with tree output | Script-friendly disk usage with percentage bars. `-d 2` for depth limit. Modern Rust tool, parseable output. |
| GNU parallel | 20260922 | Advanced parallel execution | When `xargs -P` isn't enough: `--joblog`, `--retries`, `--halt`, rich placeholders. Zero-install alternative is `xargs -P N`. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| `shellcheck -x` | Lint all scripts | `-x` follows `source` directives. Run in CI or pre-commit. |
| `shfmt -d` | Check formatting | `-d` shows diff. `-w` writes. `-l` lists files needing formatting. |
| `bats` | Run test suite | `bats test/` runs all `.bats` files. TAP output for CI integration. |
| `shellcheck --severity=warning` | Stricter linting | Only errors and warnings, not style/info. |

## Installation

```bash
# Core (Arch/CachyOS)
sudo pacman -S bash coreutils imagemagick cups exiftool jq fdupes shellcheck shfmt bats ncdu dust parallel

# Core (Debian/Ubuntu)
sudo apt-get install bash coreutils imagemagick cups libimage-exiftool-perl jq fdupes shellcheck shfmt bats ncdu dust parallel

# Development (pre-commit hooks)
pip install pre-commit
# .pre-commit-config.yaml:
# - repo: https://github.com/koalaman/shellcheck-precommit
#   hooks:
#     - id: shellcheck
# - repo: https://github.com/mvdan-sh/pre-commit-shfmt
#   hooks:
#     - id: shfmt
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| GNU `find` | `fd` (fdfind) | `fd` is faster and respects `.gitignore`, but adds a Rust dependency. Use `fd` for interactive use; `find` for script portability. |
| `xargs -P` | GNU `parallel` | `xargs -P` is zero-install and sufficient for simple fan-out. Use `parallel` when you need `--joblog`, `--retries`, or remote execution. |
| `fdupes` | `rdfind` | `rdfind` has smarter duplicate detection (preserves directory structure) but was retired from Fedora. `fdupes` is universally packaged. Use `jdupes` if speed is critical. |
| `cron` | `systemd timers` | `cron` is simpler and more portable. Use `systemd timers` when you need journal logging, dependency management, or catch-up on missed runs. |
| `ncdu` | `dust` | `ncdu` is interactive TUI (best for manual exploration). `dust` is script-friendly with visual output. Use `ncdu` by hand, `dust` in scripts. |
| `bats-core` | `shunit2` | `shunit2` is older, xUnit-style, pure bash. `bats-core` has better syntax, docs, and ecosystem. Use `shunit2` only if you need POSIX shell compatibility. |
| ImageMagick 7 `magick` | ImageMagick 6 `convert` | v6 is still supported for 10 years but v7 is the future. Scripts should detect `magick` first, fall back to `convert`. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `convert` / `montage` (bare) | Deprecated in v7. `magick` is the primary command. Bare `convert` still works via symlink but is not the documented interface. | `magick` / `magick montage` |
| `rdfind` | Retired from Fedora (orphaned). Less packaged across distros. | `fdupes` (universally available) or `jdupes` (faster) |
| `fd` in scripts | Adds Rust dependency. Not available on minimal systems. | GNU `find` (universal) |
| `echo -e` | Not POSIX. Behavior varies across shells. | `printf '%b\n'` or `printf '%s\n'` |
| `[ ]` test builtin | Less safe than `[[ ]]`. No pattern matching, word splitting issues. | `[[ ]]` (bash) |
| Unquoted variables | Word splitting on spaces/globs. Causes bugs with filenames. | Always quote: `"$var"` |
| `ls` in scripts | Parsing `ls` output is fragile. | `find`, globs, or arrays |
| `bc` for integer math | External process for simple arithmetic. | `$(( ))` arithmetic expansion |
| `curl \| sh` pattern | Security risk. No integrity checking. | Download to file, verify, then execute |

## Stack Patterns by Variant

**If processing photos for print:**
- Use `magick` (IM7) for resize/montage
- Use `exiftool` to read EXIF orientation and color profile
- Use `lp -o media=A4 -o fit-to-page` for CUPS printing
- Use `jq` if parsing `exiftool -j` JSON output

**If cleaning up disk space:**
- Use `fdupes` to find duplicate files
- Use `ncdu` (interactive) or `dust` (script) to analyze usage
- Use `find -mtime +30` to find old files
- Use `du -sh` for quick size checks

**If scheduling periodic maintenance:**
- Use `cron` for simple personal scheduling
- Use `systemd timers` if you need logging, dependencies, or catch-up
- Always use `mktemp -d` + `trap 'rm -rf "$TMPDIR"' EXIT` for temp files

**If processing images in parallel:**
- Use `xargs -P$(nproc)` for zero-install parallelism
- Use `parallel --joblog` if you need logging and retries
- Use `find -print0 | xargs -0` for safe filename handling

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| `magick` 7.1.2 | `convert` 6.x fallback | Script should detect: `command -v magick && MAGICK=magick \|\| MAGICK=convert` |
| `shellcheck` 0.11.0 | bash 3.2+ | Supports bash, sh, ksh, zsh |
| `shfmt` 3.14.1 | bash, POSIX sh, mksh, zsh | v3.13+ has preliminary zsh support |
| `bats-core` 1.11+ | bash 3.2+ | TAP-compliant output |
| `exiftool` 13.59 | Perl 5.6+ | Pure Perl, no compilation needed |
| `jq` 1.8.2 | C89 | Single static binary available |

## Sources

- ImageMagick 7 porting guide — https://imagemagick.org/porting/ (HIGH confidence, official docs)
- exiftool application documentation — https://exiftool.org/exiftool_pod.html (HIGH confidence, official docs)
- CUPS command-line options — https://www.cups.org/doc/options.html (HIGH confidence, official docs)
- jq 1.7 manual — https://jqlang.github.io/jq/manual/v1.7/ (HIGH confidence, official docs)
- shellcheck releases — https://github.com/koalaman/shellcheck/releases (HIGH confidence, verified v0.11.0 Aug 2025)
- shfmt releases — https://github.com/mvdan/sh/releases (HIGH confidence, verified v3.14.1 Sep 2025)
- bats-core documentation — https://bats-core.readthedocs.io (HIGH confidence, official docs)
- fdupes vs rdfind comparison — https://discussion.fedoraproject.org/t/duplicates-finder-in-fedora/72023 (MEDIUM confidence, community)
- bash strict mode best practices — https://mywiki.wooledge.org/BashFAQ/105 (HIGH confidence, community wiki)
- GNU parallel vs xargs — https://micropyramid.com/blog/linux-parallel-processing (MEDIUM confidence, blog)
- systemd timers vs cron — https://linuxblog.io/systemd-timers-alternative-cron-linux (MEDIUM confidence, blog)
- dust vs ncdu — https://github.com/bootandy/dust (HIGH confidence, GitHub)

---
*Stack research for: handyman utility shell scripts (photo printing, HDD cleanup, system maintenance)*
*Researched: 2026-10-19*
