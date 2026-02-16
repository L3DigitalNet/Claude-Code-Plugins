---
name: orchestration
description: Context management and coordination patterns for multi-agent orchestration. Use when coordinating agent teams, managing context budgets, handling compaction, or debugging orchestration issues.
---

# Orchestration Patterns Reference

This skill provides reference material for agent team orchestration. It supplements the `/orchestrate` command with detailed patterns.

## Context Budget Management

### Lead Orchestrator
- Compact after every wave; always after 2+ waves
- Write handoff to `.claude/state/lead-handoff.md` BEFORE compacting
- Compact instruction: `Preserve: orchestration plan, team roster, current wave, file ownership map, all ledger entries, blocker status`
- After compaction, immediately read your handoff note

### Teammates
- Compact every 3 tasks, or after 10+ file reads (the read-counter hook will warn you)
- Write handoff to `.claude/state/<your-name>-handoff.md` BEFORE compacting
- Compact instruction: `Preserve: my tasks, file ownership, decisions from my handoff note`
- After compaction, immediately read your handoff note

### Subagents
- Disposable — no compaction needed
- Return structured results only (use the scan/integration templates)

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
BUILD: [pass | fail — one-line error]
TESTS: [X passed, Y failed, Z skipped — failing test names]
IMPORTS: [pass | list of broken import paths]
TYPES: [pass | list of type mismatches]
BLOCKERS: [none | list of blocking issues]
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

## Single-Writer Ledger Pattern

The ledger (`.claude/state/ledger.md`) is maintained exclusively by the lead orchestrator. This prevents concurrent write corruption.

- **Lead:** Writes to ledger.md. Reads teammate status files and aggregates them.
- **Teammates:** Write to their own `.claude/state/<name>-status.md`. NEVER write to ledger.md.
- **Hooks:** Write to `.claude/state/compaction-events.log`. NEVER write to ledger.md.

## Worktree Path Rules

When working in a worktree:
- All file operations must target files inside `.worktrees/<name>/`
- The `.claude/state/` directory is shared at the project root
- Access shared state via `../.claude/state/` or the absolute path
- Your FIRST action after being spawned must be `cd .worktrees/<name>/`

## Wave Execution Model

```
Wave 1 → Spawn all independent teammates in parallel
          ↓ Monitor status files for completion signals
Wave 2 → Spawn dependent teammates; include summaries from predecessor handoffs
          ↓ ...
Wave N → Final integration
```

Between waves, the lead:
1. Reads all status files and compaction events
2. Validates handoff compliance (handoff file exists for completed teammates)
3. Checks for file-ownership violations
4. Writes lead handoff and evaluates compaction need

## Health States

| State | Signal | Response |
|-------|--------|----------|
| Healthy | Status file shows `working` | No action |
| Complete | Status shows `done` | Check if next wave unblocked |
| Blocked | Status shows `blocked` | Read notes, resolve, message |
| Stalled | No status file or stale | Message → read handoff → respawn |
| Quality concern | Done but handoff suspicious | Spawn review subagent |

Max 2 retries per teammate. Then escalate to user.
