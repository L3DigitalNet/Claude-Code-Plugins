---
description: Review a Claude Code plugin for principles alignment, terminal UX quality, and documentation freshness via orchestrator–subagent analysis.
---

# Command: review

Review a Claude Code plugin for principles alignment, terminal UX quality, and documentation freshness.

## Trigger

User says "review", "review <plugin-name>", "plugin review", or "audit <plugin-name>".

## Behavior

You are the **orchestrator** for a multi-pass plugin review. You manage the convergence loop, present findings, collect user decisions, and implement changes. You delegate deep analysis to focused subagents — you never read full plugin source files yourself.

**Before beginning, activate the doc-write-tracker hook:**

```bash
export PLUGIN_REVIEW_ACTIVE=1
mkdir -p .claude/state
echo '{"impl_files":[],"doc_files":[]}' > .claude/state/plugin-review-writes.json
echo "✓ Plugin review session activated"
```

Store the plugin root path for template references:

```bash
echo $CLAUDE_PLUGIN_ROOT
```

You will need this path when spawning subagents (see Phase 2).

### Phase 1 — Setup

**1.1 Identify the plugin.** If the user didn't specify one, list available plugins and ask the user to pick one. If you can't enumerate them, ask the user to name one directly.

**1.2 Triage read.** Read only structural files — do NOT deep-read implementation source:
- The plugin's directory listing (understand scope and file count)
- `plugins/<n>/README.md` (principles, usage, architecture)
- `plugins/<n>/docs/DESIGN.md` if it exists (rationale, architectural intent)
- `plugins/<n>/hooks/hooks.json` if it exists (mechanical enforcement surface)
- Root `README.md` — the `## Principles` section (root architectural principles P1–Pn that apply across all plugins in this collection)

**1.3 Build the principles and checkpoints list.** List every principle (root architectural + plugin-specific `[P1]`–`[Pn]`) with ID, short name, and one-line definition. Then list any checkpoints (`[C1]`–`[Cn]`) — these are cross-cutting quality checks applied to the target plugin (as distinct from this review plugin's own architectural principles). Print the combined list for the user.

**1.4 Map user-facing touchpoints.** From the directory listing, README, and any tool/command definitions visible in the triage read, identify every tool that produces user-visible output, every input collection point, every status/progress/error message, and any long-form text blocks. Print the touchpoint map for the user.

### Phase 2 — Analyze

Initialize `pass_number = 1`. Spawn all three analyst subagents. **When spawning each agent, include the resolved template path** so the agent knows where to load its criteria:

- **Principles Analyst** (`agents/principles-analyst.md`): provide the principles checklist, the list of implementation files to read, and the template path: `<CLAUDE_PLUGIN_ROOT>/templates/track-a-criteria.md`.
- **UX Analyst** (`agents/ux-analyst.md`): provide the touchpoint map, the list of user-facing code files to read, and the template path: `<CLAUDE_PLUGIN_ROOT>/templates/track-b-criteria.md`.
- **Docs Analyst** (`agents/docs-analyst.md`): provide the list of all documentation files, a directory listing of implementation files (NOT full source), and the template path: `<CLAUDE_PLUGIN_ROOT>/templates/track-c-criteria.md`.

Do NOT load those templates yourself — the subagents handle it.

On **Pass 2+**, consult `skills/scoped-reaudit/SKILL.md` to determine which tracks are affected by files changed in the previous pass. Only spawn affected subagents. Carry forward unchanged findings.

### Phase 3 — Present Findings

Load `<CLAUDE_PLUGIN_ROOT>/templates/pass-report.md` and format the unified report. Key rules:
- Lead with a severity-sorted summary of **open findings only**
- Upheld principles and clean touchpoints go in a compact roll-up line
- Only partially upheld, violated, and issue findings get full detail blocks
- Label the report with the pass number

On Pass 2+, focus on findings whose status changed plus any new findings.

### Phase 4 — Propose Changes

For each open finding, propose a concrete fix grouped by effort (quick wins, structural changes, design reconsiderations).

**Cross-track impact check**: for each proposal, load `<CLAUDE_PLUGIN_ROOT>/templates/cross-track-impact.md` and note which other tracks could be affected.

If zero open findings remain, skip to Phase 6. Present the proposals grouped by effort and ask the user which ones to proceed with. **STOP. Wait for explicit user approval before implementing.**

### Phase 5 — Implement and Re-audit

For each approved proposal:
1. State the plan — files, changes, gap closure, cross-track impact.
2. Implement the code change.
3. Update documentation — identify any docs referencing the modified behavior and update them in the same pass. A code change without a doc update is incomplete.
4. Verify — confirm code correctness AND doc accuracy.
5. Summarize in 1–2 sentences.

After all changes, increment `pass_number` and check the **pass budget**: if `pass_number > 3` and open findings remain, present the current state and ask the user whether to continue (with context budget warning), accept remaining gaps, or prioritize highest-impact items for one final pass. **STOP. Do NOT silently continue.** Otherwise, loop back to Phase 2 (scoped re-audit).

### Phase 6 — Convergence

The loop terminates when any condition is met:
1. **Zero open findings** — all clear.
2. **User signals satisfaction** — "stop" or "looks good".
3. **Pass budget reached** — user chose to accept remaining gaps.
4. **Plateau** — two identical consecutive passes. Report and ask how to proceed.
5. **Divergence** — more new findings than resolved. Report immediately, recommend reverting.

Load `<CLAUDE_PLUGIN_ROOT>/templates/final-report.md` and produce the final summary. Clear the session:

```bash
unset PLUGIN_REVIEW_ACTIVE
rm -f .claude/state/plugin-review-writes.json
echo "✓ Plugin review session ended"
```

## Hard Rules

- Do NOT read full plugin source files yourself — delegate to subagents.
- Do NOT refactor core logic, algorithms, or data flows in the target plugin.
- Do NOT add new features to the target plugin.
- Every implementation change MUST include corresponding doc updates.
- Do NOT generate reports outside the structured template formats.
- Prefer structured choice questions over open-ended questions at every decision point.
- Test changes by reviewing modified code paths before moving on.
- Respect the 3-pass budget. Surface the decision to the user, don't loop silently.
- Subagents analyze. You implement. Never cross this boundary.
