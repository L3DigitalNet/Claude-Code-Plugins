# Design: Plugin Review

## Problem

Reviewing a Claude Code plugin requires reading its full source, comparing against multiple sets of principles and UX criteria, producing structured reports, making changes, and re-reading to verify — potentially across multiple passes. In a monolithic prompt, the agent holds every source file, all analysis criteria, all report templates, and cumulative findings state simultaneously. For a non-trivial plugin with 15–20 files, context exhaustion becomes the practical limit on review depth, often before convergence is reached.

## Core Architectural Decision: Orchestrator + Subagents

The plugin splits work into an orchestrator (the `review` command) and three disposable analyst subagents (principles, UX, docs). This mirrors the "disposable context" pattern from the root architectural principles, applied to the review process itself.

**Why this works for token budget:** Each analyst subagent loads the source files it needs, performs deep analysis, and returns a compact structured summary (typically 20–50 lines). When the subagent completes, its full file contents are discarded from context. The orchestrator only ever holds the summaries, not the source. Across a 3-pass review, the orchestrator's context grows by ~100–150 lines of findings data rather than by 3× the full plugin source.

**Why three subagents, not one:** Each track requires different files and different evaluation criteria. A single "analyst" subagent would need to load all source files plus all three criteria sets — defeating the purpose of the split. Three focused subagents each load only what they need.

**Why subagents analyze but don't implement:** Implementation changes require cross-track awareness (a UX fix might introduce doc drift). The orchestrator has the full findings state from all three tracks, making it the right place to coordinate changes. Subagents see only their own track.

## Enforcement Layer Mapping

| Constraint | Layer | Mechanism |
|-----------|-------|-----------|
| Doc co-mutation (forgot to update) | Mechanical (warn-only) | `doc-write-tracker` PostToolUse hook tracks impl-vs-doc writes, warns on imbalance — does not block |
| Doc co-mutation (content accuracy) | Behavioral | Orchestrator verifies doc content matches new behavior — can't be mechanically checked |
| Pass budget (3-pass limit) | Structural | Orchestrator command explicitly checks pass count before spawning next round |
| Scoped re-audit | Structural | `scoped-reaudit` skill encodes file→track mapping; orchestrator consults it before spawning |
| Subagents don't implement | Structural + Mechanical (warn) | Agent YAML frontmatter `tools:` line restricts to `Read, Grep, Glob` — no Write/Edit access. PostToolUse hook `validate-agent-frontmatter.sh` warns if disallowed tools are added to agent files. |
| Report format consistency | Structural | Report templates are externalized; agents are instructed to follow them exactly |
| Severity-led reporting | Behavioral | Instruction in report template to lead with open findings, roll up clean items |
| Cross-track impact check | Behavioral | Instruction in orchestrator to annotate proposals with affected tracks |

**Accepted behavioral-only constraints:** Some rules are inherently judgment calls (UX criteria like "no walls of text", cross-track impact assessment, convergence quality detection). Attempting mechanical enforcement of aesthetic or analytical judgment would be brittle. These are appropriate for behavioral enforcement.

## Checkpoints vs. Principles

Principles ([P1]–[P9]) govern this plugin's own internal architecture — how the review tool is built and operates. Checkpoints ([C1]–[Cn]) are cross-cutting quality standards applied to the *target* plugin being reviewed. The distinction matters because principles are self-referential (the review plugin should satisfy its own principles), while checkpoints are outward-facing evaluation criteria.

Checkpoints live in Track A (Principles Analyst) because that agent already deep-reads every implementation file in the target plugin and is best positioned to evaluate code-level qualities like commenting patterns. Checkpoint status uses its own scale rather than the Upheld/Partially Upheld/Violated framework, since checkpoints measure quality on a spectrum rather than binary enforcement compliance.

### [C1] LLM-Optimized Commenting

The motivation is workflow-specific: in a Claude Code development workflow, the human acts as an architecture-level manager while the AI reads and writes code line by line. The actual consumer of in-code comments is the next AI session loading those files into its context window. Comments should be tuned for that reader.

An LLM already understands syntax, can parse control flow, and can infer what a function does from its name and body. What it cannot infer is intent, constraints, decision history, and cross-file relationships. Comments that restate code mechanics waste context tokens and provide no value. Comments that explain architectural role, non-obvious constraints, and cross-file contracts are the highest-value investments because they prevent the most common class of AI-introduced regressions — changes made without understanding context that wasn't visible in the code itself.

## Template Externalization Rationale

The analysis criteria for each track are substantial — Track A's component-type table and analysis rules, Track B's four-category UX checklist, Track C's five drift criteria. In the monolithic prompt these lived inline even though only the relevant subagent needs each. As externalized templates, each is loaded only by the subagent that uses it. The orchestrator never loads track-specific criteria. Report format templates are similarly externalized — the orchestrator loads only `pass-report.md` or `final-report.md` as needed.

## Scoped Re-audit Design

The `scoped-reaudit` skill encodes a mapping from file paths to affected tracks. When the orchestrator completes a batch of changes, it consults this mapping to determine which subagents to spawn for the re-audit pass. The mapping is intentionally conservative — if uncertain, it errs toward re-running a track. The Docs track always runs when any file changes, since documentation drift can be introduced by any modification.

## Pass Budget Rationale

Five passes chosen as the default budget (configurable via `--max-passes=N`) based on the typical review arc: Pass 1 discovers initial findings, Pass 2 verifies fixes and catches regressions, Pass 3 handles cascade effects, with additional passes available for complex plugins. Reviews that haven't converged by the budget limit usually have findings representing accepted trade-offs or architectural limitations rather than fixable gaps. The budget is a structural checkpoint, not a hard wall — the user can choose to continue, but the orchestrator must surface the decision.

## Hook Design: PostToolUse Doc Write Tracker

The `doc-write-tracker` hook runs on every Write, Edit, MultiEdit, NotebookEdit, and MCP write tool use during a review session. It categorizes each written file path as "implementation" or "documentation" using two matching strategies: implementation paths are matched by directory prefix (`commands/`, `agents/`, `skills/`, `scripts/`, `hooks/scripts/`, `src/`, `templates/`); documentation is matched by basename (`README.md`, `DESIGN.md`, `CHANGELOG.md`). It tracks these categories in a state file at `.claude/state/plugin-review-writes.json`.

**Known gap**: `hooks/hooks.json` does not match any implementation directory prefix and is not tracked by the co-mutation check. This is an accepted gap — the orchestrator is not expected to edit hook declarations during review sessions, so the omission has no practical impact during normal use.

When an implementation file is written and the state file shows zero documentation writes in the current session, it emits a warning to the agent context. This catches the most common documentation co-mutation failure (forgetting to update docs entirely) while accepting that content accuracy verification must remain behavioral.

The hook uses `PLUGIN_REVIEW_ACTIVE=1` as a session-awareness gate — it only activates during review sessions, not normal development work.

## Hook Design: PostToolUse Agent Frontmatter Validator

The `validate-agent-frontmatter.sh` hook runs on every Write, Edit, and MultiEdit tool use. Unlike the doc-write-tracker, it is always active (not gated by `PLUGIN_REVIEW_ACTIVE`) because agent frontmatter correctness is a permanent invariant — not session-scoped.

When an `agents/*.md` file is written, the hook parses the YAML frontmatter `tools:` line and checks for disallowed tools (Write, Edit, MultiEdit, Bash, Task, NotebookEdit). If found, it emits a warning naming the disallowed tools and the corrective action. This is a secondary layer behind the primary structural enforcement (agent YAML frontmatter tool restrictions enforced by the Claude Code platform). The hook catches accidental additions before they persist unnoticed.
