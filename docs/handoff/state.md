# Handoff

**Last updated:** 2026-06-05 (handoff v3.1 migration verified; deployed.md + 3 stale `docs/specs/` refs corrected)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev D2 (grounding skill) Task 7 — manual matrix pending.** Feature released v1.6.0 (commit `efe90b8`). Remaining: auto-trigger rules, fake-token approval-before-egress, reject/approve persist gate. (Implementation detail: `f24d690`..`d627a0c` + hardening; 144 pytest green.)
- **qdev web-research D1 — plugin smoke functionally confirmed.** `/qdev:research` started `qdev:qdev-researcher`, deduped, wrote+validated a report, regenerated index (`9550937`).
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-05)

- **Handoff v3.1 migration verified + doc drift corrected.** `validate-layout.sh` passes; hook hash matches canonical source. Fixed `deployed.md` version drift (up-docs 0.9.0→0.9.1 _released_; repo-hygiene **1.4.3** + test-driver **0.6.2** flagged marketplace-live-but-untagged, release pending) and 3 stale `docs/specs/` refs (`AGENTS.md`, `conventions.md`, `specs-plans.md` → real `docs/plans/` + `docs/research/` + `docs/superpowers/`).

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
