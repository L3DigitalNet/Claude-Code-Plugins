---
description: Review a Claude Code plugin for principles alignment, terminal UX quality, and documentation freshness via orchestrator–subagent analysis.
---

# Command: review

Review a Claude Code plugin for principles alignment, terminal UX quality, and documentation freshness.

## Trigger

User says "review", "review <plugin-name>", "plugin review", or "audit <plugin-name>". Optionally includes `--autonomous` flag to enable autonomous convergence mode and/or `--max-passes=N` to override the pass budget.

## Behavior

You are the **orchestrator** for a multi-pass plugin review. You manage the convergence loop, present findings, collect user decisions, and implement changes. You delegate deep analysis to focused subagents — you never read full plugin source files yourself.

Parse `--max-passes=N` from the user's invocation using a regex match on `--max-passes=(\d+)`; default to 5 if not present.

Parse `--autonomous` from the user's invocation using a regex match on `--autonomous`; this flag activates autonomous convergence mode (tier classification, regression guard, build/test automation, convergence metrics). When not present, behavior is identical to prior versions.

**Before beginning, activate the doc-write-tracker hook:**

```bash
export PLUGIN_REVIEW_ACTIVE=1
mkdir -p .claude/state

# Parse --max-passes=N (regex: --max-passes=(\d+)); default 5
MAX_PASSES=5  # replace with extracted value if user provided --max-passes=N

# Parse --autonomous flag (regex: --autonomous); set AUTONOMOUS_MODE=1 if present
AUTONOMOUS_MODE=0  # replace with 1 if --autonomous is present

# Base state — always written
echo "{\"impl_files\":[],\"doc_files\":[],\"pass_number\":1,\"max_passes\":$MAX_PASSES}" > .claude/state/plugin-review-writes.json
echo "{\"plugin\":\"\",\"max_passes\":$MAX_PASSES,\"current_pass\":1,\"assertions\":[],\"confidence\":{\"passed\":0,\"total\":0,\"score\":0.0}}" > .claude/state/review-assertions.json

# Autonomous mode: write extended state with metrics fields
if [ "$AUTONOMOUS_MODE" = "1" ]; then
  START_TIME=$(python3 -c "from datetime import datetime, timezone; print(datetime.now(timezone.utc).isoformat())")
  python3 -c "
import json, sys
d = json.load(open('.claude/state/plugin-review-writes.json'))
d['mode'] = 'autonomous'
d['start_time'] = sys.argv[1]
d['tier_counts'] = {'t1': 0, 't2': 0, 't3': 0}
d['fixed_findings'] = []
d['build_test_failures'] = 0
d['regression_guard_regressions'] = 0
json.dump(d, open('.claude/state/plugin-review-writes.json', 'w'), indent=2)
" "$START_TIME"
  echo "✓ Plugin review session activated (max passes: $MAX_PASSES, mode: autonomous)"
else
  echo "✓ Plugin review session activated (max passes: $MAX_PASSES)"
fi
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

Read `pass_number` from `.claude/state/plugin-review-writes.json` (the `pass_number` field; defaults to 1 if not present or file is missing). Before spawning subagents, emit a brief progress signal: `"Pass <N>: spawning analyst subagents..."`. Spawn all three analyst subagents. **When spawning each agent, include the resolved template path** so the agent knows where to load its criteria:

- **Principles Analyst** (`agents/principles-analyst.md`): provide the principles checklist, the list of implementation files to read, and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-a-criteria.md`.
- **UX Analyst** (`agents/ux-analyst.md`): provide the touchpoint map, the list of user-facing code files to read, and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-b-criteria.md`.
- **Docs Analyst** (`agents/docs-analyst.md`): provide the list of all documentation files, a directory listing of implementation files (NOT full source), and the template path: `$CLAUDE_PLUGIN_ROOT/templates/track-c-criteria.md`.

Do NOT load those templates yourself — the subagents handle it.

On **Pass 2+**, consult `skills/scoped-reaudit/SKILL.md` to determine which tracks are affected by files changed in the previous pass. Only spawn affected subagents. Carry forward unchanged findings.

**[AUTONOMOUS MODE, PASS 2+] Regression guard:** Consult `skills/scoped-reaudit/SKILL.md` — Regression Guard Exception section — which states the regression guard always runs on Pass 2+ in autonomous mode regardless of which files changed. Spawn `agents/regression-guard.md` in parallel with the analyst subagents. Provide:
- The `fixed_findings` array from `.claude/state/plugin-review-writes.json`
- For each entry in `fixed_findings`, the current content of its `files_affected` paths

If `fixed_findings` is empty (no findings have been fixed yet), skip the regression guard this pass.

### Phase 2.5 — Assertion Collection

Each analyst's output contains an `## Assertions` block with a JSON array. Extract each array and merge all assertions into `.claude/state/review-assertions.json`:

1. Read `.claude/state/review-assertions.json`
2. Set `plugin` to the current plugin name and `current_pass` to the current pass number
3. For each assertion from each analyst, add it to the `assertions` array **only if its `id` is not already present** — this preserves existing pass/fail status for assertions whose tracks were not re-audited this pass, preventing the same assertion from being reset and re-evaluated when nothing relevant changed
4. Write the updated file

After merging, report the assertion count: "Pass N: N total assertions (N new, N carried forward)."

**[AUTONOMOUS MODE, PASS 2+] Process regression guard results:** Read the `### Summary` line from the regression guard output (format: "N findings checked: N holding ✅, N regressed ❌"). Extract the regressed count and update state:

```bash
python3 -c "
import json, sys
regressed = int(sys.argv[1])  # extracted from regression guard Summary line
d = json.load(open('.claude/state/plugin-review-writes.json'))
d['regression_guard_regressions'] = d.get('regression_guard_regressions', 0) + regressed
json.dump(d, open('.claude/state/plugin-review-writes.json', 'w'), indent=2)
if regressed > 0:
    print(f'⚠️ Regression guard: {regressed} regression(s) detected — will extend convergence loop')
else:
    print('✅ Regression guard: all previously-fixed findings holding')
" <N>  # replace <N> with actual regressed count from guard output
```

Include the regression guard summary in the Phase 3 pass report under `### Regression Guard` (Pass 2+ format).

### Phase 3 — Present Findings

Load `$CLAUDE_PLUGIN_ROOT/templates/pass-report.md` and format the unified report. Key rules:
- Lead with a severity-sorted summary of **open findings only**
- Upheld principles and clean touchpoints go in a compact roll-up line
- Only partially upheld, violated, and issue findings get full detail blocks
- Label the report with the pass number

On Pass 2+, focus on findings whose status changed plus any new findings.

### Phase 4 — Auto-Implement All Proposals

For each open finding, propose and immediately implement a concrete fix. Do **not** use `AskUserQuestion` — all proposals are auto-implemented without human approval.

**[AUTONOMOUS MODE ONLY] Tier classification:** Before implementing each finding, assign it a tier using this decision table (evaluate top-to-bottom; first match wins):

| Priority | Tier | Condition |
|----------|------|-----------|
| 1 | 3 | Finding modifies command output contract, agent `tools:` frontmatter, state file schema, or hook trigger conditions |
| 2 | 3 | Track A; finding type "Violated"; affects `commands/` or `agents/` files |
| 3 | 2 | Description keywords: "error handling", "validation", "missing check", "test gap", "boundary", "exception" |
| 4 | 1 | Track C finding (documentation) |
| 5 | 1 | Description keywords: "formatting", "comment", "type annotation", "import ordering", "whitespace", "style" |
| 6 | 2 | Default (unclassified) |

All tiers are auto-fixed without a human gate. Tier affects only logging and metrics:
- **Tier 1**: implement silently; update `tier_counts.t1` in state
- **Tier 2**: implement; print one-line summary after fix; update `tier_counts.t2`
- **Tier 3**: implement; print `⚠️ Tier 3 (architectural): <finding_id> — <brief change summary>`; update `tier_counts.t3`

For each fix:
1. **[AUTONOMOUS MODE]** Assign tier per table above.
2. State the plan — files, changes, gap closure.
3. Load `$CLAUDE_PLUGIN_ROOT/templates/cross-track-impact.md` and note which other tracks are affected.
4. Implement the code change.
5. Update documentation — identify any docs referencing the modified behavior and update them in the same pass. A code change without a doc update is incomplete.
6. Summarize in 1–2 sentences.
7. **[AUTONOMOUS MODE]** Update state: append `{finding_id, description, files_affected, fix_summary, pass_fixed, tier}` to `fixed_findings`; increment `tier_counts.tN`:

```bash
python3 -c "
import json, sys
# Args: finding_id description files_affected(comma-sep) fix_summary pass_fixed tier
finding_id, desc, files_str, fix_sum, pass_fixed, tier_str = sys.argv[1:]
d = json.load(open('.claude/state/plugin-review-writes.json'))
d.setdefault('fixed_findings', []).append({
    'finding_id': finding_id,
    'description': desc,
    'files_affected': [f.strip() for f in files_str.split(',') if f.strip()],
    'fix_summary': fix_sum,
    'pass_fixed': int(pass_fixed),
    'tier': int(tier_str),
})
tc = d.setdefault('tier_counts', {'t1': 0, 't2': 0, 't3': 0})
tc[f't{tier_str}'] = tc.get(f't{tier_str}', 0) + 1
json.dump(d, open('.claude/state/plugin-review-writes.json', 'w'), indent=2)
" \"\$FINDING_ID\" \"\$DESC\" \"\$FILES\" \"\$FIX_SUM\" \"\$PASS_NUM\" \"\$TIER\"
```

If zero open findings remain, increment `pass_number` and proceed directly to Phase 4.5 (autonomous mode) or Phase 5.5 (interactive mode).

### Phase 4.5 — Build/Test Validation [AUTONOMOUS MODE ONLY]

Skip this phase entirely in interactive mode.

After Phase 4 implementation, run build and test suites for both the target plugin and plugin-review itself to verify no regressions were introduced.

**Step 1: Discover commands.** Run discovery for both plugins:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/discover-test-commands.sh <target-plugin-path>
bash $CLAUDE_PLUGIN_ROOT/scripts/discover-test-commands.sh $CLAUDE_PLUGIN_ROOT
```

If both return empty arrays (`[]`), skip the rest of this phase: emit "Build/test: no commands discovered — skipping" and continue to Phase 5.

**Step 2: Run build/test for target plugin:**

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/run-build-test.sh <target-plugin-path>
TARGET_EXIT=$?
```

**Step 3: Run build/test for plugin-review self-check:**

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/run-build-test.sh $CLAUDE_PLUGIN_ROOT
SELF_EXIT=$?
```

**Step 4: If all pass** (`TARGET_EXIT=0` and `SELF_EXIT=0`), emit "Build/test: all pass ✅" and continue to Phase 5.

**Step 5: If any fail**, spawn `build-fix-agent` (`agents/build-fix-agent.md`) with:
- The full JSON output from `run-build-test.sh` (both runs)
- The list of files modified during Phase 4 (from `impl_files` in state)

After the build-fix-agent returns, re-run the failed suites once:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/run-build-test.sh <target-plugin-path>
bash $CLAUDE_PLUGIN_ROOT/scripts/run-build-test.sh $CLAUDE_PLUGIN_ROOT
```

**Step 6: Update state** regardless of final outcome:

```bash
python3 -c "
import json, sys
exit_codes = list(map(int, sys.argv[1:]))
d = json.load(open('.claude/state/plugin-review-writes.json'))
# Count failures (non-zero exit codes) as failures to track
failures = sum(1 for c in exit_codes if c != 0)
d['build_test_failures'] = d.get('build_test_failures', 0) + failures
json.dump(d, open('.claude/state/plugin-review-writes.json', 'w'), indent=2)
" \$ORIGINAL_TARGET_EXIT \$ORIGINAL_SELF_EXIT
```

**Step 7: Report.** If tests still fail after fix-agent: emit "⚠️ Build/test: N command(s) still failing after fix attempt — proceeding with unresolved failures noted." Do not block convergence on unresolvable build failures — note them in the final report.

### Phase 5 — Persist Pass Counter

Phase 4 has already implemented all fixes. After verifying code and documentation changes look correct, increment `pass_number` and persist it:

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
        print(f'     {a[\"failure_output\"][:200]}')
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

**[AUTONOMOUS MODE]** Additional convergence condition: also loop back if the regression guard reported any regressions in Phase 2.5, even if `confidence == 100%`. A regression means a previously-fixed finding has been re-broken — the loop must continue until both confidence is 100% AND regression guard reports zero regressions.

```bash
python3 -c "
import json
writes = json.load(open('.claude/state/plugin-review-writes.json'))
review = json.load(open('.claude/state/review-assertions.json'))
pass_num = writes.get('pass_number', 1)
max_passes = writes.get('max_passes', 5)
pct = int(review['confidence']['score'] * 100)
regressions = writes.get('regression_guard_regressions', 0)
mode = writes.get('mode', 'interactive')
print(f'Pass {pass_num}/{max_passes} — Confidence: {pct}% — Regressions: {regressions}')
if pass_num >= max_passes:
    fails = [a['id'] for a in review['assertions'] if a['status'] == 'fail']
    print(f'BUDGET_REACHED: {len(fails)} assertions failing, {regressions} regressions')
    print('Proceeding to Phase 6 (budget stop).')
elif mode == 'autonomous' and regressions > 0 and review['confidence']['score'] >= 1.0:
    print('REGRESSION_LOOP: confidence 100% but regressions detected — continuing loop')
"
```

Do not loop based on subjective "findings remain" — confidence plus regression guard status are the convergence criteria.

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

Include this confidence score in the final report output (see `templates/final-report.md` format).

**[AUTONOMOUS MODE] Convergence metrics:** Load `$CLAUDE_PLUGIN_ROOT/templates/convergence-metrics.md` and compute values from state. Append the formatted metrics section to the final report:

```bash
python3 -c "
import json
from datetime import datetime, timezone

writes = json.load(open('.claude/state/plugin-review-writes.json'))
review = json.load(open('.claude/state/review-assertions.json'))

start_time = writes.get('start_time', '')
if start_time:
    start_dt = datetime.fromisoformat(start_time)
    end_dt = datetime.now(timezone.utc)
    elapsed_s = int((end_dt - start_dt).total_seconds())
    elapsed = f'{elapsed_s // 60}m {elapsed_s % 60}s' if elapsed_s >= 60 else f'{elapsed_s}s'
else:
    elapsed = 'unknown'

tc = writes.get('tier_counts', {'t1': 0, 't2': 0, 't3': 0})
ff = writes.get('fixed_findings', [])
regressions = writes.get('regression_guard_regressions', 0)
build_fail = writes.get('build_test_failures', 0)
pass_num = writes.get('pass_number', 1)

total_findings = len(review.get('assertions', []))
resolved = sum(1 for a in review.get('assertions', []) if a.get('status') == 'pass')
open_findings = total_findings - resolved

print(f'''### Convergence Metrics
- Mode: autonomous
- Total passes: {pass_num}  |  Time to convergence: {elapsed}
- Total findings discovered: {total_findings}  →  {resolved} resolved  |  {open_findings} open (accepted gaps)
- Tier 1 auto-fixed (docs/formatting):  {tc.get('t1', 0)}
- Tier 2 auto-fixed (error handling/validation):  {tc.get('t2', 0)}
- Tier 3 auto-fixed (architectural/behavioral):  {tc.get('t3', 0)}
- Regressions caught by guard: {regressions}
- Build/test failures encountered: {build_fail}''')
"
```

Clear the session:

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
- Phase 4 is auto-implement. No human approval gates at any point in the loop. In autonomous mode, tier classification affects logging and metrics only — all tiers are auto-fixed.
- Subagents analyze. You implement. Never cross this boundary.
- In autonomous mode, convergence requires BOTH assertion confidence = 100% AND regression guard reports zero regressions. Either condition alone is insufficient.
- Phase 4.5 (build/test) is autonomous-mode-only. Do not run it in interactive mode.
- `build-fix-agent` is spawned at most once per pass — do not loop the fix attempt.
