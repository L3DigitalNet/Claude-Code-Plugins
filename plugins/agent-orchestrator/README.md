# Agent Orchestrator

General-purpose agent team orchestration for Claude Code. Decomposes complex tasks into parallel workstreams with automatic context management, file isolation via git worktrees, and mechanical enforcement hooks.

## Summary

Agent Orchestrator addresses Claude Code's core limitation on complex multi-file tasks: context degradation. It spawns isolated teammate agents in separate git worktrees — each with a clean context window — and coordinates them through a shared task ledger. The lead agent handles planning and synthesis only; teammates handle all implementation work. The result is higher-quality output on tasks that would otherwise exhaust a single session's context window.

## Principles

**[P1] Triage Before Orchestration** — Never spin up a team for a task a single agent can handle. The overhead of orchestration must be earned by task complexity, not habit.

**[P2] The Lead Never Implements** — The lead orchestrator decomposes, delegates, and synthesises. It never writes or edits files directly; all implementation work is owned by teammates.

**[P3] File Ownership is Exclusive** — No two teammates ever edit the same file. Concurrent writes are prevented through structural assignment in the task ledger, not by trusting instruction alone.

**[P4] Disposable Context, Durable Artifacts** — Subagent and teammate context windows are throwaway; only their outputs matter. Large exploration tasks run in disposable context to keep the lead window clean for synthesis.

**[P5] Mechanical Enforcement Over Instruction** — Critical constraints (lead write guard, read counter, compaction safety) are enforced by hooks that fire deterministically, not by asking the lead to remember rules under pressure.

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install agent-orchestrator@l3digitalnet-plugins
```

Or test locally:
```
claude --plugin-dir ./plugins/agent-orchestrator
```

## Usage

Run `/orchestrate` and describe your task. For simple tasks (single file, clear scope), the triage gate skips orchestration and you proceed normally.

For complex tasks, the orchestrator will:

1. **Plan** — scan the codebase, decompose work into parallel workstreams, present a plan for approval
2. **Execute** — bootstrap worktree infrastructure, spawn teammates in waves, monitor health
3. **Synthesize** — merge worktrees, run integration checks, report results

## Commands

| Command | Description |
|---------|-------------|
| `/orchestrate` | Decompose and delegate a complex task to an agent team |

## Skills

| Skill | Description |
|-------|-------------|
| `orchestration` | Context management patterns, teammate protocol, and ledger format — invoked when coordinating agent teams |

## Agents

| Agent | Description |
|-------|-------------|
| `integration-checker` | Read-only + test execution agent for verifying merged teammate outputs |
| `conflict-resolver` | Scoped single-file agent for resolving git merge conflicts during synthesis |

## Hooks

All hooks register declaratively via `hooks/hooks.json` — no runtime setup needed.

| Hook | Event | What it does |
|------|-------|-------------|
| **Compaction safety** | PreCompact | Logs event to `compaction-events.log`, prompts agent to write a handoff note |
| **Lead write guard** | PreToolUse (Write\|Edit\|MultiEdit) | Blocks source file writes when `ORCHESTRATOR_LEAD=1` is set; teammates are unaffected |
| **Read counter** | PostToolUse (Read\|View) | Warns at 10 file reads, critical alert at 15 |

## Context Management Strategy

Three-layer defense against context degradation:

1. **Structural** — disposable subagents for exploration, teammates for implementation, lead for coordination only
2. **Persistent** — handoff notes on disk survive compaction, ledger tracks all decisions
3. **Mechanical** — hooks warn on excessive reads, block unauthorized writes, log compaction events

## Key Design Decisions

- **Single-writer ledger:** Only the lead writes to `ledger.md`. Teammates write to individual status files. Prevents concurrent write corruption.
- **Session-aware hooks:** The write guard checks `ORCHESTRATOR_LEAD=1` env var, so teammates retain full write access.
- **Event-driven monitoring:** The lead processes events sequentially. No polling.
- **Plan-first execution:** The user approves the plan before any infrastructure is created or code is changed.
- **Git worktrees:** Each teammate gets an isolated branch. Merge conflicts are resolved one at a time during synthesis.

## Fallback Mode

If `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` is not set, the orchestrator falls back to sequential subagent pipelines. This preserves all context management benefits but executes ~2–4× slower. Quality improvement comes from discipline and isolation, not parallelism.

## Planned Features

- **Smarter triage** — cost/complexity estimation before deciding whether to orchestrate, with configurable thresholds
- **Auto-retry for failed workstreams** — detect a stalled or crashed teammate and re-spawn with context from the ledger
- **Multi-repo support** — orchestrate work that spans more than one git repository, with per-repo worktrees
- **Richer synthesis reports** — structured diff summary per workstream with test results inline

## Known Issues

- **Fallback mode is significantly slower** — sequential subagent pipelines provide the same isolation benefits but without parallelism; complex tasks may take 2–4× longer than in teams mode
- **Worktree cleanup can fail** if a teammate process crashes mid-write and leaves a lock file; run `git worktree prune` manually if cleanup scripts report errors
- **Write guard does not cover `Bash` tool** — the lead write guard blocks `Write|Edit|MultiEdit` but teammates could still make indirect changes via shell commands; rely on code review for enforcement in these cases
- **Teams mode is experimental** — requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` and may change behavior between Claude Code versions
