# Design Assistant — Architecture & Design Decisions

This document records the architectural choices and trade-offs made in the design-assistant plugin. It is intended for contributors extending or modifying the plugin, not for end users.

## Plugin Purpose

Design Assistant provides two complementary workflows:

- `/design-draft` — structured interview that discovers and stress-tests design principles *before* architecture is committed
- `/design-review` — iterative review that enforces those principles across multiple passes until convergence

The core insight: most design documents fail not because the architecture is wrong, but because the principles behind it were never made explicit. Architecture without principles is just boxes and arrows.

## Architecture Overview

Design Assistant is a **behavioral-only plugin** — it has no agents, no templates, and minimal hooks (one context pressure counter). All functionality is implemented as AI instructions in two large command files.

This is a deliberate departure from the agent-orchestrator reference pattern, which uses structural and mechanical enforcement extensively. The reasons are documented in the decisions below.

---

## Architecture Decisions

### AD1: Behavioral-Only — No Structural Enforcement

**Decision**: No git worktrees, no file isolation, no write-guard hooks.

**Rationale**: Design Assistant is a *conversation*, not a multi-agent task. Its outputs are design documents produced through human-AI dialogue — not files modified concurrently by multiple agents. The structural enforcement patterns in agent-orchestrator (worktrees, single-writer ledger, lead write guard) solve concurrent-write problems that do not exist in a sequential interview workflow.

The only structural concern is context pressure during large-document review. That is addressed by the read-counter hook (see AD7) and the `pause/continue` mechanism.

---

### AD2: Single-Agent Workflow — No Disposable Subagents

**Decision**: All phases run in a single conversation context. No subagents are spawned.

**Rationale**: The design interview (Phases 0–4) is inherently stateful and sequential — each answer builds on the previous ones. Delegating phases to disposable subagents would require serializing and passing the full session state (`answers[]`, `candidates[]`, `tension_flags[]`, etc.) between agents, costing more context than keeping everything in one session.

The disposable-agent pattern is valuable for exploration tasks (e.g., reading many files in agent-orchestrator's plan mode). Design Assistant has no equivalent exploration task — the "content" being processed is user answers in the conversation, not files on disk.

---

### AD3: Large Command Files Are Intentional

**Decision**: `design-draft.md` (~1,500 lines) and `design-review.md` (~1,075 lines) are large inline instruction files.

**Rationale**: Template externalization reduces context cost when templates are read by *subagents that receive them as instructions*. In design-assistant, there are no subagents — the command IS the agent's instructions. Externalizing the phase protocol to template files would require Read tool calls that load the same content into the same context window, net-increasing context cost.

The commands are large because the protocols are complex (stateful phase machine with invariants, multi-mode auto-fix, convergence tracking). The size reflects intentional protocol depth, not poor organization. Meaningful reduction in size would require removing protocol features.

**Trade-off accepted**: Both commands load entirely into context on invocation. For `/design-review`, this means a fixed ~1,075-line base cost before the review loop begins. Use `pause/continue` to manage accumulated context for long sessions (see AD7).

---

### AD4: Two Commands Rather Than One

**Decision**: `/design-draft` and `/design-review` are separate commands, not one command with two modes.

**Rationale**:

- **Context isolation**: Running both protocols in one command would load ~2,500+ lines simultaneously. Separation keeps each session focused on one task.
- **Independent entry points**: Users can run `/design-review` on any existing document without going through the draft workflow. A combined command could not support cold-start review gracefully.
- **Warm handoff by choice**: When a user completes a draft and chooses option (B) "Begin /design-review immediately", the handoff is explicit and structured (the Handoff Block protocol). This is more reliable than mode-switching within a single command's growing context.

---

### AD5: Warm Handoff as Structured Text Block, Not a State File

**Decision**: The `/design-draft → /design-review` handoff is a text block emitted in the conversation context — not a serialized file written to disk.

**Rationale**:

- **No filesystem dependency**: A state file would require a Write → Read tool chain between commands. The block lives in the conversation context, where `/design-review` detects it automatically without a tool call.
- **Human-readable and editable**: The handoff block is plain text. The user can inspect it, modify it, or paste it into a new session manually.
- **Idempotent**: If `/design-review` runs in the same conversation where `/design-draft` ran, the handoff is seamless. If the user starts a fresh session, the block can be pasted to restore warm context.

**Trade-off**: The handoff block is verbose (~60–80 lines). This is acceptable — it is emitted once per draft→review transition and is the full authoritative state transfer.

---

### AD6: Phase Gate State Machine with Invariants

**Decision**: Session state is maintained as typed variables with explicit invariants that are verified before each phase transition.

**Rationale**: Complex multi-phase workflows degrade in AI sessions because state drift is difficult to detect mid-conversation. Explicit invariants (8 in `/design-draft`, 9 in `/design-review`) define what "valid state" means at each gate and give the AI a concrete checklist to verify before advancing.

Without invariants, an AI might advance from Phase 2A to Phase 2B before all candidates have verdicts, silently skipping the stress-test gate. The invariants are behavioral (instructions), not mechanical, because phase gate violations are conversation-level events — no hook can detect them.

---

### AD7: Context Pressure — Read Counter Hook + Pause/Continue

**Decision**: Context pressure during large-document review is managed via:
1. A PostToolUse `Read` hook (`scripts/read-counter.sh`) that warns at read count thresholds
2. The built-in `context_health` state (GREEN/YELLOW/RED) in `/design-review` for per-pass tracking
3. The `pause/continue` mechanism as the primary user-facing mitigation

**Rationale**: Large documents (500+ lines) plus review loop state machine create significant context growth during `/design-review`. The `context_health` state provides end-of-pass warnings. The read-counter hook provides additional per-operation mechanical warnings earlier — at 10 reads (notice) and 20 reads (strong warning) — before the end of a pass.

This is the only mechanical enforcement in the plugin. The hook mirrors the read-counter pattern from agent-orchestrator.

**Hook thresholds**:
- 10 reads → gentle notice (context growing, consider pausing soon)
- 20 reads → strong warning (pause before next pass recommended)

**Known limitation**: `pause/continue` state is session-local. Snapshots are held in conversation context; pasting them into a new session is the only supported cross-session resumption path.

---

## Context Cost Analysis

| Component | Approximate size | When loaded |
|-----------|-----------------|-------------|
| `/design-draft` command | ~1,500 lines | On `/design-draft` invocation |
| `/design-review` command | ~1,075 lines | On `/design-review` invocation |
| `design-draft` skill | 24 lines | When AI deems relevant |
| `design-review` skill | 19 lines | When AI deems relevant |
| Read counter hook script | Never (external) | PostToolUse on Read; only stdout returned |

**For a complete draft → review session**:
- `/design-draft` loads → generates draft → hands off → `/design-review` loads
- Context at review entry: ~1,500 (draft protocol) + draft content + ~1,075 (review protocol) ≈ 3,500+ lines before Pass 1 begins
- For documents over ~300 lines: consider using `finalize` in `/design-draft`, saving the draft, then starting a fresh `/design-review` session on the saved file.

---

## Future Considerations

The following patterns are *not* currently implemented but would be natural extensions if the plugin grows:

- **Domain-specific principle templates**: Starter principle registries for common domains (SaaS APIs, IoT firmware) would be natural Template files — short markdown read by the interview phase. This is the one area where template externalization would provide genuine value.
- **Cross-document consistency**: A second `/design-review` variant that takes two document paths would require a subagent for one document. This is the first scenario that would call for the disposable-agent pattern.
- **Persistent principles library**: Cross-session principle storage would require a state file pattern — the one case where the text-block handoff (AD5) is insufficient.
