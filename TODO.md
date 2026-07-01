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

- [ ] **Execute the spec-pipeline implementation plan** — `docs/superpowers/plans/2026-07-01-spec-pipeline-plugin.md` (14 TDD tasks; spec + plan both Codex-converged 2026-07-01). Subagent-driven recommended. Then live smoke, `/release-pipeline:release` 0.1.0, and ask the user about deprecating `author-master-spec` + `autonomous-phase-execution` in `agent-configs`.
- [ ] **project-standards follow-ups from the 2026-06-12 uv-strict-python conformance review** (fixes belong in that repo): (1) python-coding §31 claims "No compact agent summary … exists today" but the plugin ships one at `skills/uv-strict-python/references/coding-standard.md` — acknowledge it or note plugin summaries; (2) README §6 dev group is unpinned while the adopt-CLI bundle pins `pytest>=9.0` / `ruff>=0.9.0` — reconcile the two.
- [ ] **Verify uv-strict-python BasedPyright LSP loads** (after next session's cache sync picks up v0.2.0): `/reload-plugins`, then check the `/plugin` Errors tab. Needs `basedpyright-langserver` on PATH or uvx fallback.
- [ ] **Release release-pipeline** (5 commits pending, incl. Bug 8 PATH-shim hardening `4f9fd1c`) — `/release-pipeline:release`.
- [ ] **MCP E2E Tests (HA Container) CI is red** — `HA Dev Plugin Tests` → `MCP E2E Tests` job fails: the HA test container's demo integration loads 0 entities, so e2e assertions for `light.bed_light` / `sensor.outside_temperature` etc. fail (13 pass / 10 fail). Pre-existing, environmental (HA version / container onboarding), NOT a dependency issue — surfaced after the 2026-06-08 `typescript-eslint` bump cleared the `npm ci` ERESOLVE that previously masked it. The other 4 HA jobs pass.
