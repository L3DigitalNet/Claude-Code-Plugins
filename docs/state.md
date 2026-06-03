# Handoff

**Last updated:** 2026-06-03 (qdev web-research D1 — implemented; automated acceptance passed)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev web-research D1 — implemented; manual plugin smoke pending.** Commits `8635076`..`a50ca7b` delivered research-KB scripts/tests, migrated report/index, `qdev-researcher` routing/reporting cycle, command/docs, and global routing. Automated acceptance passed. Remaining: in plugin-loaded Claude, run `/qdev:research <topic>` and confirm dispatch + report/index/dedup behavior.
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-03)

- **qdev D1 spec + plan** — D1 design (`1b1de91`) + TDD plan (`f4f9f65`), each audited clean over 3 Codex rounds (`92bac34`/`116075f`/`1433723`; `378634c`/`8d43f90`/`3f075d8`). Pass-2 research folded into the brief (`1225594`).
- **qdev D1 implementation** — 9 commits (`8635076`..`a50ca7b`) implemented the plan; 24 pytest + dedup CLI + corpus validator + index idempotency passed.
- **CR-001 hotfix** (`68b9185`) — all four qdev command dispatches qualified to `qdev:qdev-<agent>` (PLUGIN-001; bare names silently no-op).
- **testing/ drift** (`ee98471`) — dead `testing/STRATEGY.md` / `testing/plans` refs scrubbed from CLAUDE.md + README.md (tree removed in `66b02d4`); remaining refs in architecture.md/conventions.md folded into the D1 plan.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
