---
description: Render the spec-pipeline phase plan — statuses, next pending phase, review-round counters
argument-hint: '[phase-plan-path]'
allowed-tools: Bash, Read, Glob
---

Show project phase status via the specpipe CLI:

`PYTHONPATH="${CLAUDE_PLUGIN_ROOT}/scripts/specpipe" uv run --no-project python -B -m specpipe status <path>`

Use the path from $ARGUMENTS; if omitted, default to `docs/handoff/phase-plan.md`, and if that does not exist, locate the phase-plan file per the project's handoff convention (search for a file with `## Phase <n> —` entries under the project's state/docs layout). Present the table (id → status → depends_on → title), the resolved next phase, and any round counters. If no phase resolves as next, explain why (all complete, or a dependency chain is blocked — name the blocking phase).
