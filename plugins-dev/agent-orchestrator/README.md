# Agent Orchestrator Plugin

General-purpose agent team orchestration for Claude Code. Decomposes complex tasks into parallel workstreams with automatic context management, file isolation via git worktrees, and mechanical enforcement hooks.

## Installation

From a marketplace:
```
/plugin install agent-orchestrator@<marketplace-name>
```

Or test locally:
```
claude --plugin-dir ./agent-orchestrator
```

## Usage

Run `/orchestrate` and describe your task. The orchestrator will:

1. **Triage** — skip orchestration for simple tasks
2. **Plan** — scan the codebase, decompose into workstreams, present a plan for approval
3. **Execute** — bootstrap infrastructure, spawn teammates in waves, monitor health
4. **Synthesize** — merge worktrees, run integration checks, report results

## What's Included

| Component | File | Purpose |
|-----------|------|---------|
| **Command** | `commands/orchestrate.md` | `/orchestrate` entry point — the full orchestration workflow |
| **Agent** | `agents/integration-checker.md` | Read-only + test execution agent for verifying merged outputs |
| **Agent** | `agents/conflict-resolver.md` | Scoped agent for resolving git merge conflicts |
| **Skill** | `skills/orchestration/SKILL.md` | On-demand reference for context management patterns |
| **Hooks** | `hooks/hooks.json` | Three enforcement hooks (see below) |
| **Scripts** | `scripts/` | Bootstrap, merge, cleanup — run externally, never enter context |
| **Templates** | `templates/` | Ledger and teammate protocol — copied to project, not carried by lead |

## Hooks

All hooks are registered declaratively via `hooks/hooks.json` — no runtime registration needed.

| Hook | Event | What it does |
|------|-------|-------------|
| **Compaction safety** | PreCompact | Logs event to `compaction-events.log`, reminds agent to write handoff |
| **Lead write guard** | PreToolUse (Write\|Edit\|MultiEdit) | Blocks source file writes when `ORCHESTRATOR_LEAD=1` is set. Teammates unaffected. |
| **Read counter** | PostToolUse (Read\|View) | Warns at 10 file reads, critical alert at 15. Enforces context discipline. |

## Context Management Strategy

Three-layer defense against context degradation:

1. **Structural** — disposable subagents for exploration, teammates for implementation, lead for coordination only
2. **Persistent** — handoff notes on disk survive compaction, ledger tracks all decisions
3. **Mechanical** — hooks warn on excessive reads, block unauthorized writes, log compaction events

## Key Design Decisions

- **Single-writer ledger:** Only the lead writes to `ledger.md`. Teammates write to individual status files. Prevents concurrent write corruption.
- **Session-aware hooks:** The write guard checks `ORCHESTRATOR_LEAD=1` env var, so teammates retain full write access.
- **Event-driven monitoring:** The lead processes events sequentially (teammate messages in teams mode, subagent returns in fallback mode). No polling.
- **Plan-first execution:** The user approves the plan before any infrastructure is created or code is changed.
- **Git worktrees:** Each teammate gets an isolated branch. Merge conflicts are resolved one at a time during synthesis.

## Fallback Mode

If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set, the orchestrator falls back to sequential subagent pipelines. This preserves all context management benefits but executes ~2-4x slower. Quality improvement comes from discipline and isolation, not parallelism.
