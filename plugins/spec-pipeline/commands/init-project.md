---
description: Scaffold the minimal spec-pipeline handoff layout (phase-plan, audit dir, gitignore entry)
argument-hint: '[target-dir]'
allowed-tools: Bash, Read, Glob
---

# /spec-pipeline:init-project

Scaffold the layout the execute-phase skill expects, via the specpipe CLI:

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe init-project --dir <target>`

Use the directory from $ARGUMENTS, defaulting to the current project root. If the project already keeps agent state somewhere other than `docs/handoff/` (check for an existing handoff/state convention first), pass `--handoff-dir <relative-path>` so the phase plan and audit dir land inside that convention. The operation is idempotent and never overwrites existing files — report what was created vs skipped. Afterwards, point at the created `docs/handoff/phase-plan.md` and note that `/spec-pipeline:author` fills it from a project brief.
