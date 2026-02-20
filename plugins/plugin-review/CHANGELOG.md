# Changelog

## [0.2.0] - 2026-02-20

### Added
- PostToolUse hook `validate-agent-frontmatter.sh` — warns when disallowed tools (Write, Edit, Bash, etc.) are added to analyst agent YAML frontmatter, providing secondary enforcement for [P9]
- Architectural role headers (`<!-- -->` comment blocks) to all six template files documenting which component loads each template, output format contracts, and cross-file dependencies
- Architectural role header to `skills/scoped-reaudit/SKILL.md` documenting the orchestrator-skill contract and what breaks if the mapping table changes

### Added
- `docs/DESIGN.md`: new "Hook Design: PostToolUse Agent Frontmatter Validator" section documenting the always-active frontmatter validation gate, its disallowed tool list, and its relationship to primary structural enforcement via agent YAML frontmatter

### Changed
- `commands/review.md` Phase 1.1: bounded plugin selection — uses `AskUserQuestion` with up to 4 options; fallback provides format hint rather than open-ended free-text prompt
- `commands/review.md` Phase 1.3: principles and checkpoints now formatted as markdown tables (ID | Name | Definition), not a flat list
- `commands/review.md` Phase 1.4: touchpoint map now formatted as a markdown table (# | Touchpoint | Type | Source File)
- `commands/review.md` Phase 2: reads `pass_number` from state file rather than relying on in-memory variable alone — survives context compaction
- `commands/review.md` Phase 4: proposal approval uses `AskUserQuestion` with four bounded options (quick wins / quick+structural / all / none)
- `commands/review.md` Phase 5: pass budget decision uses `AskUserQuestion` with three bounded options (continue / accept gaps / final focused pass)
- `commands/review.md` Phase 5: persists `pass_number` to state file after each increment
- `commands/review.md` Phase 1.2: triage boundary is now explicitly defined — lists which file types are permitted in orchestrator direct reads vs. subagent-only reads
- Session state initialization now includes `pass_number: 1` in `.claude/state/plugin-review-writes.json`
- `templates/cross-track-impact.md` annotation format: cross-track impact annotations now use indented blockquote (`> **Cross-track impact**: ...`) for visual subordination from proposal body text
- `templates/final-report.md`: standardized null-state handling — "Files Modified" section now uses `(omit if no files were modified)` to match the same convention as "Accepted Gaps"
- `scripts/doc-write-tracker.sh` warning: changed to imperative phrasing ("Update README.md..." instead of "Remember to update..."); added blank lines before and after for visual separation
- `README.md` [P6] principle description: clarified that the hook "mechanically warns" (not "provides mechanical enforcement"); added note that full blocking enforcement requires a manual pre-completion check
- `docs/DESIGN.md` Enforcement Layer Mapping: corrected Doc co-mutation row from "Mechanical" to "Mechanical (warn-only)"
- `docs/DESIGN.md` Hook Design section: corrected impl-dir categorization description to list exact directory prefixes used in the script; added known gap note for `hooks/hooks.json` not being tracked

### Fixed
- `README.md` Hooks table omitted `NotebookEdit` from the PostToolUse matcher description — now matches actual `hooks.json` matcher pattern

## [0.1.1] - 2026-02-19

### Fixed
- source root principles from README.md not CLAUDE.md


## [0.1.0] - 2026-02-19 — Initial Release

### Added
- Orchestrator command (`/review`) with 6-phase convergence loop
- Three analyst subagents: principles-analyst, ux-analyst, docs-analyst
- Six externalized templates: track criteria (A, B, C), pass report, final report, cross-track impact
- Scoped re-audit skill with file-to-track mapping
- PostToolUse hook for documentation co-mutation tracking
- Session commands: skip, focus, light-pass, revert-pass
- 3-pass budget enforcement with user checkpoint
- [C1] LLM-Optimized Commenting checkpoint — evaluates whether target plugin's in-code comments are tuned for AI readers (architectural role headers, intent-over-mechanics, constraint annotations, decision context, cross-file contracts)
