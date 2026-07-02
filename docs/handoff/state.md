# Handoff

**Last updated:** 2026-07-02 pm (spec-pipeline fable-review R-001..R-015 all fixed, 122 tests, pushed; release + smoke next)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## In flight

- **spec-pipeline 0.1.0 release pending.** Implemented, fable-reviewed, all 15 findings fixed (`ec74a16`, 122/122 tests, all gates green). Next: live smoke in a fresh session (install/cache sync first), `/release-pipeline:release` 0.1.0, then user decides deprecation of `author-master-spec` + `autonomous-phase-execution` in `agent-configs`. Remaining 0.1.x hygiene backlog in TODO.md.

## Recently closed (this session, 2026-07-02 pm)

- **spec-pipeline fable-review + all 15 findings fixed** (`ec74a16`, pushed). 0C/0H/4M/11L; Mediums: implement-vs-test step misclassification, GREEN accepted any exit-0 (now needs `N passed` / `--expect-success-regex`), fence-unaware `phaseplan.parse`, README HALT claim unbacked by the skills. 21 RED-first regression tests → 122 total; R-012 (collection-phrase-as-data) documented as accepted limitation. Skills bumped to v2.1. Detail in `sessions/2026-07.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
