# Agent Orchestrator — Design Document

This document captures the design decisions, rationale, and iterative thought process behind the Agent Orchestrator plugin for Claude Code. It is intended to serve as institutional knowledge for continued development.

---

## Origin and Motivation

The project started from a single observation: Claude Code sessions degrade on complex, multi-file tasks. When a session reads too many files, makes too many edits, or runs too long, context fills up. Auto-compaction fires and nuance is lost. Later files get worse treatment than earlier ones. The user ends up with 70-80% of the work done correctly and spends time on manual fixups.

The original request was: "Design a prompt that I will use in Claude Code. It should use agent teams for the given task(s). Each agent is a coordinator of their own subagents. Context management is key and the agents should strategize to avoid compaction."

Three constraints shaped everything that followed: context management as the primary design goal, parallel execution as a secondary speed benefit, and a general-purpose system not tied to any specific project.

---

## Research Phase

Before writing any prompt, we researched Claude Code's capabilities to understand what was mechanically possible versus what required behavioral instructions.

Key findings that shaped the architecture:

**Agent teams vs. subagents.** Agent teams allow inter-agent communication — teammates can message each other directly. Subagents can only report back to their parent. This distinction drove the dual-mode design: agent teams when available, sequential subagent pipelines as fallback.

**Plan mode.** Claude Code has a built-in `/plan` command that uses an internal Plan subagent for exploration. This subagent operates in its own context window, keeping the parent's context clean. This became the basis for Phase 1 reconnaissance — exploration happens in disposable context.

**Hooks system.** Claude Code supports event hooks (PreToolUse, PostToolUse, PreCompact, etc.) that run external shell scripts. Hook output is injected into the agent's context as text. Hooks can block tool use by returning a specific JSON structure with `"decision": "block"`. This became the basis for mechanical enforcement.

**Git worktrees.** Git supports multiple working trees from a single repository. Each worktree gets its own branch and working directory. This provides structural file isolation — teammates literally cannot edit each other's files because they're in different directories on different branches.

**Tool restrictions.** Agent definitions support a `tools` frontmatter field that limits available tools. However, we discovered (GitHub issue #4740) that tool restrictions on subagents may not always be enforced reliably. This pushed us toward hooks as the primary enforcement mechanism.

---

## Core Architecture

### The Three-Phase Lifecycle

The system follows a strict lifecycle: Plan → Execute → Synthesize. This isn't just organizational — it maps to different context management strategies at each phase.

**Phase 0 (Triage)** exists because orchestration has real overhead. For a single-file bug fix, the bootstrapping time and token cost of the orchestration machinery would exceed the cost of just doing the work directly. The triage gate uses four criteria (file count, cross-cutting concerns, sequential nature, describability) to prevent over-engineering. This was added as recommendation #6 during the first refinement pass — the original prompt had no escape hatch for simple tasks.

**Phase 1 (Reconnaissance & Planning)** runs entirely in `/plan` mode. This was a deliberate choice. Early versions tried to spawn parallel research subagents for codebase scanning, but plan mode and custom subagent spawning are different mechanisms that conflict — you can't spawn custom subagents while `/plan` is active. The fix (weakness #1) was to commit fully to plan mode: let the built-in Plan subagent do exploration, use the structured scan template as guidance for what it should produce, and exit plan mode only when moving to execution. The plan is presented to the user for approval before any infrastructure is created.

**Phase 2 (Execution)** is where the orchestration machinery runs. The lead spawns teammates (or subagents in fallback mode), monitors progress at event-driven checkpoints, manages the ledger, and resolves blockers. The lead never implements directly — this is enforced mechanically by a PreToolUse hook that blocks Write/Edit/MultiEdit on source files.

**Phase 3 (Synthesis)** merges worktree branches, runs integration checks via a dedicated read-only agent, and iterates through a quality gate (max 3 cycles) before reporting to the user. The quality gate serves double duty: it catches code errors AND process failures (e.g., a teammate that ignored protocol and produced incomplete work).

### The Delegation Model

The system uses a hybrid delegation model: the lead orchestrates teammates, and each teammate coordinates its own subagents. This was an explicit design choice (selected during initial design) over alternatives like flat delegation (lead manages everything) or pure hierarchy (no subagent nesting).

The rationale: flat delegation overloads the lead's context. Pure hierarchy adds coordination latency. The hybrid model gives each teammate autonomy over its implementation approach while the lead focuses purely on coordination. Teammates decide when to spawn exploration subagents, test-runner subagents, or convention-checking subagents within their own scope.

### Context Management Strategy

This is the system's raison d'être. Three layers of defense:

**Structural isolation.** Subagents are disposable — they explore, return structured results, and their context is discarded. Teammates work in focused scopes (3-6 tasks, explicit file ownership). The lead carries only coordination state. Git worktrees provide physical file isolation. This prevents context contamination across workstreams.

**Persistent state on disk.** Every agent writes handoff notes to `.claude/state/` before compacting. The ledger tracks all decisions in an append-only log. Status files give the lead visibility into each teammate's progress. These files survive compaction — when an agent compacts and loses context, it reads its handoff note to restore continuity. This was the key insight: context is ephemeral, but disk is persistent.

**Heuristic-based compaction triggers.** Rather than waiting for auto-compaction to fire unexpectedly, agents proactively compact based on activity heuristics: teammates compact every 3 tasks or after 10+ file reads; the lead compacts after every wave or when `/context` shows >40% usage. The PostToolUse hook on Read/View operations tracks file reads per session and injects warnings at 10 and 15 reads. These heuristics were chosen because percentage-based triggers (like "compact at 60%") are unreliable — `/context` may not always be available, and the relationship between file reads and context consumption isn't linear.

### The Single-Writer Ledger Pattern

The ledger (`ledger.md`) is maintained exclusively by the lead. Teammates write to their own status files. Hooks write to their own log files. The lead reads all these sources and aggregates them into the ledger during between-wave checks.

This pattern emerged from fixing weakness #4 (PreCompact hook concurrent write hazard). The original design had the PreCompact hook appending directly to `ledger.md`, creating a race condition with the lead's writes. The fix was to give the hook its own file (`compaction-events.log`) and have the lead incorporate those events during its aggregation pass. This generalized into a rule: one writer per file, the lead aggregates.

### Event-Driven Monitoring

The lead cannot poll. It processes events sequentially — it doesn't have a timer or event loop. This was weakness #6 in the review.

In agent teams mode, monitoring happens when the lead receives a teammate message. Each incoming message is a checkpoint: the lead reads all status files, assesses teammate states, takes action if needed, and returns to waiting.

In subagent fallback mode, monitoring happens when each subagent returns. The lead reads the output, updates the ledger, checks if the next subagent is unblocked, and dispatches it.

The "periodically check" language from the original prompt was removed because it implied active polling that the lead cannot perform.

---

## Iterative Refinement History

The prompt went through three major refinement passes before plugin conversion.

### Pass 1: Initial Recommendations (7 items)

After the first draft, we identified seven improvements. The most impactful were:

**Triage gate (recommendation #6).** Without this, every task — including trivial ones — would trigger the full orchestration machinery. The gate uses four criteria to filter out tasks that don't need orchestration.

**Plan mode for reconnaissance (recommendation #5).** Running Phase 1 in `/plan` mode saves tokens because the Plan subagent operates in its own context window.

**Delegate mode enforcement (recommendation #3).** The original prompt told the lead to delegate, but Claude Code agents frequently break role constraints when they see something they could "quickly fix." This needed mechanical enforcement, not just instructions.

**Git worktrees (recommendation #4).** File-ownership instructions are behavioral — teammates can still accidentally cross boundaries. Worktrees make file conflicts structurally impossible.

**Subagent fallback (recommendation #2).** The original prompt assumed agent teams were available. Many users won't have the experimental flag enabled. The fallback mode provides the same context management benefits without parallelism.

**PreCompact hooks (recommendation #7).** Rather than relying on agents to remember to write handoff notes before compaction, hooks fire automatically and inject reminders into the agent's context.

**Prompt context reduction (recommendation #1).** The prompt itself consumes context. Splitting content into files on disk (templates, protocols) that agents read independently keeps the lead's context lean.

### Pass 2: Critical Review (9 weaknesses)

After implementing all recommendations, we did a fresh review asking: "Does it make sense? Will it actually work? What's the expected output quality?"

The review identified 9 weaknesses. These are documented here in the order they were fixed, which was chosen to minimize cascading conflicts between fixes:

**#4 — Hook concurrent write hazard.** The PreCompact hook appended to `ledger.md` while the lead might be mid-write. Fixed by giving the hook its own file (`compaction-events.log`) and having the lead read it during aggregation.

**#1 — Plan mode + subagent spawning tension.** Plan mode and "spawn parallel research subagents" were conflicting instructions. Fixed by committing fully to plan mode for Phase 1.1 and using the scan template as guidance rather than dispatch instructions.

**#5 — Delegate mode enforcement.** The original approach was to define the lead as a subagent with tool restrictions, but subagents can't spawn other subagents (or teammates). The fix was a PreToolUse hook that blocks Write/Edit/MultiEdit when `ORCHESTRATOR_LEAD=1` is set. This is session-aware — the env var is set only in the lead's session, so teammates retain full write access. Three layers: mechanical (hook), behavioral (Shift+Tab delegate mode toggle), and instructional (self-reinforcing prompt text).

**#6 — Event-driven monitoring.** "Periodically check" was reframed as event-driven checkpoints. In agent teams mode: checkpoints on teammate messages. In subagent fallback: checkpoints on subagent returns.

**#2 — Bootstrap script collapse.** Phase 2.1 had ~150 lines of bash heredocs (ledger, protocol, hooks, registration) consuming lead context. Collapsed into a single bash execution block. One write, one run. Context footprint cut significantly.

**#3 — Worktree path confusion.** Teammates might use root-relative paths instead of worktree paths. Fixed by mandating `cd .worktrees/<n>/` as the FIRST action in the spawn template and stating all ownership paths as relative to the worktree root.

**#7 — Context discipline enforcement.** All context management was advisory. Added a PostToolUse hook (`read-counter.sh`) that tracks file reads per session, warns at 10, critical alert at 15. Added between-waves handoff validation: the lead checks for handoff file existence when a teammate reports `done`. Missing handoffs are flagged for extra scrutiny.

**#8 — Fallback transparency.** The subagent fallback description didn't quantify the tradeoff. Added explicit statement: "Expect ~2-4x slower wall-clock time. Quality improvement comes from discipline and context isolation, not parallelism."

**#9 — Confidence level in plan.** The prompt implied infallibility. Added a "Guardrails" section to the plan output that distinguishes mechanical enforcement (hooks) from behavioral enforcement (protocol + prompts) and explicitly notes that "hooks reduce but do not eliminate the risk of protocol violations."

### Pass 3: Plugin Conversion

After all fixes, the prompt was 580 lines. The question was: "This is getting complex. Would it make more sense to have this installable as a Claude Code plugin?"

The answer was unambiguously yes, because nearly every component mapped directly to a plugin primitive:

The 580-line pasted prompt became a `/orchestrate` slash command that loads on demand. The three inline heredocs for hook scripts became external shell scripts registered declaratively in `hooks/hooks.json` — they never enter the context window. The teammate protocol heredoc became a template file that `bootstrap.sh` copies to disk — the lead never carries it. The ledger template got the same treatment. Hook registration (previously a Python one-liner that modified `settings.local.json` at runtime) became declarative JSON that auto-registers on plugin install. The integration checker instructions became a proper agent definition with mechanical tool restrictions via YAML frontmatter. Merge and cleanup scripts moved to external files — only their stdout returns to context.

The net context improvement: the lead's footprint dropped from ~3000 words (the full prompt loaded at session start) to ~2000 words (the command, loaded on invocation) plus near-zero for scripts, templates, and hooks that run externally.

---

## Enforcement Philosophy

A central theme of this project is the gap between behavioral instructions and mechanical enforcement. Every "NEVER" and "ONLY" in a prompt is a request, not a guarantee. Claude Code agents generally follow instructions well, but "generally" isn't "always" — especially in long sessions where earlier instructions get pushed further from the active context.

The system uses three enforcement layers, in decreasing order of reliability:

1. **Mechanical (hooks).** PreToolUse blocks writes. PostToolUse counts reads. PreCompact injects reminders. These fire deterministically regardless of what the agent "thinks" it should do.

2. **Structural (git worktrees, single-writer pattern).** Teammates physically cannot edit each other's files because they're in different directories. The ledger has one writer because no one else has the path convention to write to it. These constraints are architectural, not instructional.

3. **Behavioral (protocol files, self-reinforcing prompt text).** The teammate protocol, the delegate mode declaration, the anti-patterns list. These shape behavior when mechanical enforcement isn't possible. They're the weakest layer but cover the widest surface area.

The quality gate in Phase 3 is the final safety net. It catches both code errors and process failures. If a teammate ignored protocol and produced bad work, the integration check surfaces it.

The design document's "Guardrails" section in the plan output communicates this layered approach to the user, setting proper expectations rather than implying infallibility.

---

## Known Limitations and Open Questions

### System Requirements

**Hook scripts require:**
- GNU coreutils (`realpath` command) — standard on Linux systems
- Python 3 (for JSON parsing in hooks)
- Bash 4.0+ (for pattern matching features)

If `realpath` is unavailable, the lead-write-guard hook fails open (allows all writes) rather than blocking legitimate work. This is acceptable for a development workflow tool — a rare edge case where system dependencies are missing is less disruptive than enforcing writes when the canonical path check cannot run.

### Unresolved

**Agent teams is experimental.** The `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` flag may change behavior, gain new features, or be deprecated. The fallback mode exists to handle this, but the agent teams path is the primary design target.

**Tool restriction reliability.** GitHub issue #4740 reported that tool restrictions on subagents may not always be enforced. We use hooks as the primary enforcement mechanism for this reason, but if tool restrictions become reliable, the agent definitions (`integration-checker.md`, `conflict-resolver.md`) gain real mechanical weight.

**Worktree interaction with CLAUDE.md and MCP servers.** Teammates in worktrees inherit the project's `CLAUDE.md` and MCP server configuration, which may contain root-relative paths. If a teammate's MCP server or CLAUDE.md instruction references a file by root-relative path, it will resolve against the worktree directory, which may or may not contain the expected file. This hasn't been tested.

**Hook input schema stability.** The `lead-write-guard.sh` hook parses JSON from stdin to extract `tool_input.file_path`. This schema is undocumented and may change between Claude Code versions. If the JSON structure changes, the hook fails open (allows the write) rather than crashing, which is the correct failure mode but means enforcement silently degrades.

**PreCompact hook timing.** The hook fires before compaction, giving the agent a chance to write a handoff note. But if the agent's context is already at 100% when PreCompact fires, there may not be enough room to execute the handoff write before compaction proceeds. The hook reminder is best-effort, not guaranteed.

**Read counter keyed by parent PID.** The `read-counter.sh` hook uses `$PPID` (parent process ID) as the session key. Each hook invocation runs in a new bash subprocess, so `$$` would create a new counter file every time. Using `$PPID` ensures all hook invocations within the same parent session share the same counter file. If Claude Code reuses parent PIDs across sessions or if the parent PID doesn't map 1:1 to agent sessions, the counter may be inaccurate. This is a pragmatic approximation, not a precise per-session tracker.

### Tested and Validated

**Plan mode for reconnaissance.** `/plan` mode uses the built-in Plan subagent in its own context window. This is documented behavior and the foundation of Phase 1.

**PreToolUse hook blocking.** Returning `{"hookSpecificOutput":{"hookEventName":"PreToolUse","decision":"block","reason":"..."}}` with exit code 2 blocks the tool invocation. This is documented in the hooks reference.

**Git worktree creation and merging.** Standard git operations. The `merge-branches.sh` script handles one branch at a time and stops on conflict, which is the correct approach for agent-assisted conflict resolution.

**PostToolUse hook context injection.** Hook stdout is injected into the agent's context. The read-counter warnings ("You have read 10 files...") will appear in the agent's context window.

---

## Quality Expectations

Realistic assessment of expected output quality for tasks that pass the triage gate (multi-module, cross-cutting, 5+ files):

**With agent teams (~85-90% first-pass correctness).** Planning adds 5-10 minutes upfront. Teammates work in parallel with focused contexts. Context quality stays higher per-agent because each owns a narrow scope. Integration check catches cross-cutting issues. Audit trail provides visibility. Slower to start, but parallel execution and higher first-pass quality save time overall.

**With subagent fallback (~80-85% first-pass correctness).** Same planning and scaffolding overhead, but sequential execution. Essentially a well-structured single-session workflow with better context management. Better than an unstructured session because of discipline around file reads and compaction, but without the parallelism benefit. Slower than both other approaches because of overhead without parallel payoff.

**Unstructured single session (~70-80% first-pass correctness).** Context fills up around 60-70% through the task. Quality degrades on later files. Auto-compaction loses nuance. Last 20-30% requires manual fixups. Faster to start, slower overall due to rework.

The honest bottom line: the quality gain comes from discipline — scoped file ownership, structured returns, handoff persistence, forced planning — not from parallelism. Parallelism is a speed bonus when available.

---

## Plugin File Map

```
agent-orchestrator/
├── .claude-plugin/
│   └── plugin.json              # Manifest (name, description, version)
├── commands/
│   └── orchestrate.md           # /orchestrate entry point — full workflow
├── agents/
│   ├── integration-checker.md   # Read-only + Bash agent for Phase 3.2
│   └── conflict-resolver.md     # Scoped agent for merge conflict resolution
├── skills/
│   └── orchestration/
│       └── SKILL.md             # On-demand reference for context patterns
├── hooks/
│   └── hooks.json               # Declarative hook registration (3 hooks)
├── scripts/
│   ├── bootstrap.sh             # Creates .claude/state/, copies templates
│   ├── on-pre-compact.sh        # Logs compaction event, injects reminder
│   ├── lead-write-guard.sh      # Blocks lead source file writes (session-aware)
│   ├── read-counter.sh          # Tracks reads, warns at 10/15
│   ├── merge-branches.sh        # Merges worktree branches one at a time
│   ├── cleanup-worktrees.sh     # Removes worktrees and orchestrator branches
│   └── cleanup-state.sh         # Removes .claude/state/ and gitignore entries
├── templates/
│   ├── ledger.md                # Ledger template (copied by bootstrap)
│   └── teammate-protocol.md     # Full teammate operating protocol
├── README.md                    # User-facing documentation
└── DESIGN.md                    # This file
```

**Context cost of each component:**

| Component | Enters lead context? | When? |
|-----------|---------------------|-------|
| `orchestrate.md` | Yes | On `/orchestrate` invocation |
| `integration-checker.md` | No | Loaded by the integration checker agent itself |
| `conflict-resolver.md` | No | Loaded by the conflict resolver agent itself |
| `SKILL.md` | Conditionally | Only if Claude determines it's relevant to current task |
| `hooks.json` | No | Processed by Claude Code at plugin install |
| All `scripts/*.sh` | No (stdout only) | Scripts run externally; only their printed output returns |
| `templates/*.md` | No | Copied to disk by bootstrap; teammates read them, lead doesn't |

---

## Future Work

**Testing framework.** The plugin has no automated tests. A test harness that simulates an orchestration run (triage → plan → bootstrap → spawn → merge → verify) against a sample repository would catch regressions in the prompt, scripts, and hooks.

**Adaptive context heuristics.** The "every 3 tasks / 10 file reads" triggers are fixed values. Tracking actual context consumption per session and adjusting thresholds based on observed patterns would be more robust. This could be a PostToolUse hook that estimates token counts.

**Metrics collection.** Tracking orchestration outcomes (time, token cost, first-pass correctness, number of quality gate cycles) across runs would provide data to tune the system. A lightweight log in `.claude/state/metrics.json` could capture this.

**Plugin marketplace distribution.** The plugin is currently a local directory. Publishing to a marketplace would make it installable via `/plugin install agent-orchestrator@<marketplace>`.

**SessionStart hook for auto-setup.** A SessionStart hook could detect when a user invokes `/orchestrate` and automatically set `ORCHESTRATOR_LEAD=1` without requiring the manual export. This would tighten the enforcement chain.

**Teammate agent definitions.** Currently, teammates are spawned with inline prompt text. Defining teammate templates as agent files (with tool restrictions in frontmatter) would add mechanical enforcement to their behavior too — not just the lead's.

**PreCompact hook: force handoff write.** The current hook only injects a reminder. A more aggressive version could attempt to write a minimal handoff (current task list, modified files) automatically by reading the agent's status file. This is speculative — it depends on whether the hook has enough information to construct a useful handoff.
