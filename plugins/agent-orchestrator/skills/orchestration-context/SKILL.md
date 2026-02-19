---
name: orchestration-context
description: Compaction and handoff rules for multi-agent orchestration. Use when a lead orchestrator or teammate needs to manage context pressure, compact their context window, or write a handoff note before compacting.
---

# Orchestration — Context Budget Management

## Lead Orchestrator

- Compact after every wave; always after 2+ waves
- Write handoff to `.claude/state/lead-handoff.md` BEFORE compacting
- Compact instruction: `Preserve: orchestration plan, team roster, current wave, file ownership map, all ledger entries, blocker status`
- After compaction, immediately read your handoff note

## Teammates

- Compact every 3 tasks, or after 10+ file reads (the read-counter hook will warn you)
- Write handoff to `.claude/state/<your-name>-handoff.md` BEFORE compacting
- Compact instruction: `Preserve: my tasks, file ownership, decisions from my handoff note`
- After compaction, immediately read your handoff note

## Subagents

- Disposable — no compaction needed
- Return structured results only (use the scan/integration templates in `orchestration-state`)
