# Handoff

**Last updated:** 2026-07-01 (spec-pipeline plugin designed + planned; both Codex-converged; implement next session)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## In flight

- **spec-pipeline plugin — ready to implement.** Spec `docs/superpowers/specs/2026-07-01-spec-pipeline-plugin-design.md` (Codex-converged, 4 rounds, in-doc ledger) + plan `docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md` (14 TDD tasks, Codex-converged 2 rounds, r2 clean; plan header carries review status). Execute via `superpowers:subagent-driven-development` (recommended) or `executing-plans`. After implementation: live smoke, `/release-pipeline:release` 0.1.0, then user decides deprecation of the two source skills in `agent-configs`.

## Recently closed (this session, 2026-07-01)

- **spec-pipeline design cycle** — merged `author-master-spec` + `autonomous-phase-execution` design into one plugin spec with a stdlib-only `specpipe` validator CLI (structural gates before every review pass, resume-safe phase state, safety-contracted RED/GREEN evidence capture). Full adversarial loop: spec r1–r4, plan r1–r2 (clean); audits in `docs/codex-reviews/` (now lint-exempt as generated evidence). Detail in `sessions/2026-07.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
