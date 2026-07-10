# Project Tasks

<!--
Purpose:
- This document is the user's visible task list and the agent-visible project queue.

Instructions for AI agents:
- Do not add tasks to the `## User tasks` section.
- Do add tasks to the `## Agent tasks` section. Include all open work from agent-managed handoff documents.
- Use `- [ ]` to indicate open work and `- [x]` for work completed during the current session.
- Remove completed standalone agent tasks after recording their outcomes in `docs/STATUS.md`.
-->

## User tasks

- From [https://github.com/L3DigitalNet/project-standards/tree/main/standards](https://github.com/L3DigitalNet/project-standards/tree/main/standards):
  - [ ] Adopt python-tooling

## Agent tasks

- [ ] Emit Prettier-clean frontmatter from `plugins/qdev/scripts/build_research_index.py`.

  `yaml.safe_dump` writes block sequences flush (`- item`) but Prettier wants two-space indent, so regenerating `docs/research/index.md` breaks the format gate. The committed index is currently clean and current; this only surfaces on regen. Ships with a qdev release (plugin code change).

- [ ] Complete the `spec-pipeline` post-release follow-ups.

  Run a live smoke test in a fresh session after plugin installation and cache sync. Ask the user whether to deprecate `author-master-spec` and `autonomous-phase-execution` in `agent-configs`. Remaining hygiene: add `~~~` fence support, dedicated PLAN-NO-FILE-STRUCTURE/INTERFACES/TASKS tests, consistent `plugin.json` key order, and the AC5 lint delta in `references/spec-construction.md`.

- [ ] Reconcile the two `project-standards` findings from the uv-strict-python conformance review.

  Update the Python Coding compact-summary claim and reconcile the README's unpinned dev group with the adopt bundle's `pytest>=9.0` and `ruff>=0.14` floors.

- [ ] Verify the uv-strict-python BasedPyright LSP loads after the next cache sync.

  Run `/reload-plugins`, then check the `/plugin` Errors tab. The environment needs `basedpyright-langserver` on `PATH` or the uvx fallback.

- [ ] Repair the red Home Assistant MCP end-to-end CI job.

  The test container's demo integration loads no entities, so 10 assertions for entities such as `light.bed_light` fail while 13 pass. The other four Home Assistant jobs pass; this is a pre-existing environment or onboarding issue.
