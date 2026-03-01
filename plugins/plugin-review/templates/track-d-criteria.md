# Track D: Context Efficiency Criteria

<!-- architectural-context
  Loaded by: agents/efficiency-analyst.md — receives this file path in its prompt
    and reads it with the Read tool at the start of its analysis session.
  Never loaded by: the orchestrator (commands/review.md). If the orchestrator reads this,
    it violates [P3] On-Demand Template Loading.
  Output contract: the status vocabulary (Upheld / Partially Upheld / Violated) defined here
    must match what review.md Phase 3 expects in the subagent's returned analysis table.
    Changing status labels here requires updating pass-report.md and final-report.md to match.
  Cross-file dependency: scoped-reaudit/SKILL.md defines which file changes trigger
    a Track D re-audit. If the scope of Track D changes, update that skill to match.
  Source: principles P1–P12 originate from the context-efficiency-toolkit plugin
    (merged into plugin-review v0.5.0). The canonical reference is
    skills/context-efficiency-reference/SKILL.md in this plugin.
-->

Load this template when performing context efficiency analysis. It defines what to examine in each component type and the twelve principles to evaluate against.

## Component Examination Table

| Component | Look for | Relevant principles |
|-----------|----------|---------------------|
| **Commands** (`commands/*.md`) | Instruction length, template delegation vs. inlining, preemptive context loading, output verbosity spec | P1, P3, P4, P6 |
| **Skills** (`skills/*/SKILL.md`) | Load-on-demand patterns, scope creep beyond declared purpose, verbosity of skill content | P1, P4, P7 |
| **Agents** (`agents/*.md`) | Structured return format, scope boundaries, intermediate result accumulation | P7, P8, P9 |
| **Hooks** (`hooks/hooks.json`, `scripts/*.sh`) | Fail-fast / early bailout on invalid input, stdout verbosity | P10, P11 |
| **Templates** (`templates/`) | Duplication of shared content vs. single-definition, format matching consumer needs | P2, P3 |
| **MCP server** (`.mcp.json`, `src/`) | Tool granularity, response format, structured vs. raw output | P2, P8, P11 |
| **State files** (`.claude/state/`) | Accumulation patterns, discard-after-use vs. perpetual growth | P5 |

## Analysis Rules

### Status Definitions

**Upheld**: Concrete implementation evidence — a structural constraint, an architectural choice, or an explicit design — makes the principle true. The enforcement is appropriate to the principle's intent.

**Partially Upheld**: The intent is present but inconsistently applied. Common pattern: a principle honored in most components but violated in one, or a pattern applied correctly in commands but absent in agents.

**Violated**: The implementation contradicts the principle, or nothing in the codebase enforces or supports it. The principle has zero implementation footprint.

### Principle Definitions

#### Layer 1 — Instruction Design

**P1 Imperative Minimalism**: Instruction sets contain only what is needed to produce correct output. No preamble, no safety caveats that don't affect behavior, no restatement of the user's request. A 300-word instruction block that could achieve the same result in 100 words is a violation even if every word is individually correct.

**P2 Format Matches Data Type**: Output format matches what the consumer will act on. Prose narratives for structured data, unformatted dumps for tabular data, and dense JSON where a brief summary suffices are all violations. The format choice should be made at the consumer's boundary, not the producer's preference.

**P3 Reference Over Repetition**: Shared content is defined once and referenced, not duplicated. Identical instruction blocks appearing in two commands, copy-pasted criteria spread across multiple agents, and template content inlined into orchestrators are all violations. The correct pattern is to define once in a skill or template and load at the point of need.

#### Layer 2 — Runtime Efficiency

**P4 Lazy Context Loading**: Context is loaded on demand, not preemptively. A command that loads all skill files at startup regardless of which path the user takes is a violation. The correct pattern is to load a skill only when the relevant branch is entered — and to discard it immediately when the branch is complete.

**P5 Process and Discard**: Intermediate results are consumed and discarded, not accumulated. An orchestrator that grows its context with raw subagent transcripts instead of structured extracts, or a loop that accumulates every pass result into a single growing document, violates this principle. The correct pattern is to extract the needed fields and let the raw output leave scope.

**P6 Output Verbosity**: Output length scales with what the consumer will actually read and act on. A subagent that returns 2000 tokens of context when the orchestrator needs 50 tokens of structured findings is a violation. Verbose output is appropriate when every word reaches a decision-making reader; it is waste when routed to a program that extracts three fields.

#### Layer 3 — Agent Architecture

**P7 Decompose by Scope**: Work is decomposed at natural scope boundaries, not implementation boundaries. An agent whose "single responsibility" is actually several unrelated responsibilities bundled together is a violation. The test: could any part of this agent's output be removed without the other parts caring? If yes, decomposition is wrong.

**P8 Subagents Return Structured Extracts**: Subagents return structured summaries, not raw transcripts. A subagent that returns its full reasoning chain, intermediate results, or tool call outputs as part of its response is a violation. The orchestrator should receive a clean, parseable extract — findings, status, assertions — not a replay of the subagent's work.

**P9 Orchestrator Synthesizes**: The orchestrator aggregates and decides; subagents do not. A subagent that makes implementation decisions, proposes fixes, or deduces next steps for the orchestrator violates role boundaries. The subagent reports findings; the orchestrator chooses what to do with them.

#### Layer 4 — Token Budget

**P10 Fail Fast**: When required context is missing, abort with a clear error immediately. Do not continue processing with degraded context, emit partial results, or guess at missing inputs. A command that proceeds without a required config value and produces incorrect output downstream is a violation.

**P11 Choose Lighter Path**: When multiple approaches achieve equivalent outcomes, choose the one with lower context cost. This applies to tool selection (Read a specific section vs. reading the whole file), agent selection (spawning a full analyst vs. a targeted grep), and output format (a one-line status vs. a structured report for a binary decision).

**P12 Verbosity Scales Inverse to Context Depth**: The deeper into a call stack, the more terse the output should be. A top-level orchestrator talking to the user may emit rich formatted output. A sub-sub-agent writing to a state file should emit a JSON object. Verbosity that is appropriate at depth 1 is waste at depth 3.
