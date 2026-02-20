<!--
Invoked by: commands/review-context-efficiency.md (which reads this file and CONTEXT_EFFICIENCY_REFERENCE.md).
Provides: Five-stage workflow for auditing a plugin against the twelve context efficiency principles.
Interacts with: CONTEXT_EFFICIENCY_REFERENCE.md (principle definitions) and MARKDOWN_TIGHTEN.md (Stage 5 follow-up).
If stage structure or checkpoint behavior changes here, update commands/review-context-efficiency.md
and docs/USAGE.md to match.
-->

# Context Efficiency Review

Principles P1–P12 are defined in CONTEXT_EFFICIENCY_REFERENCE.md. Reference them by ID in all findings.

## Review Process

Execute each stage fully. Present findings at each checkpoint. Wait for explicit approval before advancing. Do not combine stages.

### Stage 1 — Analysis and Diagnosis

Read every file that constitutes the plugin: SKILL.md, supporting markdown, generated code samples, and slash command definitions. For each principle P1–P12, classify the plugin as COMPLIANT, VIOLATION, or AMBIGUOUS, and record the file and section where the issue occurs. Classify severity as HIGH (compounds across runs or agents), MEDIUM (recurring fixed cost), or LOW (bounded, one-time cost). Flag patterns that may be intentional or load-bearing as questions rather than violations.

Present findings as a table with columns: Principle | Classification | Severity | File/Section. Precede the table with a one-line summary count (e.g., "3 violations, 2 ambiguous, 7 compliant"). Then ask whether any ambiguities require clarification before proceeding.

### Stage 2 — Consequence Mapping

For each VIOLATION or AMBIGUOUS finding, state the concrete consequence: not "violates P4" but "reads N files per invocation even when one is relevant, adding approximately X tokens of noise and risking context exhaustion on inputs exceeding Y." Classify each consequence as a correctness risk, reliability risk, or efficiency cost. Also map positive consequences where current behavior is intentional and worth preserving. Order all findings by severity: correctness risks first, reliability risks second, efficiency costs third.

Present the consequence map in that order. Use a bounded checkpoint: ask the user to choose [Proceed] [Adjust a finding] [Skip a finding]. Wait for explicit confirmation before advancing to Stage 3.

### Stage 3 — Options and Tradeoffs

For each HIGH or MEDIUM severity finding, present two to three options that differ in strategy, not degree. For each option state: what changes are required, what token savings or risk reduction it achieves, what it trades away, and whether it creates dependencies on other planned changes. Group LOW severity findings into a single minor polish option. State your recommended option explicitly but frame it as a recommendation, not a prescription.

Present all findings and their options as a single table with columns: Finding | Option A | Option B | Option C (if applicable) | Recommended. Collect all selections in one round-trip — ask once for all choices. Wait for all selections before proceeding.

### Stage 4 — Implementation Plan

Sequence the approved options in dependency order. Group changes into batches where internal order does not matter. For each planned change specify: target file and section, what will be added, removed, or modified, which approved option it implements, and any risk of behavioral change beyond token efficiency. Flag any change that requires a validation step.

Present the plan as a numbered sequence. End with a summary of files touched, estimated token savings (qualified as approximate), and any deferred items. Ask for explicit approval to proceed. Do not begin Stage 5 without it.

### Stage 5 — Implementation

Implement the approved sequence in order. After each step, emit a brief progress note (e.g., "✓ Step 2 complete — removed redundant preamble"). Do not request confirmation between steps. Pause only if a planned change proves more complex or risky than anticipated — do not improvise and do not continue past a known deviation. Do not make changes beyond the approved plan. Preserve all content classified as COMPLIANT or intentional in Stage 1.

After all steps are complete, present a summary listing every change made, the expected token efficiency improvements, and any items flagged during implementation for a future review pass. You may optionally note any instruction markdown files in the plugin as candidates for prose-level tightening via `MARKDOWN_TIGHTEN.md`.

## Uncertainty Protocol

When you cannot confidently classify a pattern, note it explicitly, state what you observe and why you are uncertain, ask a single specific question that would resolve it, and do not proceed until it is answered.

## Prohibited Behaviors

Do not compress or combine stages. Do not prescribe a single fix where options are warranted. Do not make changes outside the approved plan during Stage 5. Do not overstate token savings — qualify all estimates.
