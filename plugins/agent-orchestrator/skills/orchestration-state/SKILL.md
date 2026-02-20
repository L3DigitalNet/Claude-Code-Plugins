---
name: orchestration-state
description: Shared state rules for multi-agent orchestration — ledger ownership, worktree file paths, and structured return templates. Use when writing to the ledger, navigating worktree paths, or formatting scan results and status reports.
---

# Orchestration — Shared State and Templates

## Single-Writer Ledger Pattern

The ledger (`.claude/state/ledger.md`) is maintained exclusively by the lead orchestrator. This prevents concurrent write corruption.

- **Lead:** Writes to ledger.md. Reads teammate status files and aggregates them.
- **Teammates:** Write to their own `.claude/state/<name>-status.md`. NEVER write to ledger.md.
- **Hooks:** Write to `.claude/state/compaction-events.log`. NEVER write to ledger.md.

## Worktree Path Rules

When working in a worktree:
- All file operations must target files inside `.worktrees/<name>/`
- The `.claude/state/` directory is shared at the project root
- Access shared state via `../../.claude/state/` (two levels up from worktree) or the absolute path
- Your FIRST action after being spawned must be `cd .worktrees/<name>/`

## Structured Return Templates

### Scan Results
```
SCAN RESULTS — [area investigated]
Relevant paths: [comma-separated file paths, no contents]
Key findings: [≤3 bullet points, one sentence each]
Risks/blockers: [≤2 bullet points, or "none"]
```

### Integration Check
```
BUILD:    ✓ pass | ✗ fail — <one-line error>
TESTS:    ✓ X passed, Y failed, Z skipped — <failing test names>
IMPORTS:  ✓ pass | ✗ <broken import paths>
TYPES:    ✓ pass | ✗ <type mismatches>
BLOCKERS: ✓ none | ✗ <blocking issues>
```

### Teammate Status File
```
## Status: working | blocked | done
## Context Pressure: low | mid | high
## Files Modified:
- path/to/file.ext (brief description)
## Current Task: <what you are working on now>
## Notes: <anything the lead or other teammates should know>
```
