# Context Efficiency → Plugin-Review Track D Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge `context-efficiency-toolkit` into `plugin-review` as Track D (Efficiency Analyst), migrate two standalone commands, and delete the source plugin.

**Architecture:** Track D follows the exact analyst agent pattern of Tracks A/B/C — a read-only agent (`efficiency-analyst`) loads a criteria template (`track-d-criteria.md`), evaluates P1–P12 compliance, and returns structured findings + JSON assertions. The orchestrator's Phase 2 spawns `efficiency-analyst` in parallel with the three existing analysts. Five files form the "cross-track registry" and must all be updated: `review.md`, `scoped-reaudit/SKILL.md`, `cross-track-impact.md`, `pass-report.md`, `final-report.md`. Two standalone commands (`review-efficiency`, `tighten`) move from context-efficiency-toolkit into plugin-review with corrected `${CLAUDE_PLUGIN_ROOT}` skill paths.

**Tech Stack:** Markdown (commands, agents, skills, templates), JSON (`plugin.json`, `marketplace.json`), bash (`validate-marketplace.sh`)

---

### Task 1: Create `track-d-criteria.md`

**Files:**
- Create: `plugins/plugin-review/templates/track-d-criteria.md`
- Reference: `plugins/plugin-review/templates/track-a-criteria.md` (format pattern)
- Reference: `plugins/context-efficiency-toolkit/skills/CONTEXT_EFFICIENCY_REFERENCE.md` (P1–P12 source)

**Step 1: Verify the file does not yet exist**

```bash
ls plugins/plugin-review/templates/track-d-criteria.md 2>&1
```
Expected: `No such file or directory`

**Step 2: Create `track-d-criteria.md`**

Create `plugins/plugin-review/templates/track-d-criteria.md` with this exact content:

```markdown
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
```

**Step 3: Verify content**

```bash
grep -c "P1\|P2\|P3\|P4\|P5\|P6\|P7\|P8\|P9\|P10\|P11\|P12" plugins/plugin-review/templates/track-d-criteria.md
```
Expected: 12+

**Step 4: Commit**

```bash
git add plugins/plugin-review/templates/track-d-criteria.md
git commit -m "feat(plugin-review): add track-d-criteria template for context efficiency"
```

---

### Task 2: Create `efficiency-analyst.md` agent

**Files:**
- Create: `plugins/plugin-review/agents/efficiency-analyst.md`
- Reference: `plugins/plugin-review/agents/principles-analyst.md` (exact structure to follow)

**Step 1: Verify the file does not yet exist**

```bash
ls plugins/plugin-review/agents/efficiency-analyst.md 2>&1
```
Expected: `No such file or directory`

**Step 2: Create `efficiency-analyst.md`**

Create `plugins/plugin-review/agents/efficiency-analyst.md` with this exact content:

```markdown
---
name: efficiency-analyst
description: Track D analysis — reads plugin implementation files and returns per-principle context efficiency status table with enforcement assessment and JSON assertions.
tools: Read, Grep, Glob
---

# Agent: Efficiency Analyst

You are a focused analysis subagent. Your sole job is to read a plugin's implementation files, compare them against twelve context efficiency principles (P1–P12), and return a structured assessment. You do not implement changes, interact with the user, or make decisions about what to fix.

## Role Boundaries

**You may:** Read files, analyze code, produce structured output.
**You may not:** Write or modify files, interact with the user, or make implementation recommendations. Return your findings — the orchestrator decides what to do with them.

## Setup

1. Load your analysis criteria from the template path provided by the orchestrator (the file `track-d-criteria.md`). This contains the component examination table, P1–P12 definitions, and status rules. Follow them exactly.
2. You will receive from the orchestrator:
   - A **list of files to read** (specific paths, not "read everything")
   - The template path: `$CLAUDE_PLUGIN_ROOT/templates/track-d-criteria.md`
   - On Pass 2+: the **previous pass's findings** for your track, plus a list of **changed files** to focus on

## Analysis Process

For each principle P1–P12, read the relevant implementation files (use the component examination table in the criteria to know which files map to which principles), determine the status (**Upheld**, **Partially Upheld**, or **Violated**), and note the evidence with a specific file and line reference where available.

On Pass 2+, focus on changed files and affected principles. Carry forward unchanged assessments as "Unchanged from Pass N."

## Output Format

```
## Context Efficiency — Pass <N>

### Open Findings

#### [Pn] <Principle Name> — <STATUS>
**Principle**: <one-line definition>
**Evidence**: <what supports/contradicts, with file reference>
**Gap**: <specific misalignment — what should be different>

### Upheld
[P1], [P3], [P4] — fully upheld with concrete implementation evidence.

### Partially Upheld
[P2] — intent present; inconsistently applied in <specific components>.
```

Do not deviate from this format. The orchestrator parses it to build the unified report.

## Assertions Output

After your findings, append an `## Assertions` section containing a JSON array of machine-verifiable checks, one per open finding:

```
## Assertions

```json
[
  {
    "id": "A-D-<number>",
    "finding_id": "<principle ID, e.g. P3>",
    "track": "D",
    "type": "<grep_not_match | grep_match | file_exists | file_content | shell_exit_zero>",
    "description": "One sentence: what this assertion verifies",
    "command": "<bash command to run — use full relative paths from repo root>",
    "expected": "<no_match | match | exists | contains | exit_zero>",
    "path": "<file path — only for file_exists and file_content types>",
    "needle": "<search string — only for file_content type>"
  }
]
```
```

**Assertion type guide:**
- `grep_not_match`: a pattern that should NOT appear (e.g., duplicated content block). Grep for it; expect empty output.
- `grep_match`: a pattern that SHOULD appear (e.g., required discard comment). Grep for it; expect non-empty output.
- `file_exists`: a missing file. Use `path` field (no `command`).
- `file_content`: missing content in an existing file. Use `path` + `needle` fields.
- `shell_exit_zero`: a script that should run cleanly.

**Write one assertion per open finding.** If a finding has no machine-verifiable check, omit it — do not invent synthetic assertions. Only include assertions that will currently FAIL (the finding represents a current gap).
```

**Step 3: Verify structure**

```bash
grep "tools:" plugins/plugin-review/agents/efficiency-analyst.md
grep "track.*D\|A-D-" plugins/plugin-review/agents/efficiency-analyst.md
```
Expected: `tools: Read, Grep, Glob` and `A-D-` present

**Step 4: Commit**

```bash
git add plugins/plugin-review/agents/efficiency-analyst.md
git commit -m "feat(plugin-review): add efficiency-analyst agent for Track D"
```

---

### Task 3: Update `review.md` — Phase 2 spawn + scoped re-audit

**Files:**
- Modify: `plugins/plugin-review/commands/review.md`

**Step 1: Find the exact Phase 2 subagent list**

```bash
grep -n "Principles Analyst\|UX Analyst\|Docs Analyst\|all three" plugins/plugin-review/commands/review.md
```
Expected: Shows lines with the three analyst bullets and the "all three" count

**Step 2: Add Efficiency Analyst to Phase 2 subagent list**

In `commands/review.md`, find this block (around line 84–90):
```
Spawn all three analyst subagents. **When spawning each agent, include the resolved template path** so the agent knows where to load its criteria:

- **Principles Analyst** ...
- **UX Analyst** ...
- **Docs Analyst** ...
```

Change "Spawn all three analyst subagents" to "Spawn all four analyst subagents" and add the efficiency-analyst bullet after the Docs Analyst line:

```
- **Efficiency Analyst** (`agents/efficiency-analyst.md`): provide the component list to analyze, and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-d-criteria.md`.
```

**Step 3: Add Track D row to the tier classification table**

In Phase 4, find the tier decision table (around line 143–152). Add this row after the existing Track C row (row 4):

```
| 5 | 2 | Track D finding (context efficiency); finding type "Violated" |
```

Renumber the subsequent rows (old 5 → 6, old 6 → 7).

**Step 4: Verify**

```bash
grep -c "Efficiency Analyst\|efficiency-analyst" plugins/plugin-review/commands/review.md
grep "all four" plugins/plugin-review/commands/review.md
```
Expected: 2+ references to efficiency-analyst, and "all four" present

**Step 5: Commit**

```bash
git add plugins/plugin-review/commands/review.md
git commit -m "feat(plugin-review): add efficiency-analyst Track D to Phase 2 spawn and tier table"
```

---

### Task 4: Update `pass-report.md` — add Track D summary line and findings section

**Files:**
- Modify: `plugins/plugin-review/templates/pass-report.md`

**Step 1: Verify the current summary block**

```bash
grep -n "Documentation\|Open findings\|Summary" plugins/plugin-review/templates/pass-report.md | head -10
```
Expected: Shows the Pass 1 Format summary lines including "Documentation" and "Open findings"

**Step 2: Add Context Efficiency line to the Summary block**

In the Pass 1 Format `### Summary` block, add after the Documentation line:
```
- Context Efficiency: <N> checked | <N> upheld | <N> partial | <N> violated
```

**Step 3: Add "Open Findings — Context Efficiency" section**

After the `### Open Findings — Documentation` section, add:
```
### Open Findings — Context Efficiency

#### [Pn] <Principle Name> — <STATUS>
**Principle**: <definition>
**Evidence**: <what supports/contradicts, with file reference>
**Gap**: <specific misalignment>
```

Also update the `### Upheld (no action needed)` roll-up text to mention "Context efficiency principles [list IDs] are fully upheld" as a possible addition.

**Step 4: Update the architectural-context comment**

Add to the `<!-- architectural-context -->` comment:
```
  Autonomous mode additions: ... Context Efficiency summary line added (Pass 1+).
    Track D open findings section added after Documentation section.
```

**Step 5: Verify**

```bash
grep -c "Context Efficiency" plugins/plugin-review/templates/pass-report.md
```
Expected: 3+

**Step 6: Commit**

```bash
git add plugins/plugin-review/templates/pass-report.md
git commit -m "feat(plugin-review): add Track D context efficiency to pass-report template"
```

---

### Task 5: Update `final-report.md` — add Context Efficiency Status section

**Files:**
- Modify: `plugins/plugin-review/templates/final-report.md`

**Step 1: Find the Documentation Status section**

```bash
grep -n "Documentation Status\|UX Status\|Assertion Coverage" plugins/plugin-review/templates/final-report.md
```
Expected: Shows the sections in order

**Step 2: Add Context Efficiency Status table after Documentation Status**

After the `### Documentation Status` table and before `### Assertion Coverage`, add:
```
### Context Efficiency Status
| Principle | Status | Notes |
|-----------|--------|-------|
| P1 Imperative Minimalism | ✅ / ⚠️ / ❌ | |
| P2 Format Matches Data Type | | |
| P3 Reference Over Repetition | | |
| P4 Lazy Context Loading | | |
| P5 Process and Discard | | |
| P6 Output Verbosity | | |
| P7 Decompose by Scope | | |
| P8 Subagents Return Structured Extracts | | |
| P9 Orchestrator Synthesizes | | |
| P10 Fail Fast | | |
| P11 Choose Lighter Path | | |
| P12 Verbosity Scales Inverse to Context Depth | | |
```

**Step 3: Update the Rules section**

In the `## Rules` paragraph at the bottom, add: "Every P1–P12 context efficiency principle must appear in Context Efficiency Status."

**Step 4: Verify**

```bash
grep -c "Context Efficiency\|P1.*Imperative\|P12.*Verbosity" plugins/plugin-review/templates/final-report.md
```
Expected: 3+

**Step 5: Commit**

```bash
git add plugins/plugin-review/templates/final-report.md
git commit -m "feat(plugin-review): add Track D context efficiency status to final-report template"
```

---

### Task 6: Update `cross-track-impact.md` — register Track D

**Files:**
- Modify: `plugins/plugin-review/templates/cross-track-impact.md`

**Step 1: Read the full file to understand current structure**

```bash
cat plugins/plugin-review/templates/cross-track-impact.md
```
Expected: Track A, B, C impact mappings and a note about "Adding a new track requires updating all four files simultaneously"

**Step 2: Add Track D to all impact mapping sections**

For each track section (A, B, C), add a "Track X affects Track D" entry describing the cross-track relationship:
- Track A affects Track D: principle violations often involve redundant instruction blocks (P3) or behavioral-layer-only enforcement when mechanical is feasible (P10)
- Track B affects Track D: UX verbosity patterns directly reflect P6 and P2 compliance
- Track C affects Track D: documentation duplication is a direct P3 signal; doc verbosity reflects P1

Add a new "Track D" section:
- Track D affects Track A: efficiency violations often expose behavioral-only enforcement where mechanical is implied
- Track D affects Track B: P6 violations surface in the same touchpoints Track B monitors
- Track D affects Track C: P1 violations (over-long instructions) and P3 violations (duplicated content) show up as doc findings too

**Step 3: Update the "four files" note**

Find the note about "Adding a new track requires updating all four files simultaneously" and update it to five files:
```
Adding a new track requires updating all five files simultaneously:
cross-track-impact.md, review.md, pass-report.md, final-report.md, skills/scoped-reaudit/SKILL.md
```

**Step 4: Verify**

```bash
grep -c "Track D\|efficiency" plugins/plugin-review/templates/cross-track-impact.md
```
Expected: 4+

**Step 5: Commit**

```bash
git add plugins/plugin-review/templates/cross-track-impact.md
git commit -m "feat(plugin-review): register Track D in cross-track impact map"
```

---

### Task 7: Update `scoped-reaudit/SKILL.md` — add Track D mapping

**Files:**
- Modify: `plugins/plugin-review/skills/scoped-reaudit/SKILL.md`

**Step 1: Read the current File-to-Track Mapping section**

```bash
grep -n "Track A\|Track B\|Track C\|Track D" plugins/plugin-review/skills/scoped-reaudit/SKILL.md
```
Expected: A, B, C entries present; D absent

**Step 2: Add Track D entry to File-to-Track Mapping**

After the Track C paragraph, add:

```
**Track D (Efficiency Analyst)** is affected when any of these were modified: `commands/*.md`, `agents/*.md`, `skills/*/SKILL.md`, `hooks/hooks.json`, `scripts/*.sh`, `.mcp.json`, `src/**`, or `templates/*.md`. Track D evaluates context efficiency patterns that appear in all component types; any component modification may introduce efficiency regressions.
```

**Step 3: Update the architectural-context comment**

Update the `Output contract` line to mention Track D:
```
  Output contract: the orchestrator extracts the Track A / Track B / Track C / Track D determination
    from the File-to-Track Mapping section. Track letters (A, B, C, D) must match the agent
    names used in review.md Phase 2's spawn instructions.
```

**Step 4: Verify**

```bash
grep "Track D" plugins/plugin-review/skills/scoped-reaudit/SKILL.md
```
Expected: 1+ matches

**Step 5: Commit**

```bash
git add plugins/plugin-review/skills/scoped-reaudit/SKILL.md
git commit -m "feat(plugin-review): add Track D file-to-track mapping in scoped-reaudit skill"
```

---

### Task 8: Add skill files to `plugin-review/skills/`

**Files:**
- Create: `plugins/plugin-review/skills/context-efficiency-workflow/SKILL.md`
- Create: `plugins/plugin-review/skills/context-efficiency-reference/SKILL.md`
- Create: `plugins/plugin-review/skills/markdown-tighten/SKILL.md`
- Source: `plugins/context-efficiency-toolkit/skills/CONTEXT_EFFICIENCY_REVIEW.md`
- Source: `plugins/context-efficiency-toolkit/skills/CONTEXT_EFFICIENCY_REFERENCE.md`
- Source: `plugins/context-efficiency-toolkit/skills/MARKDOWN_TIGHTEN.md`

**Step 1: Verify the source files exist**

```bash
ls plugins/context-efficiency-toolkit/skills/
```
Expected: `CONTEXT_EFFICIENCY_REVIEW.md  CONTEXT_EFFICIENCY_REFERENCE.md  MARKDOWN_TIGHTEN.md`

**Step 2: Create skill directories and copy content**

```bash
mkdir -p plugins/plugin-review/skills/context-efficiency-workflow
mkdir -p plugins/plugin-review/skills/context-efficiency-reference
mkdir -p plugins/plugin-review/skills/markdown-tighten

cp plugins/context-efficiency-toolkit/skills/CONTEXT_EFFICIENCY_REVIEW.md \
   plugins/plugin-review/skills/context-efficiency-workflow/SKILL.md

cp plugins/context-efficiency-toolkit/skills/CONTEXT_EFFICIENCY_REFERENCE.md \
   plugins/plugin-review/skills/context-efficiency-reference/SKILL.md

cp plugins/context-efficiency-toolkit/skills/MARKDOWN_TIGHTEN.md \
   plugins/plugin-review/skills/markdown-tighten/SKILL.md
```

**Step 3: Verify all three files created**

```bash
ls plugins/plugin-review/skills/context-efficiency-workflow/SKILL.md \
   plugins/plugin-review/skills/context-efficiency-reference/SKILL.md \
   plugins/plugin-review/skills/markdown-tighten/SKILL.md
```
Expected: all three files found

**Step 4: Commit**

```bash
git add plugins/plugin-review/skills/
git commit -m "feat(plugin-review): add context-efficiency-workflow, context-efficiency-reference, markdown-tighten skills"
```

---

### Task 9: Migrate `review-context-efficiency` → `review-efficiency`

**Files:**
- Create: `plugins/plugin-review/commands/review-efficiency.md`
- Source: `plugins/context-efficiency-toolkit/commands/review-context-efficiency.md`

**Step 1: Read the source command to find path references**

```bash
grep -n "\.claude/skills\|CONTEXT_EFFICIENCY" plugins/context-efficiency-toolkit/commands/review-context-efficiency.md
```
Expected: Two `.claude/skills/` references

**Step 2: Create the migrated command**

Create `plugins/plugin-review/commands/review-efficiency.md` as a copy of `review-context-efficiency.md` with:
- The comment header updated to reference new skill paths
- `.claude/skills/CONTEXT_EFFICIENCY_REFERENCE.md` → `${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-reference/SKILL.md`
- `.claude/skills/CONTEXT_EFFICIENCY_REVIEW.md` → `${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-workflow/SKILL.md`

The two `Read` lines in the command body become:
```
Read `${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-reference/SKILL.md` in full.
Read `${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-workflow/SKILL.md` in full.
```

**Step 3: Verify no stale paths remain**

```bash
grep "\.claude/skills" plugins/plugin-review/commands/review-efficiency.md
```
Expected: no output (zero matches)

```bash
grep "CLAUDE_PLUGIN_ROOT" plugins/plugin-review/commands/review-efficiency.md
```
Expected: 2 matches

**Step 4: Commit**

```bash
git add plugins/plugin-review/commands/review-efficiency.md
git commit -m "feat(plugin-review): migrate review-efficiency command with corrected skill paths"
```

---

### Task 10: Migrate `tighten-markdown` → `tighten`

**Files:**
- Create: `plugins/plugin-review/commands/tighten.md`
- Source: `plugins/context-efficiency-toolkit/commands/tighten-markdown.md`

**Step 1: Find the path reference**

```bash
grep -n "\.claude/skills\|MARKDOWN_TIGHTEN" plugins/context-efficiency-toolkit/commands/tighten-markdown.md
```
Expected: One `.claude/skills/MARKDOWN_TIGHTEN.md` reference

**Step 2: Create the migrated command**

Create `plugins/plugin-review/commands/tighten.md` as a copy of `tighten-markdown.md` with:
- Comment header updated to reference new skill path
- `.claude/skills/MARKDOWN_TIGHTEN.md` → `${CLAUDE_PLUGIN_ROOT}/skills/markdown-tighten/SKILL.md`

The `Read` line in the command body becomes:
```
Read `${CLAUDE_PLUGIN_ROOT}/skills/markdown-tighten/SKILL.md` in full.
```

**Step 3: Verify**

```bash
grep "\.claude/skills" plugins/plugin-review/commands/tighten.md
```
Expected: no output

```bash
grep "CLAUDE_PLUGIN_ROOT" plugins/plugin-review/commands/tighten.md
```
Expected: 1 match

**Step 4: Commit**

```bash
git add plugins/plugin-review/commands/tighten.md
git commit -m "feat(plugin-review): migrate tighten command with corrected skill path"
```

---

### Task 11: Bump plugin-review version and update CHANGELOG + README

**Files:**
- Modify: `plugins/plugin-review/.claude-plugin/plugin.json` (v0.4.0 → v0.5.0)
- Modify: `plugins/plugin-review/CHANGELOG.md`
- Modify: `plugins/plugin-review/README.md`

**Step 1: Verify current version**

```bash
cat plugins/plugin-review/.claude-plugin/plugin.json
```
Expected: `"version": "0.4.0"`

**Step 2: Bump version in plugin.json**

Change `"version": "0.4.0"` → `"version": "0.5.0"`

**Step 3: Prepend CHANGELOG entry**

Add at the top of `CHANGELOG.md`, before the current latest entry:

```markdown
## [0.5.0] - 2026-03-01

### Added

- Track D context efficiency analysis: `efficiency-analyst` agent evaluates P1–P12 compliance in parallel with Tracks A/B/C
- `track-d-criteria.md` template: P1–P12 evaluation criteria with component examination table
- `review-efficiency` command: standalone 5-stage interactive context efficiency review (migrated from context-efficiency-toolkit)
- `tighten` command: prose tightening workflow for plugin markdown files (migrated from context-efficiency-toolkit)
- `context-efficiency-workflow` skill: approval-gated P1–P12 review workflow
- `context-efficiency-reference` skill: P1–P12 principle definitions and layer taxonomy
- `markdown-tighten` skill: five-step prose compression workflow
- Track D entries in `pass-report.md` and `final-report.md` templates
- Track D mapping in `cross-track-impact.md` and `scoped-reaudit/SKILL.md`
```

**Step 4: Update README**

In `README.md`, add entries for the three new commands and Track D analyst:
- Under the Commands table: add `review-efficiency` and `tighten`
- Under the Agents table: add `efficiency-analyst`
- Under the Skills or Tracks section: mention Track D and the three new skills

**Step 5: Verify**

```bash
grep '"version"' plugins/plugin-review/.claude-plugin/plugin.json
grep "0.5.0" plugins/plugin-review/CHANGELOG.md
```
Expected: `"version": "0.5.0"` and the changelog entry present

**Step 6: Commit**

```bash
git add plugins/plugin-review/.claude-plugin/plugin.json \
        plugins/plugin-review/CHANGELOG.md \
        plugins/plugin-review/README.md
git commit -m "feat(plugin-review): bump to v0.5.0 — Track D context efficiency integration"
```

---

### Task 12: Update `marketplace.json`

**Files:**
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Confirm current entries**

```bash
grep -A3 '"context-efficiency-toolkit"\|"plugin-review"' .claude-plugin/marketplace.json
```
Expected: Both entries present; `plugin-review` at v0.4.0

**Step 2: Remove context-efficiency-toolkit entry**

Delete the entire `context-efficiency-toolkit` object from the `plugins` array (the full `{ ... }` block including trailing comma).

**Step 3: Bump plugin-review to v0.5.0**

Change `"version": "0.4.0"` → `"version": "0.5.0"` in the plugin-review entry.

**Step 4: Run marketplace validation**

```bash
./scripts/validate-marketplace.sh
```
Expected: PASS

**Step 5: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "chore: remove context-efficiency-toolkit, bump plugin-review to v0.5.0 in marketplace"
```

---

### Task 13: Delete `plugins/context-efficiency-toolkit/`

**Files:**
- Delete: `plugins/context-efficiency-toolkit/` (entire directory)

**Step 1: Verify no plugin-review files reference the old plugin's paths**

```bash
grep -r "context-efficiency-toolkit\|\.claude/skills/CONTEXT_EFFICIENCY\|\.claude/skills/MARKDOWN_TIGHTEN" \
  plugins/plugin-review/ 2>/dev/null
```
Expected: no output (zero matches — all migrated paths should use `${CLAUDE_PLUGIN_ROOT}`)

**Step 2: Delete the plugin directory**

```bash
rm -rf plugins/context-efficiency-toolkit/
```

**Step 3: Verify deletion and run final validation**

```bash
ls plugins/context-efficiency-toolkit/ 2>&1
./scripts/validate-marketplace.sh
```
Expected: `No such file or directory` for ls, and PASS for validator

**Step 4: Verify no broken references anywhere in the repo**

```bash
grep -r "context-efficiency-toolkit" plugins/ .claude-plugin/ 2>/dev/null
```
Expected: no output

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: delete context-efficiency-toolkit — fully merged into plugin-review v0.5.0"
```

---

## Completion Checklist

After all tasks, verify:

```bash
# All new files exist
ls plugins/plugin-review/templates/track-d-criteria.md
ls plugins/plugin-review/agents/efficiency-analyst.md
ls plugins/plugin-review/commands/review-efficiency.md
ls plugins/plugin-review/commands/tighten.md
ls plugins/plugin-review/skills/context-efficiency-workflow/SKILL.md
ls plugins/plugin-review/skills/context-efficiency-reference/SKILL.md
ls plugins/plugin-review/skills/markdown-tighten/SKILL.md

# Source plugin gone
ls plugins/context-efficiency-toolkit 2>&1 | grep "No such"

# Versions consistent
grep '"version"' plugins/plugin-review/.claude-plugin/plugin.json
grep -A1 '"plugin-review"' .claude-plugin/marketplace.json | grep version

# Marketplace validates
./scripts/validate-marketplace.sh
```
