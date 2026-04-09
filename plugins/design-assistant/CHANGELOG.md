# Changelog — Design Assistant

All notable changes to this plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [0.5.0] - 2026-04-09

### Added
- `scripts/state-manager.sh` for persistent review session state (findings, sections, streaks, deferred log)
- `scripts/invariant-check.sh` validating 7 review and 7 draft state invariants
- `scripts/coverage-sweep.sh` for pre-Phase-5 constraint/risk/governance coverage checking
- `scripts/pause-snapshot.sh` for serializing session state to markdown snapshots

### Changed
- `commands/design-review.md` now initializes state manager, records findings via scripts, and runs invariant checks at pass boundaries
- `commands/design-draft.md` now runs coverage sweep script before Phase 5

## [0.4.0] - 2026-03-27

### Changed
- Extracted shared infrastructure into 7 reference files following the nominal plugin's architecture pattern
- Rewrote both commands as thinner orchestrators that read `references/` on demand instead of embedding all content inline
- design-draft.md reduced from 1,538 to 990 lines; design-review.md from 1,099 to 686 lines
- Created centralized ux-templates.md with 37 output templates from both commands
- Deduplicated interaction conventions, operational commands, and pause/resume protocols

### Removed
- Deleted both stub skills (commands are the sole entry points)
- The `skills/` directory no longer exists

## [0.3.3] - 2026-03-04

### Changed
- update remaining L3Digital-Net references
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply audit findings — plugin.json, CHANGELOG, script

## [0.3.2] - 2026-03-02

### Changed
- Strengthen skill triggers and extract long content to reference files

### Fixed
- Fix structural README issues and docs path
- Replace `\n` with `<br/>` in Mermaid node labels


## [0.3.1] - 2026-02-20

### Changed
- Version bump alongside multi-plugin bulk release


## [0.3.0] - 2026-02-19

### Added
- **DESIGN.md** — architecture decisions document covering 7 key design choices:
  behavioral-only architecture, single-agent workflow, large command file rationale,
  two-command split, warm handoff as text block, phase gate state machine, and
  context pressure management strategy
- **Context pressure hook** (`hooks/hooks.json` + `scripts/read-counter.sh`) —
  PostToolUse Read hook that counts file reads per session and emits warnings at
  10 reads (notice) and 20 reads (strong warning)
- Known Issue entry for 5+ option prompt UX limitation
- Principles section added to README.md

### Changed
- README.md Known Issues: removed stale Q7 checkbox entry; reframed 5+ option
  prompt as a deliberate design decision; updated context pressure note to
  reference the new hook
- design-draft.md: strengthened universal AskUserQuestion directive with explicit
  "applies to code blocks" enforcement and conversion recipe
- design-draft.md Q7: replaced false-affordance checkbox list with numbered
  reference list; split Q8 into two derived AskUserQuestion calls using Q7 answers
- design-draft.md Phase 2A: progressive disclosure — compact summary first, full
  candidate details available via option (B) on demand
- design-draft.md Phase 3: moved domain rationale note outside fenced code block;
  added explicit AskUserQuestion instruction for structure confirmation
- design-draft.md `back` command: added defined output format
- design-review.md: same AskUserQuestion enforcement strengthening as design-draft
- design-review.md empty argument: added defined `✗ NO FILE PROVIDED` message
  template for consistent entry error display
- Audit and split wide-scope skills


## [0.2.0] - 2026-02-18

### Added
- Initial design-assistant plugin release (v0.2.0)

### Fixed
- Removed trailing comma in plugin.json
- Removed invalid commands/skills fields from plugin.json
- Added Session State Model to /design-review with typed variables, initialization
  timing, and 8 state invariants — matches the rigor of /design-draft's state model
- Defined context health thresholds (GREEN/YELLOW/RED) with numeric boundaries and
  explicit warning text for YELLOW and RED states
- Updated Pause State Snapshot to serialize all state groups: principles, gap baseline,
  loop state, compliance/coverage streaks, section status, deferred log, and warm
  handoff context
- Added `continue` reconstruct-and-confirm step (`▶ RESUMING /design-review` block)
  before resuming loop — consistent with /design-draft behaviour
- Fixed Step 3 (Gap Baseline Impact Check) triggering condition: unified across cold
  start and warm handoff to "runs only if Step 2 health check resolutions resulted in
  any principle modifications"
- Fixed skill contradiction in skills/design-review/SKILL.md: auto-invoke response
  now directs users to provide a file path rather than paste content
