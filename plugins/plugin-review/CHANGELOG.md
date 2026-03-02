# Changelog

## [0.5.0] - 2026-03-02

### Added
- bump to v0.5.0 — Track D context efficiency integration
- migrate tighten command with corrected skill path
- migrate review-efficiency command with corrected skill paths
- add context-efficiency-workflow, context-efficiency-reference, markdown-tighten skills
- add Track D file-to-track mapping in scoped-reaudit skill
- register Track D in cross-track impact map
- add Track D context efficiency status to final-report template
- add Track D context efficiency to pass-report template
- add efficiency-analyst Track D to Phase 2 spawn and tier table
- add efficiency-analyst agent for Track D
- add track-d-criteria template for context efficiency

### Changed
- update P9 and hooks table to say 'blocks' not 'warns'
- em dash cleanup, root README sync
- Update GitHub org references from L3DigitalNet to L3Digital-Net
- reduce AI writing signals across all plugin READMEs
- Enhance Release Pipeline and Repo Hygiene Plugins
- update plugin docs, PTH README for v0.6.0, and repo template

### Fixed
- fix path injection in validate-agent-frontmatter.sh; fix CHANGELOG em dashes
- extend doc-write-tracker to cover hooks/ (including hooks.json)
- make validate-agent-frontmatter.sh blocking (exit 2)
- final review fixes — Track D label, type enum, cross-refs, diagram
- resolve Track D collision and update Summary/P7 in README
- update stale skill cross-references to new structured paths
- add state file pattern and Track D to Decision Logic in scoped-reaudit
- correct A→D relationship to P10 and tighten P1 paraphrase
- align P9/P10 names and clean up P1 placeholder in final-report
- add context efficiency to Upheld roll-up in pass-report
- anchor efficiency-analyst spawn to concrete Phase 1 artifacts
- clarify output contract and align assertion schema in efficiency-analyst
- align track-d P7/P9/P10 definitions with canonical source
- remove em dashes from all READMEs; add hygiene check
- replace \n with <br/> in mermaid node labels across all plugin READMEs


## [Unreleased]

### Fixed

- `validate-agent-frontmatter.sh` now exits 2 (blocking) instead of 0 (warn-only) when disallowed write tools are detected in analyst agent YAML frontmatter; this closes the P9 enforcement gap
- `doc-write-tracker.sh` now tracks all `hooks/` files (including `hooks/hooks.json`) as implementation files; changes to hook configuration now trigger the P6 co-mutation warning

## [0.5.0] - 2026-03-01

### Added

- Track D context efficiency analysis: `efficiency-analyst` agent evaluates P1–P12 compliance in parallel with Tracks A/B/C
- `track-d-criteria.md` template: P1–P12 evaluation criteria with component examination table
- `review-efficiency` command: standalone 5-stage interactive context efficiency review (migrated from context-efficiency-toolkit)
- `tighten` command: prose tightening workflow for plugin markdown files (migrated from context-efficiency-toolkit)
- `context-efficiency-workflow` skill: approval-gated P1–P12 review workflow
- `context-efficiency-reference` skill: P1–P12 principle definitions and layer taxonomy
- `markdown-tighten` skill: five-step prose compression workflow
- Track D entries in `pass-report.md` and `final-report.md` templates
- Track D mapping in `cross-track-impact.md` and `scoped-reaudit/SKILL.md`

## [0.4.0] - 2026-02-21

### Added
- `--autonomous` flag — enables fully autonomous convergence mode alongside existing interactive mode
- `agents/regression-guard.md` — 4th read-only analyst subagent; spawned on Pass 2+ in autonomous mode to perform narrative re-verification of previously-fixed findings, returning per-finding holding/regressed/indeterminate status
- `agents/build-fix-agent.md` — write-capable fix-forward subagent; invoked in Phase 4.5 when build or test commands fail after an implementation pass
- `scripts/discover-test-commands.sh` — probes a plugin directory for build and test commands (npm scripts, Makefile targets, pytest config, `scripts/test*.sh` files); outputs JSON array
- `scripts/run-build-test.sh` — runs discovered build/test commands with structured JSON output and human-readable stderr summary; exit 0 = all pass, exit 1 = some fail
- `templates/convergence-metrics.md` — template for the final report Convergence Metrics section (autonomous mode only)
- Phase 4.5 (Build/Test Validation) — runs `run-build-test.sh` for target plugin and plugin-review self-check after each implementation pass; spawns `build-fix-agent` on failure (at most once per pass)
- Tier classification system — orchestrator assigns Tier 1 (docs/formatting), Tier 2 (error handling/validation), or Tier 3 (architectural/behavioral) to each finding before fixing; all tiers auto-fixed; tier affects logging verbosity and metrics only
- Convergence metrics in Phase 6 — elapsed time, total passes, tier breakdown (T1/T2/T3 counts), regressions caught by guard, build/test failure count
- Regression guard integration in Phase 2 — spawned alongside analyst subagents on Pass 2+; results processed in Phase 2.5, `regression_guard_regressions` tracked in state
- Extended state schema for autonomous mode: `mode`, `start_time`, `tier_counts`, `fixed_findings`, `build_test_failures`, `regression_guard_regressions`
- Tier1/Tier2/Tier3 columns added to Convergence table in pass-report.md and Pass History table in final-report.md (autonomous mode only)
- Regression Guard section added to Pass 2+ format in pass-report.md (autonomous mode only)
- Regression Guard Exception section added to scoped-reaudit skill documenting that it always spawns on Pass 2+ in autonomous mode, outside the A/B/C track system

### Changed
- Convergence criterion in autonomous mode requires BOTH assertion confidence = 100% AND regression guard reporting zero regressions; either condition alone is insufficient
- Phase 5.5 budget-check extended to include regression guard status in autonomous mode
- `commands/review.md` trigger description updated to mention `--autonomous` flag
- Hard Rules updated: autonomous mode tier behavior, Phase 4.5 scope restriction, build-fix-agent spawn limit

## [0.3.0] - 2026-02-20

### Added
- add Assertion Coverage section to final report template
- add Confidence column to pass report convergence tables
- refactor convergence loop — fully automated with assertion runner
- add Assertions block to docs-analyst output format
- add Assertions block to ux-analyst output format
- add Assertions block to principles-analyst output format
- add fix-agent — write-capable assertion-driven fixer
- add run-assertions.sh assertion runner with smoke tests
- enhance skills and commands for context efficiency review and markdown tightening
- add documentation for PostToolUse Agent Frontmatter Validator in DESIGN.md
- update version to 0.2.0 and enhance documentation with new hooks and validation features

### Changed
- bump to v0.3.0 — assertion-driven convergence loop

### Fixed
- address code review — Phase 5 duplication, loop safety, test coverage
- integration test self-review fixes (v0.3.0)
- clarify convergence loop conditions and fix-agent context in review.md
- complete assertion type enum + guide in docs-analyst
- complete assertion type enum in ux-analyst (add typescript_compile)
- harden run-assertions.sh — JSON error handling, file handle fix, field validation


## [0.3.0] - 2026-02-20

### Added
- `scripts/run-assertions.sh` — machine-verifiable assertion runner; reads `.review-assertions.json`, executes all assertions by type (grep_not_match, grep_match, file_exists, file_content, typescript_compile, shell_exit_zero), updates pass/fail status, computes confidence score (assertions_passed/total)
- `scripts/test-run-assertions.sh` — smoke test for the assertion runner covering all 6 assertion types plus a fail-case that verifies exit code 1
- `agents/fix-agent.md` — write-capable targeted fix agent for assertion-driven regressions; one invocation per pass receives all failing assertions and implements minimal fixes
- `## Assertions Output` block added to all three analyst agents (principles-analyst, ux-analyst, docs-analyst) — each generates machine-verifiable JSON assertions alongside findings, one per open finding
- Phase 2.5 (Assertion Collection) in orchestrator — extracts and merges analyst assertion JSON blocks into `.claude/state/review-assertions.json`, deduplicating by `id`
- Phase 5.5 (Assertion Runner) in orchestrator — runs full assertion suite after implementation, spawns fix-agent for failures, re-runs assertions, checks max-passes budget
- `--max-passes=N` flag — parsed from invocation text via regex `--max-passes=(\d+)`; replaces hardcoded 3-pass budget (default 5)
- Confidence score (`assertions_passed / total_assertions`) reported at each pass and in final report
- `Confidence` column in pass-report.md convergence table
- Assertion Coverage section in final-report.md

### Changed
- Phase 4 is now fully automated — `AskUserQuestion` gate removed; all proposals auto-implemented without human approval
- Phase 5 renamed to "Persist Pass Counter" — implementation work moved to Phase 4; Phase 5 now only increments `pass_number`
- Zero-findings path now increments `pass_number` before jumping to Phase 5.5 — prevents infinite loop when assertions fail on a clean pass
- Pass budget changed from hardcoded 3 to `--max-passes=N` (default 5)
- Loop convergence criterion is now confidence-based (`confidence < 100%`), not finding-count-based
- Session cleanup now removes both `plugin-review-writes.json` and `review-assertions.json`
- State file initialization includes `max_passes` field in both state files
- `$CLAUDE_PLUGIN_ROOT` syntax standardized — angle-bracket format removed from all prose references
- Phase 5.5 failure_output display truncation increased from 100 to 200 characters for better TypeScript error visibility
- `commands/review.md` Phase 2: added progress signal instruction ("Pass N: spawning analyst subagents...") before subagent spawn to address silent gap

### Fixed
- Duplicate `### Added` section header in 0.2.0 CHANGELOG entry (pre-existing drift)
- `README.md` [P5] description: corrected stale "3 passes" reference to "configured pass budget (default 5, overridden by `--max-passes=N`)"
- `README.md` Key Design Decisions: updated "3-pass budget" entry to "Configurable pass budget"
- `docs/DESIGN.md` Pass Budget Rationale: updated "Three passes chosen as default" to reflect 5-pass default and `--max-passes=N` configurability

## [0.2.0] - 2026-02-20

### Added
- PostToolUse hook `validate-agent-frontmatter.sh` — warns when disallowed tools (Write, Edit, Bash, etc.) are added to analyst agent YAML frontmatter, providing secondary enforcement for [P9]
- Architectural role headers (`<!-- -->` comment blocks) to all six template files documenting which component loads each template, output format contracts, and cross-file dependencies
- Architectural role header to `skills/scoped-reaudit/SKILL.md` documenting the orchestrator-skill contract and what breaks if the mapping table changes
- `docs/DESIGN.md`: new "Hook Design: PostToolUse Agent Frontmatter Validator" section documenting the always-active frontmatter validation gate, its disallowed tool list, and its relationship to primary structural enforcement via agent YAML frontmatter

### Fixed
- `scripts/doc-write-tracker.sh` fallback initializer: added `pass_number` to the fallback JSON schema (`{"impl_files":[],"doc_files":[],"pass_number":1}`) so it matches `review.md`'s initialization — prevents silent counter reset if the state file is deleted mid-session and the hook's fallback fires
- `scripts/doc-write-tracker.sh` warning output: modified file paths are now printed one per indented line instead of comma-joined, preventing line wrapping at 80–120 column terminals when file paths are long

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
