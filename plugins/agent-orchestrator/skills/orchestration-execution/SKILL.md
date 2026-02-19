---
name: orchestration-execution
description: Wave-based parallel execution and teammate health monitoring for multi-agent orchestration. Use when coordinating agent waves, spawning teammates, checking health states, or a teammate appears stalled or blocked.
---

# Orchestration — Wave Execution and Health Monitoring

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
