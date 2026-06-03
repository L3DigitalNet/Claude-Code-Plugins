# CLAUDE.md

**Session startup:** state is injected by the SessionStart hook (see `.claude/hooks/session_start.py`).

**Branch workflow:** Direct commit to `main`. No `testing` branch. Use `/release-pipeline:release` for plugin releases (version bump + tag + GitHub release). See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for full rules.

**Document layout (read on demand):**

- `docs/state.md` — live state + active incidents (auto-injected, do not read directly)
- `docs/deployed.md` — deployment truth + what-remains
- `docs/architecture.md` — repo structure + plugin design principles + full CLAUDE.md detail
- `docs/credentials.md` — credential surfaces
- `docs/conventions.md` — pattern library (Phase 5 deferred)
- `docs/sessions/` — monthly session logs (grep by date)
- `docs/bugs/` — per-file bug KB (grep by service or tag)
- `docs/specs-plans.md` — pointer into `docs/plans/`
- per-plugin tests: `plugins/<plugin>/tests/` (frameworks by language per `docs/conventions.md` TEST-001)
