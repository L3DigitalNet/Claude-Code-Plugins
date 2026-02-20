# Context Efficiency Review

Read this file in full before beginning Stage 1.

---

## Principles

These are the evaluation standard. Every finding must cite one or more of these by ID.

**P1 — Imperative Minimalism.** Every instruction sentence must define a behavior, constrain a choice, or specify a format. Delete anything that does not meet this test.

**P2 — Format Matches Data Type.** Structured data uses structured formats (YAML, markdown tables). Behavioral rules use natural language. Never encode structured data as prose.

**P3 — Reference Over Repetition.** Define a concept once, name it, reference the name thereafter. Never restate a definition.

**P4 — Lazy Context Loading.** Read the minimum data needed to answer the current question at the moment it is needed. Prefer targeted reads over whole-resource reads.

**P5 — Process and Discard.** After reading and analyzing content, carry forward a structured summary or extract — not the raw content.

**P6 — Output Verbosity Matches Consumer.** Human-facing outputs are clear and readable. Machine-consumed outputs are compact and schema-aligned. Know which you are producing before writing it.

**P7 — Decompose by Scope.** Each subagent's input context must be constructable from a small, targeted briefing. If a subagent requires the orchestrator's full context, the decomposition is wrong.

**P8 — Subagents Return Structured Extracts.** Subagent outputs follow an explicit schema and return results, not reasoning traces. Diagnostic output is a mode, not the default.

**P9 — Orchestrator Synthesizes, Does Not Re-Analyze.** The orchestrator trusts subagent outputs and routes, integrates, and synthesizes. It does not re-analyze source data the subagent already processed.

**P10 — Fail Fast, Surface Early.** Surface ambiguity, infeasibility, or blockers at the earliest possible point. Emit partial results mid-process rather than holding them.

**P11 — Choose the Lighter Path.** When multiple valid approaches exist and result quality is comparable, take the one with lower token cost. Make this tradeoff consciously, not by default.

**P12 — Verbosity Scales Inverse to Context Depth.** As context window depth grows, reduce tool call frequency and output verbosity. Early stages may read whole files; later stages read targeted ranges only.

---

## Review Process

Execute each stage fully. Present findings at each checkpoint. Wait for explicit approval before advancing. Do not combine stages.

---

### Stage 1 — Analysis and Diagnosis

Read every file that constitutes the plugin: SKILL.md, supporting markdown, generated code samples, and slash command definitions. For each principle P1–P12, classify the plugin as COMPLIANT, VIOLATION, or AMBIGUOUS, and record the file and section where the issue occurs. Classify severity as HIGH (compounds across runs or agents), MEDIUM (recurring fixed cost), or LOW (bounded, one-time cost). Flag patterns that may be intentional or load-bearing as questions rather than violations.

Present findings grouped by principle. State the principle ID, observation, classification, and severity for each. Then ask whether any ambiguities require clarification before proceeding.

---

### Stage 2 — Consequence Mapping

For each VIOLATION or AMBIGUOUS finding, state the concrete consequence: not "violates P4" but "reads N files per invocation even when one is relevant, adding approximately X tokens of noise and risking context exhaustion on inputs exceeding Y." Classify each consequence as a correctness risk, reliability risk, or efficiency cost. Also map positive consequences where current behavior is intentional and worth preserving. Order all findings by severity: correctness risks first, reliability risks second, efficiency costs third.

Present the consequence map in that order. Confirm with the user that the impact assessment matches their experience with the plugin before proceeding.

---

### Stage 3 — Options and Tradeoffs

For each HIGH or MEDIUM severity finding, present two to three options that differ in strategy, not degree. For each option state: what changes are required, what token savings or risk reduction it achieves, what it trades away, and whether it creates dependencies on other planned changes. Group LOW severity findings into a single minor polish option. State your recommended option explicitly but frame it as a recommendation, not a prescription.

Present options grouped by finding. Ask the user to select an option for each finding, or to defer or skip it. Wait for explicit selections before proceeding.

---

### Stage 4 — Implementation Plan

Sequence the approved options in dependency order. Group changes into batches where internal order does not matter. For each planned change specify: target file and section, what will be added, removed, or modified, which approved option it implements, and any risk of behavioral change beyond token efficiency. Flag any change that requires a validation step.

Present the plan as a numbered sequence. End with a summary of files touched, estimated token savings, and any deferred items. Ask for explicit approval to proceed. Do not begin Stage 5 without it.

---

### Stage 5 — Implementation

Implement one step at a time in the approved sequence. Confirm each change briefly before proceeding to the next. Do not make changes beyond the approved plan. If a planned change proves more complex or risky than anticipated, pause and describe the situation — do not improvise. Preserve all content classified as COMPLIANT or intentional in Stage 1.

After all steps are complete, present a summary listing every change made, the expected token efficiency improvements, and any items flagged during implementation for a future review pass. List all instruction markdown files in the plugin as candidates for prose-level tightening via `MARKDOWN_TIGHTEN.md`.

---

## Uncertainty Protocol

When you cannot confidently classify a pattern, note it explicitly, state what you observe and why you are uncertain, ask a single specific question that would resolve it, and do not proceed until it is answered.

---

## Prohibited Behaviors

Do not compress or combine stages. Do not prescribe a single fix where options are warranted. Do not make changes outside the approved plan during Stage 5. Do not overstate token savings — qualify all estimates.
