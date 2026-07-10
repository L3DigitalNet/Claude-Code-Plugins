# CLAUDE.md

**Session startup:** Agent Handoff injects state through the shared repo-local SessionStart hook.

**Branch workflow:** Direct commit to `main`. No `testing` branch. Plugin releases are manual — bump `plugins/<name>/.claude-plugin/plugin.json` and its matching `.claude-plugin/marketplace.json` entry, then commit, tag `<name>/vX.Y.Z`, push, and `gh release create`. See [BRANCH_PROTECTION.md](BRANCH_PROTECTION.md) for full rules.

**Document layout (read on demand):**

- `docs/handoff/state.md` — live state + active incidents (auto-injected, do not read directly)
- `docs/handoff/deployed.md` — deployment truth + what-remains
- `docs/handoff/architecture.md` — repo structure + plugin design principles + full CLAUDE.md detail
- `docs/handoff/credentials.md` — credential surfaces
- `docs/handoff/conventions.md` — pattern library (Phase 5 deferred)
- `docs/handoff/sessions/` — monthly session logs (grep by date)
- `docs/handoff/bugs/` — per-file bug KB (grep by service or tag)
- `docs/handoff/specs-plans.md` — pointer into `docs/plans/`
- per-plugin tests: `plugins/<plugin>/tests/` (frameworks by language per `docs/handoff/conventions.md` TEST-001)

<!-- BEGIN agent-handoff managed instructions -->
Use the repo-local `$agent-handoff` skill at startup and closeout.
Do not reread `docs/handoff/state.md` when SessionStart already injected it.
Keep current status and tasks in `docs/STATUS.md` and `docs/TODO.md`; route durable facts through `docs/handoff/`.
At closeout, update only changed facts, preserve user-authored work, store credential references only, and run relevant validation.
<!-- END agent-handoff managed instructions -->
