# Handoff

**Last updated:** 2026-06-03 (qdev web-research D1 — spec + plan complete & audited; execution pending)

## Session Instructions

1. Read this file first.
2. Check `docs/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

- **qdev web-research D1 — execution-ready (fresh session).** Execute `docs/plans/2026-06-03-qdev-research-reporting-plan.md` (10 TDD tasks: PEP 723 scripts + shared parser + dedup helper + pytest → legacy migration → `qdev-researcher` routing/reporting rewrite → command/doc updates → global `~/.claude/CLAUDE.md` routing reconciliation). Spec + plan each survived 3 Codex audit rounds. CR-001 (systemic bare `subagent_type`) already hotfixed (`68b9185`). D2 (escalating skill) is a later cycle. Indexed in `docs/specs-plans.md`.
- **repo-hygiene modernization — paused mid-brainstorm.** Resume from `docs/plans/2026-05-30-repo-hygiene-modernization-program.md` (§11 + §6 Phase 0). Next: spec Phase 0 (skills migration), then `superpowers:writing-plans`.

## Recently closed (this session, 2026-06-03)

- **qdev D1 spec + plan** — D1 design (`1b1de91`) + TDD plan (`f4f9f65`), each audited clean over 3 Codex rounds (`92bac34`/`116075f`/`1433723`; `378634c`/`8d43f90`/`3f075d8`). Pass-2 research folded into the brief (`1225594`).
- **CR-001 hotfix** (`68b9185`) — all four qdev command dispatches qualified to `qdev:qdev-<agent>` (PLUGIN-001; bare names silently no-op).
- **testing/ drift** (`ee98471`) — dead `testing/STRATEGY.md` / `testing/plans` refs scrubbed from CLAUDE.md + README.md (tree removed in `66b02d4`); remaining refs in architecture.md/conventions.md folded into the D1 plan.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/sessions/<YYYY-MM>.md. -->
