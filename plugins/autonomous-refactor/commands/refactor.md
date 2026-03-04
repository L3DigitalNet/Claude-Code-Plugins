---
description: Test-driven autonomous refactoring against project design principles. Captures a green test baseline, audits code against README.md principles, applies changes in git worktree isolation (reverts on test failure), and produces a before/after report — entirely without human input in the loop.
---

# Command: refactor

Run a 4-phase autonomous refactoring session on one or more source files.

## Trigger

User says "refactor", "refactor `<file>`", "/refactor `<file>`", "autonomous refactor", or "refactor the `<module>` module".

## Setup

Parse arguments from the invocation:
- `--max-changes=N` → integer, default 10
- `--dry-run` → boolean, default false. When true: run Phases 1 and 2 only, display ranked opportunities, then exit without creating worktrees or applying any changes.
- Remaining non-flag arguments → target file paths

Store the plugin root path for template and script references:
```bash
echo $CLAUDE_PLUGIN_ROOT
```

Initialise the session state and working directories:
```bash
mkdir -p .claude/state/refactor-tests .claude/worktrees

MAX_CHANGES=10  # replace with --max-changes=N value if provided
DRY_RUN=false   # set to true if --dry-run was provided
# Convert bash booleans to Python-compatible values before passing to python3
PY_DRY_RUN=$( [[ "$DRY_RUN" == "true" ]] && echo "True" || echo "False" )

python3 -c "
import json
state = {
    'target_files': [],
    'language': '',
    'test_file': '',
    'baseline': None,
    'final': None,
    'opportunities': [],
    'completed_changes': [],
    'reverted_changes': [],
    'skipped_changes': [],
    'convergence_reason': '',
    'max_changes': $MAX_CHANGES,
    'dry_run': $PY_DRY_RUN,
    'current_worktree': None
}
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
"
echo "✓ Refactor session initialised (max changes: $MAX_CHANGES)"
```

---

## Phase 1 — Snapshot

**1.1 Resolve target files.**

If no target files were specified: list `.ts`, `.tsx`, and `.py` files under `src/` (or the project root if no `src/` exists). Use `AskUserQuestion` with up to 4 bounded choices. If more than 4 candidates exist, list the 3 most recently modified and add an "Other" option.

Once targets are confirmed, detect language from file extension:
- `.ts` or `.tsx` → `typescript`
- `.py` → `python`
- Mixed → use `AskUserQuestion` to confirm which language the test runner should target

Update session state with `target_files` and `language`.

**1.2 Spawn test-generator.**

Spawn the `agents/test-generator` agent with:
- The resolved target file list
- The detected language
- The PLUGIN_ROOT path
- The appropriate template path: `$CLAUDE_PLUGIN_ROOT/templates/test-generation-ts.md` (TypeScript) or `$CLAUDE_PLUGIN_ROOT/templates/test-generation-py.md` (Python)

**1.3 Check baseline result.**

Parse the agent output:
```bash
# Extract test file path from agent output (looks for "Test file: <path>")
TEST_FILE=$(echo "<agent-output>" | grep "^Test file:" | sed 's/Test file: //')
BASELINE_FAILED=$(echo "<agent-output>" | grep -c "BASELINE FAILURE" || true)
```

If `BASELINE FAILURE` is present: emit the agent output verbatim and **stop**. Do not proceed. The user must resolve the baseline before refactoring can begin.

Update session state:
```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
state['test_file'] = '<TEST_FILE>'
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
```

**1.4 Capture baseline metrics.**

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/snapshot-metrics.sh \
  --label baseline \
  --language <language> \
  $(for f in <target_files>; do echo "--target $f"; done)
```

Read the output file and update session state:
```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
metrics = json.load(open('.claude/state/refactor-metrics-baseline.json'))
state['baseline'] = {'loc': metrics['total_loc'], 'complexity': metrics['avg_complexity']}
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
```

Emit: `"Phase 1 complete: baseline captured (LOC: N, complexity: N)"`

---

## Phase 2 — Analyze

**2.1 Spawn principles-auditor.**

Spawn the `agents/principles-auditor` agent with:
- The target file list
- Path to project `README.md` (project root)
- Instruction: this is the initial audit (no previous opportunities to carry forward)

**2.2 Extract and store opportunities.**

The agent returns a fenced JSON block. Extract it:
```bash
python3 -c "
import json, re, sys
output = open('/dev/stdin').read()
# Extract fenced JSON block
match = re.search(r'\`\`\`json\s*(.*?)\`\`\`', output, re.DOTALL)
if not match:
    print('ERROR: No JSON block in auditor output', file=sys.stderr)
    sys.exit(1)
data = json.loads(match.group(1))
state = json.load(open('.claude/state/refactor-session.json'))
state['opportunities'] = data['opportunities']
state['baseline']['principles_score'] = data['principles_score']
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
print(f'Opportunities: {len(data[\"opportunities\"])} | Score: {data[\"principles_score\"]}/100')
" <<'EOF'
<AGENT_OUTPUT>
EOF
```

Emit: `"Phase 2 complete: alignment score N/100, N opportunities identified"`

List the opportunities as a numbered table:
```
| # | Priority | Description |
|---|----------|-------------|
| 1 | 🔴 high   | Extract shared validation logic |
| 2 | 🟡 medium | Add error handling to async calls |
```

---

## Dry-Run Exit

**If `--dry-run` was specified**, stop here. Do not proceed to Phase 3.

Display:

```
Dry-run complete. N opportunities identified (max changes: M).

Ranked opportunities:
  1. [HIGH]   <file>:<line>: <opportunity description>
  2. [MEDIUM] <file>:<line>: <opportunity description>
  ...

No changes applied. Run without --dry-run to execute.
```

Exit cleanly after displaying this output. Do NOT proceed to Phase 3 or Phase 4.

---

## Phase 3 — Refactor Loop

**This phase runs fully autonomously. Do NOT use `AskUserQuestion` at any point in this loop.**

Emit: `"Phase 3: starting refactor loop (max changes: N)..."`

Read the session state. Process opportunities in order (high → medium → low). Track `total_changes = 0`.

For each opportunity with `status == "pending"`:

### 3.1 Oscillation check

```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
opp_id = <current_opportunity_id>
revert_count = sum(1 for c in state['reverted_changes'] if c['id'] == opp_id)
if revert_count >= 2:
    print('OSCILLATING')
```

If `OSCILLATING`: mark the opportunity `skipped_oscillation`, emit `"⏭ Skipped (oscillation): <description>"`, continue to next opportunity.

### 3.2 Worktree setup

```bash
WORKTREE_PATH=".claude/worktrees/refactor-${OPP_ID}"
git worktree add "$WORKTREE_PATH" HEAD
```

If `git worktree add` fails (non-zero exit): emit the raw git error output and **stop the entire session**. Surface: `"Git worktree creation failed. Run 'git worktree list' to inspect current state."` and proceed directly to Phase 4.

Update session state: `current_worktree = "$WORKTREE_PATH"`

### 3.3 Spawn refactor-agent

Spawn the `agents/refactor-agent` agent with:
- The full opportunity object (id, description, priority, rationale, affected_files)
- The worktree path: `$WORKTREE_PATH`
- The PLUGIN_ROOT path

### 3.4 Check for OUT_OF_SCOPE

Parse the agent output:
```bash
OUT_OF_SCOPE=$(echo "<agent-output>" | grep -c "OUT_OF_SCOPE" || true)
```

If `OUT_OF_SCOPE`:
```bash
git worktree remove --force "$WORKTREE_PATH"
```
Mark opportunity `skipped_out_of_scope`. Emit `"⏭ Skipped (out of scope): <description>"`. Update `current_worktree = null`. Continue to next opportunity.

### 3.5 Run tests

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/run-tests.sh \
  --worktree "$WORKTREE_PATH" \
  --test-file ".claude/state/refactor-tests/<test-basename>"
TEST_EXIT=$?
```

If test runner is missing (exit 2): surface the install instructions printed by `run-tests.sh`, clean up worktree, and **stop the loop**. Proceed to Phase 4 with the changes made so far.

### 3.6 GREEN path — commit and record

```bash
(cd "$WORKTREE_PATH" && git add -A && git commit -m "refactor: <opportunity-description>")
git worktree remove "$WORKTREE_PATH"
```

Update session state:
```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
opp = next(o for o in state['opportunities'] if o['id'] == OPP_ID)
opp['status'] = 'completed'
state['completed_changes'].append({'id': OPP_ID, 'description': opp['description']})
state['current_worktree'] = None
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
```

Emit: `"✅ Change N: <description>"`

Increment `total_changes`. Check if `total_changes >= max_changes` — if so, set `convergence_reason = "max_changes reached (N)"` and exit the loop.

**Re-audit:** Spawn `agents/principles-auditor` again with:
- The target file list
- Project `README.md` path
- The previous opportunities list (so the agent can assign new IDs and skip completed/skipped items)

Extract the JSON block and merge new opportunities into session state (append only; do not replace existing entries).

### 3.7 RED path — revert and record

```bash
git worktree remove --force "$WORKTREE_PATH"
```

Update session state:
```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
opp = next(o for o in state['opportunities'] if o['id'] == OPP_ID)
opp['status'] = 'reverted'
state['reverted_changes'].append({'id': OPP_ID, 'description': opp['description']})
state['current_worktree'] = None
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
```

Emit: `"❌ Reverted: <description> (tests failed)"`

Continue to next opportunity. Do NOT re-audit after a revert (no code changed).

### 3.8 Loop end

When all opportunities are processed (or `max_changes` reached), determine `convergence_reason`:
- All pending opportunities addressed → `"All opportunities addressed"`
- `total_changes >= max_changes` → `"max_changes reached (N)"`
- Loop exited due to missing test runner → `"Test runner unavailable — stopped after N changes"`
- Loop exited due to git worktree failure → `"Git failure — stopped after N changes"`

```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
state['convergence_reason'] = '<REASON>'
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
```

Emit: `"Phase 3 complete: <convergence_reason>"`

---

## Phase 4 — Report

**4.1 Capture final metrics.**

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/snapshot-metrics.sh \
  --label final \
  --language <language> \
  $(for f in <target_files>; do echo "--target $f"; done)
```

Read final metrics and update session state:
```python3
import json
state = json.load(open('.claude/state/refactor-session.json'))
metrics = json.load(open('.claude/state/refactor-metrics-final.json'))
state['final'] = {'loc': metrics['total_loc'], 'complexity': metrics['avg_complexity']}
# principles_score from last successful re-audit (or baseline if no changes succeeded)
json.dump(state, open('.claude/state/refactor-session.json', 'w'), indent=2)
```

**4.2 Spawn report-generator.**

Spawn the `agents/report-generator` agent with:
- Session state path: `.claude/state/refactor-session.json`
- Baseline metrics path: `.claude/state/refactor-metrics-baseline.json`
- Final metrics path: `.claude/state/refactor-metrics-final.json`
- Template path: `$CLAUDE_PLUGIN_ROOT/templates/final-report.md`
- PLUGIN_ROOT path

**4.3 Emit the report.**

Output the full report returned by the agent.

**4.4 Clean up session.**

```bash
rm -rf .claude/state/refactor-tests .claude/worktrees
rm -f .claude/state/refactor-session.json \
      .claude/state/refactor-metrics-baseline.json \
      .claude/state/refactor-metrics-final.json
echo "✓ Refactor session complete"
```

---

## Hard Rules

- Do NOT read target source files yourself — delegate to agents
- Do NOT call `AskUserQuestion` during Phase 3 — the loop is fully autonomous
- Always remove worktrees after use; never leave orphaned worktrees
- On `git worktree add` failure: surface raw output and stop — do not attempt workarounds
- On test runner missing (exit 2 from `run-tests.sh`): surface install instructions and stop — do not silently skip tests
- If `BASELINE FAILURE` from test-generator: stop immediately and tell the user to fix the baseline before re-running
- Orphaned worktrees from a previous crashed session: if `.claude/worktrees/` contains directories, run `git worktree list` to inspect, then `git worktree remove --force` to clean up before starting Phase 3
- The final `rm -rf .claude/worktrees` in Phase 4 is the safety net — orphaned worktrees are cleaned regardless of loop outcome
