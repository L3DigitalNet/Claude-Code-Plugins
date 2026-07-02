# Handoff

**Last updated:** 2026-07-02 evening (all 7 marketplace plugins released and current; ENV-001 refined + Bug 9 recorded)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## In flight

- **spec-pipeline post-release follow-ups.** Released as v0.2.0. Still open: live smoke test in a fresh session (install/cache sync first), then user decides deprecation of `author-master-spec` + `autonomous-phase-execution` in `agent-configs`. Remaining 0.1.x hygiene backlog in TODO.md.

## Recently closed (this session, 2026-07-02 evening)

- **All 7 marketplace plugins released.** Two batch passes: pass 1 released spec-pipeline v0.2.0, home-assistant-dev v2.2.11, qt-suite v0.3.4, qdev v2.0.3 clean; quarantined release-pipeline, up-docs, uv-strict-python on real pre-flight test failures. Root-caused and fixed all 3 (Bug 9: ENV-001's global PATH guard shadowed npm/ssh test stubs in `auto-build-plugins.sh`/`server-inspect.sh`; uv-strict-python re-synced to `project-standards@6cf2228`), swept the other 11 ENV-001-guarded scripts (none exposed), then pass 2 released release-pipeline v2.2.3, up-docs v0.13.1, uv-strict-python v0.2.1 clean. `detect-unreleased.sh` confirms zero plugins remain unreleased. Detail in `sessions/2026-07.md`.

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
