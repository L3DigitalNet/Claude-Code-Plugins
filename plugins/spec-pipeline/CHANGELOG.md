# Changelog

## 0.1.0 — 2026-07-01

Initial release. Merges the `author-master-spec` (v1.6) and `autonomous-phase-execution` (v1.11) skills from agent-configs into one plugin:

- Skills `/spec-pipeline:author` and `/spec-pipeline:execute-phase` (content preserved; validator gates added)
- Deduped shared references (one `spec-construction.md` instead of two identical copies)
- `specpipe` CLI: structural validation for specs/plans/phase-plans, deterministic next-phase resolution, legal status transitions, RED/GREEN evidence capture with collection-error rejection, review-round caps, idempotent project scaffolding
- Templates whose headings are the validator grammar (conformance-tested)
- Utility commands `/spec-pipeline:validate`, `/spec-pipeline:status`, `/spec-pipeline:init-project`
- Pre-release review hardening (R-001..R-015): positive GREEN pass signature (`record-green --framework/--expect-success-regex`), supplied failure/success regexes always enforced, fence-aware phase-plan parsing, implement-before-test step classification, word-boundary phrase/symbol scans, empty symbol-table warning, `next-phase` reason output (`all_complete` vs `blocked`), git-root-bounded state search, redact-before-cap evidence capture, Python ≥ 3.11 startup guard, `blocked → pending` recovery transition, review-tooling HALT preconditions in both skills
