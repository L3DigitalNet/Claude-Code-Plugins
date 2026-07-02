---
description: Run spec-pipeline structural validators against a spec, plan, or phase-plan file
argument-hint: '[path] [master|phase|plan|phase-plan]'
allowed-tools: Bash, Read, Glob, Grep
---

# /spec-pipeline:validate

Validate the artifact at the path given in $ARGUMENTS with the specpipe CLI:

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe validate …`

1. Determine the artifact kind — from the second argument if given, otherwise infer: a file with `## Phase <n> —` entries is a phase-plan; one with `### Task <n>:` tasks is a plan; one with a `## Cross-cutting decision register` section is a master spec; one with `## Provenance & governance` is a phase spec. If the kind is ambiguous, ask.
2. Run the matching subcommand: `validate phase-plan <path>` · `validate spec <path> --kind master` · `validate spec <path> --kind phase --master <master-path>` (locate the master via the phase-plan's `Master spec:` line or ask) · `validate plan <path>`.
3. Render the findings grouped by severity. For each error, state the concrete fix. Warnings are judgment calls — say whether each is worth acting on and why.
