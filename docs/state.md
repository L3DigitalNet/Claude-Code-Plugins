# Handoff

**Last updated:** 2026-06-05 (qdev v1.6.0 released; D2 incident advanced — release blocker cleared, Task 7 manual matrix unblocked)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev D2 (grounding skill) Task 7 — manual matrix pending.** Feature released v1.6.0 (commit `efe90b8`). Remaining: auto-trigger rules, fake-token approval-before-egress, reject/approve persist gate. (Implementation detail: `f24d690`..`d627a0c` + hardening; 144 pytest green.)
- **qdev web-research D1 — plugin smoke functionally confirmed.** `/qdev:research` started `qdev:qdev-researcher`, deduped, wrote+validated a report, regenerated index (`9550937`).
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-05)

- **qdev v1.6.0 release** — commit `efe90b8`, tag `qdev/v1.6.0`, release published. D2 feature (grounding skill + sanitizer) shipped in tagged release; prior 18 commits on `main` with unreleased feature now available to marketplace.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
