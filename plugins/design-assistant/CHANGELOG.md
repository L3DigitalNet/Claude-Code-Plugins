# Changelog — Design Assistant

All notable changes to this plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [0.3.1] - 2026-02-20

### Changed
- release: 6 plugin releases — agent-orchestrator 1.0.2, home-assistant-dev 2.2.0, release-pipeline 1.4.0, linux-sysadmin-mcp 1.0.2, design-assistant 0.3.0, plugin-test-harness 0.1.1


## [0.3.0] - 2026-02-19

### Added
- audit and split wide-scope skills across all plugins

### Changed
- release: 5 plugin releases — design-assistant 0.3.0, linux-sysadmin-mcp 1.0.2, agent-orchestrator 1.0.2, release-pipeline 1.4.0, home-assistant-dev 2.2.0
- ux(design-assistant): silent completion checks, AskUserQuestion conventions, compact Phase 2D
- add Known Issue for multi-question wall-of-text UX
- add Principles section to all 7 plugin READMEs
- standardise all plugin READMEs with consistent sections


## [0.3.0] — 2026-02-19

### Added
- **DESIGN.md** — architecture decisions document covering 7 key design choices:
  behavioral-only architecture, single-agent workflow, large command file rationale,
  two-command split, warm handoff as text block, phase gate state machine, and
  context pressure management strategy
- **Context pressure hook** (`hooks/hooks.json` + `scripts/read-counter.sh`) —
  PostToolUse Read hook that counts file reads per session and emits warnings at
  10 reads (notice) and 20 reads (strong warning). Mirrors agent-orchestrator's
  read-counter pattern; upgrades context health tracking from behavioral (per-pass)
  to mechanical (per-operation)

### Changed
- **README.md Known Issues** — removed stale Q7 checkbox entry (resolved in 0.2.x UX
  audit); reframed 5+ option prompt entry as a deliberate design decision in a new
  "Design Decisions" section; updated context pressure note to reference the new hook
- **design-draft.md interaction conventions** — strengthened universal AskUserQuestion
  directive with explicit "applies to code blocks" enforcement and conversion recipe
- **design-draft.md Q7** — replaced false-affordance checkbox list with numbered
  reference list; split Q8 into two derived AskUserQuestion calls using Q7 answers
- **design-draft.md Phase 2A** — progressive disclosure: compact summary first,
  full candidate details available via option (B) on demand
- **design-draft.md Phase 3** — moved domain rationale note outside fenced code block;
  added explicit AskUserQuestion instruction for structure confirmation
- **design-draft.md `back` command** — added defined output format
  (`◀ BACK — Returning to Phase [N]: [Phase Name] — resuming at [last confirmed step]`)
- **design-review.md interaction conventions** — same AskUserQuestion enforcement
  strengthening as design-draft
- **design-review.md empty argument** — added defined `✗ NO FILE PROVIDED` message
  template for consistent entry error display

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
