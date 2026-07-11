# Handoff State

## Current focus

- Run the `spec-pipeline` live smoke test after plugin installation and cache sync.
- Obtain the user's decision on deprecating the two source skills in `agent-configs`.
- Work the remaining `docs/TODO.md` agent queue: qdev research-index generator (non-Prettier YAML), uv-strict-python LSP verify + project-standards reconcile, HA MCP CI.

## Active incidents

- Home Assistant MCP end-to-end CI remains red because the test container loads no demo entities;
  - 13 tests pass and 10 entity assertions fail.
