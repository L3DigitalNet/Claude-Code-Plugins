# Changelog

## 0.1.0 — 2026-07-01

Initial release. Merges the `author-master-spec` (v1.6) and `autonomous-phase-execution` (v1.11) skills from agent-configs into one plugin:

- Skills `/spec-pipeline:author` and `/spec-pipeline:execute-phase` (content preserved; validator gates added)
- Deduped shared references (one `spec-construction.md` instead of two identical copies)
- `specpipe` CLI: structural validation for specs/plans/phase-plans, deterministic next-phase resolution, legal status transitions, RED/GREEN evidence capture with collection-error rejection, review-round caps, idempotent project scaffolding
- Templates whose headings are the validator grammar (conformance-tested)
- Utility commands `/spec-pipeline:validate`, `/spec-pipeline:status`, `/spec-pipeline:init-project`
