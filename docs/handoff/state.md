# Handoff

**Last updated:** 2026-07-02 (spec-pipeline plugin implemented, reviewed READY-TO-MERGE, pushed; release + smoke next)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## In flight

- **spec-pipeline 0.1.0 release pending.** Plugin implemented and on `main` (commits `44ad1fd..4842a7f`, 101/101 tests, all gates green, final review READY TO MERGE). Next: live smoke in a fresh session (install/cache sync first), `/release-pipeline:release` 0.1.0, then user decides deprecation of `author-master-spec` + `autonomous-phase-execution` in `agent-configs`. 0.1.x hygiene backlog in TODO.md.

## Recently closed (this session, 2026-07-02)

- **spec-pipeline plugin implemented** — all 14 plan tasks via subagent-driven development (fresh implementer + reviewer per task, final whole-branch review on top). specpipe CLI (stdlib-only, PYTHONPATH + `uv run --no-project`, 101 tests), templates, migrated skills, commands, docs, marketplace entry. Final review found 2 Important defects in plan-authored code (fence-unaware citation scan; uncaught `re.error` breaking exit-2 contract) — fixed with regression tests in `4842a7f`. Detail in `sessions/2026-07.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
