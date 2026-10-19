# Feature Research

**Domain:** Handyman utility script collection (bash/shell for Linux)
**Researched:** 2026-10-19
**Confidence:** HIGH

## Feature Landscape

### Table Stakes (Users Expect These)

Features that any personal utility script collection is expected to have. Missing these = collection feels incomplete or not worth keeping.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Disk space cleanup | Every Linux user eventually runs out of disk space; a go-to cleanup script is the most-reached-for tool in any collection | LOW-MEDIUM | Should handle: package caches, old logs, temp files, thumbnails, trash. Dry-run mode expected. |
| Backup utility | Data loss is catastrophic; even personal users want a one-command backup for important directories | MEDIUM | tar-based with timestamp is minimum. Retention/rotation expected. |
| System info / health check | "What's going on with my machine?" is a universal question | LOW | Single command showing CPU, memory, disk, uptime, top processes. |
| Find large files | "What's eating my disk?" — the diagnostic step before cleanup | LOW | `du`-based with sorting and size thresholds. |
| Find duplicate files | Common need for photo/media collections; wastes space | MEDIUM | Hash-based (SHA-256) with size pre-filter. |
| Log rotation / cleanup | Logs silently eat disk; users discover this too late | LOW | Compress old logs, delete very old ones, configurable retention. |
| File extraction (multi-format) | "I just need to unpack this" — universal need | LOW | Wrap tar/gz/bz2/zip/7z/rar with auto-detection. |
| System update helper | "Update everything in one go" — especially on rolling releases | LOW | Wrap apt/dnf/pacman with optional cleanup after. |
| Photo resize / batch resize | Preparing images for web/email/printing is a recurring task | MEDIUM | Already partially covered by `photoresize.sh`. Should support common target sizes. |
| Photo print preparation | Printing photos at correct DPI/size without guesswork | MEDIUM | Already exists (`photoprint.sh`, `photomaster.sh`). Table stakes for this collection given project focus. |

### Differentiators (Competitive Advantage)

Features that make this collection stand out from the dozens of "bash-scripts" repos on GitHub. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Curated, annotated scripts | Most collections are dumping grounds; a curated set with clear "when to use this" comments is genuinely useful | LOW | Each script has a header comment: purpose, usage, when-to-use. |
| Dry-run mode on destructive scripts | Users are terrified of `rm -rf`; dry-run builds trust and encourages actual use | LOW | Flag like `--dry-run` or `-n` on any script that deletes. |
| Interactive menu for common tasks | Lowers the barrier for "I don't remember which script" moments | MEDIUM | A `handyman` or `menu` script that lists and runs the others. |
| Cron-ready monitoring scripts | Scripts designed to run unattended with clear exit codes and logging | MEDIUM | Disk usage alert, service watchdog, backup verification. |
| Photo print quality pipeline | End-to-end: resize → color correct → print-ready output | HIGH | Already partially built; completing the pipeline is a real differentiator. |
| Consistent CLI conventions | All scripts use same flags (`-h` for help, `-n` for dry-run, `-v` for verbose) | LOW | Makes the collection feel like a product, not a junk drawer. |
| Self-documenting (`--help` on every script) | Users shouldn't have to read source to remember usage | LOW | Standardized help output. |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem appealing but would harm this collection's core value of simplicity and reliability.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| GUI wrappers (Zenity/Dialog TUI) | "Scripts are hard to use" | Adds dependencies, breaks over SSH, complicates debugging | Keep scripts pure CLI; offer an optional interactive menu script instead |
| Cloud sync / remote backups | "I want offsite backups" | Adds credentials, network dependencies, complexity | Document how to use `rsync` or `rclone` separately; keep local backup script simple |
| Package manager integration | "Install scripts system-wide" | Most users just want to clone and run; packaging is maintenance burden | Provide a simple `Makefile` or `install.sh` that symlinks to `~/bin` |
| Configuration files / dotfiles | "Make it configurable" | Adds parsing complexity; scripts should use env vars or CLI args | Use environment variables with sensible defaults; document in header |
| Docker container for scripts | "Isolate dependencies" | Massive overkill for bash scripts; breaks the "grab and run" value prop | N/A — not applicable to this project |
| Auto-updating scripts | "Always latest" | Breaks trust; scripts should be stable and predictable | Git-based updates are sufficient for a personal collection |
| Multi-language support (Python/Rewrite) | "Bash is limiting" | Violates project constraint; adds runtime dependencies | Stay pure bash; call external tools when needed |
| Complex error handling frameworks | "Production-grade reliability" | Over-engineering for personal scripts; `set -euo pipefail` + clear messages is enough | Use `set -euo pipefail`, trap errors, print helpful messages |

## Feature Dependencies

```
[Disk Cleanup] ──requires──> [Find Large Files]
                              └──requires──> [System Info]

[Backup Utility] ──requires──> [Log Rotation]
                               └──requires──> [Disk Cleanup]

[Photo Print Pipeline] ──requires──> [Photo Resize]
                                      └──requires──> [Photo Print Preparation]

[Interactive Menu] ──requires──> [All Table Stakes]
                                └──requires──> [Consistent CLI Conventions]

[Cron Monitoring] ──requires──> [System Info]
                               └──requires──> [Disk Cleanup]
```

### Dependency Notes

- **Disk Cleanup requires Find Large Files:** Users need to diagnose before cleaning; the cleanup script should optionally invoke the large-file finder.
- **Backup requires Log Rotation:** Rotated logs should be included in backups; the backup script should respect rotation policy.
- **Photo Print Pipeline requires Resize:** Correct print dimensions depend on proper resizing first.
- **Interactive Menu requires all Table Stakes:** The menu is only as good as the scripts it exposes.
- **Cron Monitoring requires System Info:** Monitoring scripts build on the same data-gathering primitives.

## MVP Definition

### Launch With (v1)

Minimum viable product — what's needed to validate the concept of a curated, reliable handyman script collection.

- [ ] **Disk space cleanup** — the single most common "oh no" moment; proves the collection has value
- [ ] **Backup utility** — second most critical; protects against the worst-case scenario
- [ ] **System info / health check** — most frequently run; establishes the collection as a daily driver
- [ ] **Find large files** — diagnostic companion to cleanup; completes the disk management story
- [ ] **Photo print preparation** — differentiator that leverages existing work; gives the collection a unique identity
- [ ] **Consistent CLI conventions** — makes the collection feel cohesive, not random

### Add After Validation (v1.x)

Features to add once core is working and user is reaching for the collection regularly.

- [ ] **Find duplicate files** — natural extension of disk management
- [ ] **Log rotation / cleanup** — prevents the next disk-full emergency
- [ ] **Interactive menu** — once there are enough scripts to warrant discovery
- [ ] **File extraction** — convenient but not urgent
- [ ] **System update helper** — useful but distro-specific; add when needed

### Future Consideration (v2+)

Features to defer until the collection has proven its value and the user has specific needs.

- [ ] **Cron monitoring scripts** — only valuable once the collection is stable and trusted
- [ ] **Photo color correction pipeline** — complex; only if photo printing becomes a frequent use case
- [ ] **Service watchdog** — only relevant if user runs services (Plex, etc.)
- [ ] **Security audit script** — broad scope; add only if specifically needed
- [ ] **Network tools** — different domain; keep collection focused on local maintenance

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Disk space cleanup | HIGH | LOW | P1 |
| Backup utility | HIGH | MEDIUM | P1 |
| System info / health check | HIGH | LOW | P1 |
| Find large files | HIGH | LOW | P1 |
| Photo print preparation | HIGH | MEDIUM | P1 |
| Consistent CLI conventions | MEDIUM | LOW | P1 |
| Find duplicate files | MEDIUM | MEDIUM | P2 |
| Log rotation / cleanup | MEDIUM | LOW | P2 |
| Interactive menu | MEDIUM | MEDIUM | P2 |
| File extraction | MEDIUM | LOW | P2 |
| System update helper | MEDIUM | LOW | P2 |
| Cron monitoring | LOW-MEDIUM | MEDIUM | P3 |
| Photo color correction | LOW-MEDIUM | HIGH | P3 |
| Service watchdog | LOW | MEDIUM | P3 |
| Security audit | LOW | HIGH | P3 |
| Network tools | LOW | MEDIUM | P3 |

**Priority key:**
- P1: Must have for launch
- P2: Should have, add when possible
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | HariSekhon/DevOps-Bash-tools | djeada/Bash-Scripts | pirate/bash-utils | Our Approach |
|---------|------------------------------|---------------------|-------------------|--------------|
| Disk cleanup | ✅ (comprehensive) | ✅ (basic) | ❌ | Curated, dry-run, safe defaults |
| Backup | ✅ (encrypted) | ✅ (basic tar) | ❌ | Simple, timestamped, retention |
| System info | ✅ (detailed) | ✅ (detailed) | ✅ (via `sysinfo`) | Single-command overview |
| Find large files | ✅ | ✅ | ❌ | Built into cleanup workflow |
| Find duplicates | ✅ | ✅ (SHA-256) | ❌ | Size pre-filter + hash |
| Photo utilities | ❌ | ✅ (resize to A4) | ❌ | Full print pipeline (resize → correct → print) |
| CLI consistency | ❌ (varies) | ❌ (varies) | ✅ (conventions) | Standardized across all scripts |
| Documentation | ✅ (extensive) | ✅ (per-script) | ✅ (README) | Header comments + `--help` |
| Cron-ready | ✅ (many) | ❌ | ❌ | Designed for unattended use |
| Anti-pattern: GUI | ❌ | ❌ | ❌ | ❌ (deliberately avoided) |
| Anti-pattern: cloud | ✅ (AWS/GCP) | ❌ | ✅ (Cloudflare) | ❌ (deliberately avoided) |

**Key insight:** Most collections are either massive and overwhelming (HariSekhon: 1000+ scripts) or inconsistent dumping grounds (djeada: 100+ scripts, varying quality). The opportunity is a **small, curated, consistent** collection where every script is one you'd actually trust to run.

## Sources

- [HariSekhon/DevOps-Bash-tools](https://github.com/HariSekhon/DevOps-Bash-tools/) — 8K+ stars, 1000+ scripts, DevOps-focused
- [djeada/Bash-Scripts](https://github.com/djeada/Bash-Scripts) — 100+ scripts, system admin + utility
- [pirate/bash-utils](https://github.com/pirate/bash-utils) — hand-crafted, opinionated, code layout conventions
- [LINUXexpert-org/SysAdminAutomation](https://github.com/LINUXexpert-org/SysAdminAutomation) — distribution-agnostic sysadmin scripts
- [bocaletto-luca/Bash-Collection](https://github.com/bocaletto-luca/Bash-Collection) — comprehensive personal collection
- [linuxtools.app/shell-scripts](https://linuxtools.app/shell-scripts) — production-ready categorized scripts
- [alebcay/awesome-shell](https://github.com/alebcay/awesome-shell) — curated list of shell tools and resources
- [ruanyf/simple-bash-scripts](https://github.com/ruanyf/simple-bash-scripts) — simple, educational bash scripts

---
*Feature research for: handyman utility script collection (bash/shell for Linux)*
*Researched: 2026-10-19*
