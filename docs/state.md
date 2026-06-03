# Handoff

**Last updated:** 2026-06-03 (qdev D2 — design + plan complete, execution-ready; paused before implementation)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev D2 (grounding skill) — execution-ready; not started.** Spec `docs/plans/2026-06-03-qdev-d2-grounding-skill-design.md` (audited clean r1–r3) + TDD plan `docs/plans/2026-06-03-qdev-d2-grounding-skill-plan.md` (commit `e6510c9`). Resume: execute the 7-task plan via `superpowers:subagent-driven-development`. Builds `sanitize_query.py` + the `research-grounding` skill; reuses D1 unchanged. **D1 manual smoke (below) is a prerequisite** (D2 medium path = that dispatch).
- **qdev web-research D1 — implemented; manual plugin smoke pending.** Commits `8635076`..`a50ca7b` delivered research-KB scripts/tests, migrated report/index, `qdev-researcher` routing/reporting cycle, command/docs, and global routing. Automated acceptance passed. Remaining: in plugin-loaded Claude, run `/qdev:research <topic>` and confirm dispatch + report/index/dedup behavior.
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-03)

- **qdev D2 design + plan** — spec `94dcaf0`, audited clean over 3 Codex rounds (`3274c31`/`2a06021`/`fd65109`; ledger in design §12); 7-task TDD plan `e6510c9`. Execution-ready (see Active Incidents).
- **qdev D1** — shipped earlier this session (`8635076`..`a50ca7b`, 24 pytest); manual smoke pending. Detail in `docs/sessions/2026-06.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
