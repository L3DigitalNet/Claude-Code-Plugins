# Handoff

**Last updated:** 2026-06-08 (qdev 2.0.0 search-decoupling shipped + released; 3 plugins de-listed; new agent-configs `web-search` skill)

## Session Instructions

1. Read this file first.
2. Check `docs/handoff/conventions.md` before introducing a new persistent pattern.
3. Branch workflow is direct commit to `main` — see `BRANCH_PROTECTION.md` (no `testing` branch since 2026-05-07).

## Active Incidents

### (none)

## Recently closed (this session, 2026-06-08)

- **qdev 2.0.0 — search decoupling, shipped + released.** qdev slimmed to research-only (removed 4 commands + 3 agents + the `research-grounding` skill + `sanitize_query.py`); routine search moved to a new Claude-only **`web-search` skill** in agent-configs. Released `qdev/v2.0.0` (tag-only). Precursor bugfix `56494ad` corrected qdev-researcher's Tavily MCP key. **De-listed** github-repo-manager / plugin-test-harness / repo-hygiene (marketplace 9→6; tags/releases kept). Spec+plan Codex-converged; executed subagent-driven. Detail + commit refs in `sessions/2026-06.md`. **Next session: restart needed for qdev 2.0.0 to load.**

<!-- 2 KB cap (enforced by propagate-repo): keep ONLY the current session's close here. Older closes live as rows in docs/handoff/sessions/<YYYY-MM>.md. -->
