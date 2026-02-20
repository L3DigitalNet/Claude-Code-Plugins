<!--
Reference document for the twelve context efficiency principles.
Loaded by: commands/review-context-efficiency.md alongside CONTEXT_EFFICIENCY_REVIEW.md.
Can be loaded independently when a user asks about any principle P1-P12 by name or ID.
If principle definitions change here, update CONTEXT_EFFICIENCY_REVIEW.md's cross-reference note
and docs/USAGE.md to match.
-->

# Context Efficiency Principles — Reference

Twelve principles for evaluating token efficiency in Claude Code plugins. Grouped into four layers.

## Instruction Design (P1–P3)

**P1 — Imperative Minimalism.** Every instruction sentence must define a behavior, constrain a choice, or specify a format. Delete anything that does not meet this test.

**P2 — Format Matches Data Type.** Structured data uses structured formats (YAML, markdown tables). Behavioral rules use natural language. Never encode structured data as prose.

**P3 — Reference Over Repetition.** Define a concept once, name it, reference the name thereafter. Never restate a definition.

## Runtime Efficiency (P4–P6)

**P4 — Lazy Context Loading.** Read the minimum data needed to answer the current question at the moment it is needed. Prefer targeted reads over whole-resource reads.

**P5 — Process and Discard.** After reading and analyzing content, carry forward a structured summary or extract — not the raw content.

**P6 — Output Verbosity Matches Consumer.** Human-facing outputs are clear and readable. Machine-consumed outputs are compact and schema-aligned. Know which you are producing before writing it.

## Agent Architecture (P7–P9)

**P7 — Decompose by Scope.** Each subagent's input context must be constructable from a small, targeted briefing. If a subagent requires the orchestrator's full context, the decomposition is wrong.

**P8 — Subagents Return Structured Extracts.** Subagent outputs follow an explicit schema and return results, not reasoning traces. Diagnostic output is a mode, not the default.

**P9 — Orchestrator Synthesizes, Does Not Re-Analyze.** The orchestrator trusts subagent outputs and routes, integrates, and synthesizes. It does not re-analyze source data the subagent already processed.

## Token Budget Awareness (P10–P12)

**P10 — Fail Fast, Surface Early.** Surface ambiguity, infeasibility, or blockers at the earliest possible point. Emit partial results mid-process rather than holding them.

**P11 — Choose the Lighter Path.** When multiple valid approaches exist and result quality is comparable, take the one with lower token cost. Make this tradeoff consciously, not by default.

**P12 — Verbosity Scales Inverse to Context Depth.** As context window depth grows, reduce tool call frequency and output verbosity. Early stages may read whole files; later stages read targeted ranges only.
