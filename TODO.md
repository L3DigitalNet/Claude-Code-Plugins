# TODO

**Do not delete.**

## Purpose

This document is the user's visible task list alongside the v3 handoff system. Use it to track action items, follow-ups, and personal notes that should stay easy to find instead of living only in agent-facing handoff docs.

## Usage Instructions

- Write each actionable item as an unchecked Markdown task: `- [ ]`.
- When an item is completed during a session, change its marker to `- [x]`.
- During v3 handoff closeout, delete completed items from this document.
- Mirror any handoff task, todo, pending item, or follow-up here so the user can track it.
- Do not start or complete TODO items unless the user explicitly asks for that work.

<!-- LLM-EDIT-BOUNDARY: DO NOT EDIT ABOVE THIS LINE -->

## User Tracked Tasks

- From [https://github.com/L3DigitalNet/project-standards/tree/main/standards](https://github.com/L3DigitalNet/project-standards/tree/main/standards):
  - [ ] Adopt python-tooling

## Agent Tracked Tasks

- [ ] **spec-pipeline follow-ups** — released as v0.2.0 (2026-07-02); still open: live smoke test in a fresh session (needs plugin install + cache sync), decide deprecation of `author-master-spec` + `autonomous-phase-execution` in `agent-configs`. Remaining 0.1.x hygiene backlog (word-boundary scans done in `ec74a16`): `~~~` fence support, dedicated PLAN-NO-FILE-STRUCTURE/INTERFACES/TASKS tests, plugin.json key-order consistency, AC5 one-line lint delta in `references/spec-construction.md` (plan-mandated CR-005).
- [ ] **project-standards follow-ups from the 2026-06-12 uv-strict-python conformance review** (fixes belong in that repo): (1) python-coding §31 claims "No compact agent summary … exists today" but the plugin ships one at `skills/uv-strict-python/references/coding-standard.md` — acknowledge it or note plugin summaries; (2) README §6 dev group is unpinned while the adopt-CLI bundle pins `pytest>=9.0` / `ruff>=0.14` (bumped from `0.9.0` in the 2026-07-02 re-sync) — reconcile the two.
- [ ] **Verify uv-strict-python BasedPyright LSP loads** (after next session's cache sync picks up v0.2.1): `/reload-plugins`, then check the `/plugin` Errors tab. Needs `basedpyright-langserver` on PATH or uvx fallback.
- [ ] **MCP E2E Tests (HA Container) CI is red** — `HA Dev Plugin Tests` → `MCP E2E Tests` job fails: the HA test container's demo integration loads 0 entities, so e2e assertions for `light.bed_light` / `sensor.outside_temperature` etc. fail (13 pass / 10 fail). Pre-existing, environmental (HA version / container onboarding), NOT a dependency issue — surfaced after the 2026-06-08 `typescript-eslint` bump cleared the `npm ci` ERESOLVE that previously masked it. The other 4 HA jobs pass.
- [ ] **Stale `.release-waivers.json` entry** — the `noreply_email` waiver's reason string ("GitHub noreply address not configured") is outdated; `fix-git-email.sh` now reports the address as compliant on its own merit (no waiver invoked). Minor doc-hygiene cleanup, not blocking.
