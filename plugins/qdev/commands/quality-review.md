---
name: quality-review
description: Research-first iterative quality review via qdev-quality-reviewer subagent (Sonnet). Auto-detects spec, plan, or code mode. Iterates to convergence.
argument-hint: "[optional: path to file or directory to review]"
allowed-tools:
  - Agent
  - AskUserQuestion
---

# /qdev:quality-review

Review a spec, plan, or codebase for gaps, inconsistencies, and staleness — with research-backed ground truth — by dispatching the `qdev-quality-reviewer` subagent. The subagent iterates to convergence. This command orchestrates the user-interaction portion (critical-finding gate, needs-approval decisions).

## Why this is a subagent

The research phase runs dual-source web search (brave + serper) plus Context7 docs lookup over 5-10 dependencies — hundreds of search results in raw form, with tavily-extract pulling clean content from key pages. The convergence loop re-reads the artifact N times per pass. Running it in Opus costs ~22K tokens per review. Sonnet is the right tier for multi-step reasoning with convergence; the subagent consolidates research + analysis + auto-fix application into a single dispatch.

## How to run it

1. Determine the target. If `$ARGUMENTS` is provided, use it as the path. Otherwise, use `AskUserQuestion` to ask which artifact to review — offer candidates you can infer from the working directory (recent files in `docs/specs/`, `docs/plans/`, or `src/`). Do not guess.

2. Dispatch `qdev-quality-reviewer` with the target path.

   Use the `Agent` tool with `subagent_type: qdev:qdev-quality-reviewer` and a prompt like:

   > Review `<target path>`. Auto-detect mode. Run research. Apply auto-fixes. Return the convergence report per your output format. Do not call AskUserQuestion — surface needs-approval findings in the structured output.

## After the agent returns

The agent may return one of three shapes:

### Shape A: Critical-finding gate

If the response starts with `## ⚠ Critical findings from research`, the subagent halted before entering the pass loop. Surface the critical-finding table verbatim and use `AskUserQuestion`:

- question: `"Critical issues found. How would you like to proceed?"`
- options:
  1. label: `"Proceed with review"`, description: `"Re-dispatch with instruction to continue into the pass loop"`
  2. label: `"Stop and fix these first"`, description: `"End the review here"`

If "Proceed": re-dispatch the subagent with an explicit note in the prompt: "Proceed past the critical-finding gate; continue into the pass loop."

### Shape B: Oscillation

If the response contains `## ⚠ OSCILLATION DETECTED`, the subagent stopped to prevent thrashing. Surface the block verbatim and use `AskUserQuestion`:

- question: `"Oscillation detected — the fix loop kept reverting. Resolve?"`
- options:
  1. label: `"Accept latest state"`, description: `"Keep the most recent edit"`
  2. label: `"Revert to original"`, description: `"Undo and leave section alone"`
  3. label: `"I'll edit manually"`, description: `"Stop here; I'll handle the contested section"`

Apply the chosen resolution via `Edit` (or via manual handoff).

### Shape C: Normal convergence

The response contains `## Convergence Log` and `## Needs-approval findings`.

1. Present the convergence log and auto-fixes summary to the user verbatim.

2. If the Needs-approval findings table is non-empty, walk it one at a time. For each row, use `AskUserQuestion`:

   - header: `"Finding [N/Total]"`
   - question: `"[TYPE]\n\nLocation: <file:line>\nIssue: <row description>\nProposed fix: <proposed fix>\nSource: <source URL>"`
   - options:
     1. label: `"Apply fix"`, description: `"Implement the proposed change"`
     2. label: `"Apply with modifications"`, description: `"Apply, but I'll describe what to change"`
     3. label: `"Defer"`, description: `"Skip for now"`
     4. label: `"Skip permanently"`, description: `"Do not raise this finding again"`

   For `"Apply fix"`: apply via `Edit` in this session.
   For `"Apply with modifications"`: ask a follow-up open-ended question for the modification text; apply the modified version.
   For `"Defer"` or `"Skip permanently"`: note and move on.

3. If any approved modifications were applied, re-dispatch the subagent one more time for a final convergence pass on the modified artifact. Stop when zero new findings.

4. Emit the final summary:

   ```
   ✓ Quality review complete. N passes, M auto-fixes applied, K approved modifications.
   Deferred: D items
   ```
