# Changelog

## [0.2.0] - 2026-07-02

### Added

- utility commands, README, changelog
- migrate author + execute-phase skills with specpipe validator gates
- idempotent init-project scaffolding
- artifact templates conformant with the validator grammar
- review-round counters with deterministic cap enforcement
- RED/GREEN evidence capture with collection-error rejection
- plan validator — TDD step order, anti-patterns, symbol forward-refs
- spec validator — core sections, master register/ceiling, phase citation resolution
- deterministic next-phase resolution, atomic status transitions, status render
- phase-plan parser and structural/graph validator
- canonical grammar module with fence-aware markdown helpers
- specpipe project skeleton — findings model, lazy CLI dispatch, test wrapper
- scaffold plugin, dedupe shared references, register in marketplace

### Fixed

- apply fable-review findings R-001..R-015
- fence-aware citation scan, regex exit-2 guard, mode-preserving rewrite, non-dict state recovery
- resolve markdownlint MD041/MD033 gate failures
- correct ultracode term in README requirements

## 0.1.0 — 2026-07-01

Initial release. Merges the `author-master-spec` (v1.6) and `autonomous-phase-execution` (v1.11) skills from agent-configs into one plugin:

- Skills `/spec-pipeline:author` and `/spec-pipeline:execute-phase` (content preserved; validator gates added)
- Deduped shared references (one `spec-construction.md` instead of two identical copies)
- `specpipe` CLI: structural validation for specs/plans/phase-plans, deterministic next-phase resolution, legal status transitions, RED/GREEN evidence capture with collection-error rejection, review-round caps, idempotent project scaffolding
- Templates whose headings are the validator grammar (conformance-tested)
- Utility commands `/spec-pipeline:validate`, `/spec-pipeline:status`, `/spec-pipeline:init-project`
- Pre-release review hardening (R-001..R-015): positive GREEN pass signature (`record-green --framework/--expect-success-regex`), supplied failure/success regexes always enforced, fence-aware phase-plan parsing, implement-before-test step classification, word-boundary phrase/symbol scans, empty symbol-table warning, `next-phase` reason output (`all_complete` vs `blocked`), git-root-bounded state search, redact-before-cap evidence capture, Python ≥ 3.11 startup guard, `blocked → pending` recovery transition, review-tooling HALT preconditions in both skills
