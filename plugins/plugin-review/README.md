# Plugin Review

Comprehensive review of Claude Code plugins covering principles alignment, terminal UX quality, and documentation freshness. Uses an orchestrator–subagent architecture to manage context budget across multi-pass review sessions.

## Summary

Plugin Review addresses the challenge of systematically auditing a Claude Code plugin against its own stated principles, terminal UX best practices, and documentation accuracy — all without exhausting the context window. The orchestrator manages the convergence loop (setup → analyze → report → propose → implement → re-audit) while delegating deep file reading and analysis to three focused subagents with disposable context. The result is thorough multi-pass reviews that converge within a 3-pass budget.

## Principles

**[P1] Orchestrator Leanness** — The orchestrator holds only structural metadata (principles checklist, touchpoint map, convergence table, user decisions) — never raw source file contents. All deep file reading is delegated to subagents.

**[P2] Disposable Analysis** — Each analysis track runs in its own subagent whose context is discarded after it returns a structured summary. This is the primary mechanism for managing token budget across multi-pass reviews.

**[P3] On-Demand Template Loading** — Analysis criteria, report formats, and impact-check templates are externalized files loaded only by the component that needs them. The orchestrator never loads track-specific criteria into its own context.

**[P4] Scoped Re-audit** — Pass 2+ never re-runs the full three-track analysis. Only tracks affected by files changed in the previous pass are re-analyzed. Unchanged findings carry forward without re-analysis.

**[P5] Pass Budget Enforcement** — The review targets convergence within 3 passes. Exceeding this budget requires an explicit user decision — the orchestrator does not silently continue looping.

**[P6] Documentation Co-mutation** — Every implementation change must include corresponding documentation updates in the same pass. The `doc-write-tracker` hook mechanically warns when implementation files are modified without any documentation updates in the session — catching the most common failure mode (forgetting to update docs entirely). Full blocking enforcement of this rule requires a manual pre-completion check.

**[P7] Cross-Track Impact Awareness** — Before implementation, each proposed change must note which other tracks it could affect. This catches regressions before they happen rather than discovering them on re-audit.

**[P8] Severity-Led Reporting** — Reports lead with open findings sorted by severity. Upheld principles and clean touchpoints are summarized in a compact roll-up line, not given individual detail blocks.

**[P9] Subagents Analyze, Orchestrator Acts** — Subagents only read files and return structured analysis. All code changes, file modifications, and user interactions are handled by the orchestrator directly.

## Checkpoints

Checkpoints are cross-cutting quality checks applied during review. Unlike principles (which govern this plugin's own architecture), checkpoints evaluate qualities of the *target* plugin being reviewed.

**[C1] LLM-Optimized Commenting** — Code comments should be written for the AI sessions that will read, modify, and review this code — not for a human scanning line by line. Comments that restate syntax waste tokens. Comments that explain intent, constraints, decision history, and cross-file relationships prevent regressions.

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install plugin-review@l3digitalnet-plugins
```

Or test locally:
```
claude --plugin-dir ./plugins/plugin-review
```

## Usage

Run `/review` and name the plugin to audit (or pick from a list). The orchestrator will triage-read structural files, build a principles checklist and touchpoint map, then spawn analyst subagents for deep review.

During a review session, these commands are available:

| Command | Description |
|---------|-------------|
| `skip [Pn]` or `skip [finding]` | Accept a finding as out-of-scope |
| `focus on [Pn\|UX\|principles\|docs]` | Prioritize a specific area next pass |
| `light pass` | Run only tracks affected by recent changes |
| `revert last pass` | Undo the last batch of changes |
| `stop` or `looks good` | End the review and print the final summary |

## Commands

| Command | Description |
|---------|-------------|
| `/review` | Launch a multi-pass plugin review with orchestrator–subagent analysis |

## Skills

| Skill | Description |
|-------|-------------|
| `scoped-reaudit` | Determines which analysis tracks to re-run based on files changed in the previous pass |

## Agents

| Agent | Description |
|-------|-------------|
| `principles-analyst` | Track A — reads implementation files, returns per-principle status table and root architectural alignment |
| `ux-analyst` | Track B — reads user-facing code paths, returns severity-grouped UX findings |
| `docs-analyst` | Track C — reads documentation against implementation listing, returns per-file freshness assessment |

## Hooks

All hooks register declaratively via `hooks/hooks.json` — no runtime setup needed.

| Hook | Event | What it does |
|------|-------|-------------|
| **Doc write tracker** | PostToolUse (Write\|Edit\|MultiEdit\|NotebookEdit\|MCP writes) | Tracks which file categories (impl vs. doc) are being written during a review session; warns when implementation files are modified without any documentation files in the same pass |
| **Agent frontmatter validator** | PostToolUse (Write\|Edit\|MultiEdit) | Checks agent definition files for disallowed tools (Write, Edit, Bash, etc.) after each write; warns if tools beyond the read-only allowlist are present in the YAML frontmatter |

## Context Management Strategy

Three-layer defense against context degradation:

1. **Structural** — disposable subagents for deep analysis, externalized templates for criteria and report formats, orchestrator holds only compact summaries
2. **Persistent** — convergence table, findings summaries, and user decisions survive across passes as compact structured data
3. **Mechanical** — PostToolUse hook tracks write patterns and warns on documentation co-mutation failures

## Key Design Decisions

See [docs/DESIGN.md](docs/DESIGN.md) for full architectural rationale.

- **Orchestrator + subagent split:** The orchestrator never reads full plugin source files. Three focused subagents each load only the files and criteria for their track, then return compact summaries.
- **3-pass budget:** Reviews that haven't converged by Pass 3 usually have findings that represent accepted trade-offs. The budget is a structural checkpoint, not a hard wall.
- **Scoped re-audit:** Pass 2+ only spawns subagents for tracks affected by changed files. The Docs track always runs since any change can introduce documentation drift.
- **Cross-track impact annotation:** Proposals are annotated with affected tracks before implementation, catching regressions at proposal time rather than on re-audit.
- **Severity-led reporting:** Pass 1 reports roll up clean items into a single line. Only open findings get full detail blocks.
