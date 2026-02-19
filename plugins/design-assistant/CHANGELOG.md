# Changelog — Design Assistant

All notable changes to this plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [0.2.0] - 2026-02-18

### Added
- add design-assistant plugin v0.2.0

### Fixed
- remove trailing comma in plugin.json
- remove invalid commands/skills fields from plugin.json


## [0.2.0] — 2026-02-18

### Fixed

**`/design-review` command**
- Added Session State Model with typed variables, initialization timing, and
  8 state invariants — matches the rigor of `/design-draft`'s state model
- Defined context health thresholds (GREEN/YELLOW/RED) with numeric boundaries
  and explicit warning text for YELLOW and RED states
- Updated Pause State Snapshot to serialize all state groups: principles,
  gap baseline, loop state, compliance/coverage streaks, section status,
  deferred log, and warm handoff context
- Added `continue` reconstruct-and-confirm step (`▶ RESUMING /design-review`
  block) before resuming loop — consistent with `/design-draft` behaviour
- Fixed Step 3 (Gap Baseline Impact Check) triggering condition: unified across
  cold start and warm handoff to "runs only if Step 2 health check resolutions
  resulted in any principle modifications" — the previous warm handoff condition
  ("if Step 2 found new tensions") was incorrect since a tension can be
  acknowledged without modifying any principle

**`skills/design-review/SKILL.md`**
- Fixed skill contradiction: auto-invoke response now directs users to provide
  a file path rather than paste content, consistent with the command's
  file-path-only entry requirement

---

## [0.1.0] — Pre-release scaffolding

### Added

**Plugin scaffolding**
- Repository structure under `plugins/design-assistant/` within marketplace repo
- `plugin.json` manifest (`name: design-assistant`, version `0.1.0`)
- Skill files for `/design-draft` and `/design-review` auto-invocation
- Spec archive under `docs/spec/` (design-draft-v2, design-review-v2)

**`/design-draft` command (v2 spec)**
- Five-phase guided authoring workflow: Orientation → Context → Principles
  Discovery → Scope & Structure → Content Questions → Draft Generation
- Session State Model with typed variables and state invariants
- Phase completion gates — every phase has a checklist before advancing
- Entry point error handling: file not found, wrong file type, ambiguous
  argument, completed doc redirect
- Phase 1: forced-tradeoff questions (Q3b, Q6b), tension scans after
  Rounds 1 and 2, governance_requirements[] state variable
- Phase 2B: SPLIT verdict handling, dissent notes on kept-as-is verdicts,
  Cost of Following field required for STRONG verdicts
- Phase 2C: Step 2C-0 tension flag reconciliation before scenarios
- Phase 4: pre-Phase-5 coverage sweep for constraints, risks, and governance
- Phase 5: principles section quality criteria, OQ log quality criteria,
  Auto-Fix Heuristic omitted from rendered document
- Pause/continue with full state serialisation and snapshot mismatch check
- Finalize / early exit with three-tier readiness assessment
- `export principles` canonical four-section format
- All artifacts written to `[project-folder]/docs/` with standard filenames
- Warm handoff contract to `/design-review` (option B)

**`/design-review` command (v2 spec)**
- Multi-pass review loop: Track A (Structural), Track B (Principle
  Compliance), Track C (Gap Analysis)
- Auto-fix modes A, B, C, D
- Auto-fix eligibility classification (six criteria, HIGH confidence only)
- Findings queue with severity/type ordering and eligibility display
- Diff format with auto-fix vs. manual annotation
- Convergence detection and Completion Declaration
- Session log export with Auto-Fix Effectiveness Report
- All operational commands
- No-principles cold start: structured three-option response when document
  has no principles section and no warm handoff context
- Warm handoff import: reads registry, tension log, OQ log, and Phase 1
  context from `/design-draft → /design-review HANDOFF` block; skips
  principle extraction and re-confirmation
- Pause/continue with `/design-review` label in snapshot header
- Snapshot mismatch check — rejects `/design-draft` snapshots with
  three-option recovery response
- Removed: chunk handling section and `skip chunk` command (OQ2 resolution)
- File path entry only — documents read via Read tool; large documents
  supported without chunking
