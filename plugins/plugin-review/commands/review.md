---
description: Review a Claude Code plugin for principles alignment, terminal UX quality, and documentation freshness via orchestrator–subagent analysis.
---

# Command: review

Review a Claude Code plugin for principles alignment, terminal UX quality, and documentation freshness.

## Trigger

User says "review", "review <plugin-name>", "plugin review", or "audit <plugin-name>".

## Behavior

You are the **orchestrator** for a multi-pass plugin review. You manage the convergence loop, present findings, collect user decisions, and implement changes. You delegate deep analysis to focused subagents — you never read full plugin source files yourself.

Parse `--max-passes=N` from the user's invocation using a regex match on `--max-passes=(\d+)`; default to 5 if not present. This replaces the old 3-pass budget as the loop safety limit.

**Before beginning, activate the doc-write-tracker hook:**

```bash
export PLUGIN_REVIEW_ACTIVE=1
mkdir -p .claude/state

# Parse --max-passes=N from invocation text (regex: --max-passes=(\d+)); default 5
MAX_PASSES=5  # replace with extracted value if user provided --max-passes=N

# State file tracks impl/doc writes AND pass_number so the counter survives context compaction.
echo "{\"impl_files\":[],\"doc_files\":[],\"pass_number\":1,\"max_passes\":$MAX_PASSES}" > .claude/state/plugin-review-writes.json
echo "{\"plugin\":\"\",\"max_passes\":$MAX_PASSES,\"current_pass\":1,\"assertions\":[],\"confidence\":{\"passed\":0,\"total\":0,\"score\":0.0}}" > .claude/state/review-assertions.json
echo "✓ Plugin review session activated (max passes: $MAX_PASSES)"
```

Store the plugin root path for template references:

```bash
echo $CLAUDE_PLUGIN_ROOT
```

You will need this path when spawning subagents (see Phase 2).

### Phase 1 — Setup

**1.1 Identify the plugin.** If the user didn't specify one, list available plugins and use `AskUserQuestion` with bounded options (up to 4). If there are more than 4 plugins, list the 3 most recently modified and add an "Other" option so the user can type the name. If you cannot enumerate plugins at all, prompt for the plugin path with a format hint: "Enter the plugin directory path (e.g. `plugins/my-plugin`)."

**1.2 Triage read.** Read only structural files — do NOT deep-read implementation source:
- The plugin's directory listing (understand scope and file count)
- `plugins/<n>/README.md` (principles, usage, architecture)
- `plugins/<n>/docs/DESIGN.md` if it exists (rationale, architectural intent)
- `plugins/<n>/hooks/hooks.json` if it exists (mechanical enforcement surface)
- Root `README.md` — the `## Principles` section (root architectural principles P1–Pn that apply across all plugins in this collection)

**Triage boundary**: the files listed above are the only files the orchestrator reads directly. `hooks.json` is treated as structural metadata — its schema reveals the enforcement surface without requiring implementation analysis. All other plugin files (commands, agents, skills, scripts, templates, src) must be read only by analyst subagents, not the orchestrator.

**1.3 Build the principles and checkpoints list.** List every principle (root architectural + plugin-specific `[P1]`–`[Pn]`) and every checkpoint (`[C1]`–`[Cn]`). Format as two markdown tables: one for root principles and one for plugin-specific principles, each with columns **ID | Name | Definition** (one line per row). Follow with a checkpoint table using the same format. Keep definitions to one line each.

**1.4 Map user-facing touchpoints.** From the directory listing, README, and any tool/command definitions visible in the triage read, identify every tool that produces user-visible output, every input collection point, every status/progress/error message, and any long-form text blocks. Format as a markdown table with columns: **# | Touchpoint | Type (Output/Input/Error/Progress) | Source File**. Keep one entry per row.

### Phase 2 — Analyze

Read `pass_number` from `.claude/state/plugin-review-writes.json` (the `pass_number` field; defaults to 1 if not present or file is missing). Spawn all three analyst subagents. **When spawning each agent, include the resolved template path** so the agent knows where to load its criteria:

- **Principles Analyst** (`agents/principles-analyst.md`): provide the principles checklist, the list of implementation files to read, and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-a-criteria.md`.
- **UX Analyst** (`agents/ux-analyst.md`): provide the touchpoint map, the list of user-facing code files to read, and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-b-criteria.md`.
- **Docs Analyst** (`agents/docs-analyst.md`): provide the list of all documentation files, a directory listing of implementation files (NOT full source), and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-c-criteria.md`.

Do NOT load those templates yourself — the subagents handle it.

On **Pass 2+**, consult `skills/scoped-reaudit/SKILL.md` to determine which tracks are affected by files changed in the previous pass. Only spawn affected subagents. Carry forward unchanged findings.

### Phase 2.5 — Assertion Collection

Each analyst's output contains an `## Assertions` block with a JSON array. Extract each array and merge all assertions into `.claude/state/review-assertions.json`:

1. Read `.claude/state/review-assertions.json`
2. Set `plugin` to the current plugin name and `current_pass` to the current pass number
3. For each assertion from each analyst, add it to the `assertions` array **only if its `id` is not already present** — this preserves existing pass/fail status for assertions whose tracks were not re-audited this pass, preventing the same assertion from being reset and re-evaluated when nothing relevant changed
4. Write the updated file

After merging, report the assertion count: "Pass N: N total assertions (N new, N carried forward)."

### Phase 3 — Present Findings

Load `$CLAUDE_PLUGIN_ROOT/templates/pass-report.md` and format the unified report. Key rules:
- Lead with a severity-sorted summary of **open findings only**
- Upheld principles and clean touchpoints go in a compact roll-up line
- Only partially upheld, violated, and issue findings get full detail blocks
- Label the report with the pass number

On Pass 2+, focus on findings whose status changed plus any new findings.

### Phase 4 — Auto-Implement All Proposals

For each open finding, propose and immediately implement a concrete fix. Do **not** use `AskUserQuestion` — all proposals are auto-implemented without human approval.

For each fix:
1. State the plan — files, changes, gap closure.
2. Load `$CLAUDE_PLUGIN_ROOT/templates/cross-track-impact.md` and note which other tracks are affected.
3. Implement the code change.
4. Update documentation — identify any docs referencing the modified behavior and update them in the same pass. A code change without a doc update is incomplete.
5. Summarize in 1–2 sentences.

If zero open findings remain, skip directly to Phase 5.5 (run assertions to verify).

### Phase 5 — Implement and Re-audit

For each approved proposal:
1. State the plan — files, changes, gap closure, cross-track impact.
2. Implement the code change.
3. Update documentation — identify any docs referencing the modified behavior and update them in the same pass. A code change without a doc update is incomplete.
4. Verify — confirm code correctness AND doc accuracy.
5. Summarize in 1–2 sentences.

After all changes, increment `pass_number` and persist it:

```bash
python3 -c "
import json
d = json.load(open('.claude/state/plugin-review-writes.json'))
d['pass_number'] = d.get('pass_number', 1) + 1
json.dump(d, open('.claude/state/plugin-review-writes.json', 'w'), indent=2)
"
```

### Phase 5.5 — Run Assertions

Run the full assertion suite:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/run-assertions.sh
```

Read the updated confidence score and failing assertions:

```bash
python3 -c "
import json
d = json.load(open('.claude/state/review-assertions.json'))
pct = int(d['confidence']['score'] * 100)
print(f'Confidence: {pct}% ({d[\"confidence\"][\"passed\"]}/{d[\"confidence\"][\"total\"]})')
fails = [a for a in d['assertions'] if a['status'] == 'fail']
for a in fails:
    print(f'  ❌ {a[\"id\"]} ({a[\"track\"]}): {a[\"description\"]}')
    if a.get('failure_output'):
        print(f'     {a[\"failure_output\"][:100]}')
"
```

**If confidence is 100%**, proceed to Phase 6 (convergence).

**If any assertions fail**, spawn the fix-agent (`agents/fix-agent.md`) with:
- The list of failing assertion objects (full JSON from `.claude/state/review-assertions.json` where `status == "fail"`)
- The analyst finding context for each assertion: include the relevant section from the Phase 3 pass report (the finding block that generated this assertion), so the fix-agent understands why the assertion was written
- The specific files likely needing changes per assertion

After the fix-agent returns, re-run assertions and update confidence:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/run-assertions.sh
```

Read and report the updated confidence.

**Check max-passes budget:**

```bash
python3 -c "
import json
writes = json.load(open('.claude/state/plugin-review-writes.json'))
review = json.load(open('.claude/state/review-assertions.json'))
pass_num = writes.get('pass_number', 1)
max_passes = writes.get('max_passes', 5)
pct = int(review['confidence']['score'] * 100)
print(f'Pass {pass_num}/{max_passes} — Confidence: {pct}%')
if pass_num >= max_passes and review['confidence']['score'] < 1.0:
    fails = [a['id'] for a in review['assertions'] if a['status'] == 'fail']
    print(f'BUDGET_REACHED: {len(fails)} assertions still failing: {fails}')
    print('Proceeding to Phase 6 (budget stop).')
"
```

If `pass_number >= max_passes` and confidence < 100%, proceed to Phase 6 with convergence reason "Budget reached."

Loop back to Phase 2 (scoped re-audit) only if ALL of these are true:
- `confidence < 100%` (assertions still failing)
- `pass_number < max_passes` (budget not yet reached)

Do not loop based on subjective "findings remain" — confidence is the sole convergence criterion.

### Phase 6 — Convergence

The loop terminates when any condition is met:
1. **Zero open findings** — all clear.
2. **User signals satisfaction** — "stop" or "looks good".
3. **Pass budget reached** — user chose to accept remaining gaps.
4. **Plateau** — two identical consecutive passes. Report and ask how to proceed.
5. **Divergence** — more new findings than resolved. Report immediately, recommend reverting.

Load `$CLAUDE_PLUGIN_ROOT/templates/final-report.md` and produce the final summary. Read the final confidence score and include it in the final report:

```bash
python3 -c "
import json
d = json.load(open('.claude/state/review-assertions.json'))
pct = int(d['confidence']['score'] * 100)
passed = d['confidence']['passed']
total = d['confidence']['total']
print(f'Final confidence: {pct}% ({passed}/{total} assertions passing)')
for a in d['assertions']:
    icon = '✅' if a['status'] == 'pass' else '❌'
    print(f'  {icon} {a[\"id\"]} ({a[\"track\"]}): {a[\"description\"]}')
"
```

Include this confidence score in the final report output (see `templates/final-report.md` format). Clear the session:

```bash
unset PLUGIN_REVIEW_ACTIVE
rm -f .claude/state/plugin-review-writes.json .claude/state/review-assertions.json
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
- Respect the `max_passes` budget (default 5, overridden by `--max-passes=N`). Report confidence when budget is reached; do not loop silently past the limit.
- Do NOT use `AskUserQuestion` during the review loop — the loop is fully automated from invocation to final report.
- Phase 4 is auto-implement. No human approval gates at any point in the loop.
- Subagents analyze. You implement. Never cross this boundary.
