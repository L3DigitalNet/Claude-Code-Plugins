# Handoff State

## Current focus

- Run the `spec-pipeline` live smoke test after plugin installation and cache sync.
- Obtain the user's decision on deprecating the two source skills in `agent-configs`.
- Work the remaining `docs/TODO.md` agent queue: uv-strict-python LSP verify + project-standards reconcile, HA MCP CI. (qdev research-index generator closed 2026-07-10 — v2.0.4–v2.0.6 released.)

## Active incidents

- Home Assistant MCP end-to-end CI remains red because the test container loads no demo entities;
  - 13 tests pass and 10 entity assertions fail.
