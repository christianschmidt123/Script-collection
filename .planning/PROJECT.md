# HandmanSkripts

## What This Is

A collection of handyman utility scripts for common tasks — things like printing pictures in good quality, cleaning up space on HDDs, and other everyday maintenance chores. Built for personal use, kept simple and reliable.

## Core Value

Every script does one common task well and can be run without fuss — grab it, run it, done.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Photo printing at high quality
- [ ] HDD space cleanup
- [ ] Additional utility scripts for common tasks

### Out of Scope

- GUI applications — terminal scripts only
- Cloud integrations — local tools only

## Context

- Existing photo-related shell scripts in `media/photoprint/` (photomaster.sh, photoprintcorrection.sh, photoprint.sh, photoresize.sh)
- Workspace is a multi-topic script collection (esphole, llm, media, system)
- User wants a go-to set of utilities they reach for regularly

## Constraints

- **Platform**: Linux (bash/shell scripts)
- **Simplicity**: Scripts should be easy to understand and modify
- **Dependencies**: Minimize external dependencies; prefer standard tools

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Shell scripts | Matches existing workflow, no build step | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-10-19 after initialization*
