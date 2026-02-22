# Implementation Plan: autonomous-refactor Plugin

**Design doc:** `docs/plans/2026-02-21-autonomous-refactor-design.md`
**Branch:** `testing`
**Status:** Ready to execute

---

## Task 1 — Plugin scaffold

Create the plugin manifest, CHANGELOG, and README.

Files to create:
- `plugins/autonomous-refactor/.claude-plugin/plugin.json`
- `plugins/autonomous-refactor/CHANGELOG.md`
- `plugins/autonomous-refactor/README.md`

Add marketplace entry to `.claude-plugin/marketplace.json`.

Verification: `./scripts/validate-marketplace.sh` passes.

---

## Task 2 — Shell scripts

Create the three operational scripts. All must be `chmod +x`.

### `plugins/autonomous-refactor/scripts/run-tests.sh`

Detects language from target file extension or presence of `package.json` / `pyproject.toml`:
- TypeScript: reads `scripts.test` from `package.json`; falls back to `npx vitest run` then `npx jest --passWithNoTests`
- Python: runs `pytest <test_file> -v`
- Accepts `--worktree <path>` flag — if provided, `cd` to that path before running
- Outputs: exit 0 on all pass, exit 1 on any failure; prints pass/fail counts
- On missing test runner: print install instructions and exit 2

### `plugins/autonomous-refactor/scripts/measure-complexity.sh`

- Accepts `--language ts|py` and `--file <path>`
- TypeScript: tries `npx --yes complexity-report --format json <file>`; on failure prompts install and falls back to outputting `{"complexity": "ai-estimated", "file": "<path>"}`
- Python: tries `python3 -m radon cc <file> -j`; on failure prompts `pip install radon` and falls back
- Outputs JSON to stdout

### `plugins/autonomous-refactor/scripts/snapshot-metrics.sh`

- Accepts `--target <file>` (repeatable) and `--label <baseline|final>`
- For each target file: counts LOC via `wc -l`, invokes `measure-complexity.sh`
- Writes `{"label":"<label>","timestamp":"<iso>","files":[{"path":"...","loc":N,"complexity":...}]}` to `.claude/state/refactor-metrics-<label>.json`

Verification: Run each script with `--help` or no args; confirm they exit with usage message, not a crash.

---

## Task 3 — TypeScript metrics helper + package.json

Create `plugins/autonomous-refactor/src/metrics.ts`:
- CLI tool: `npx tsx plugins/autonomous-refactor/src/metrics.ts diff <before_file> <after_file>`
- Outputs structured diff summary: `{added_lines, removed_lines, changed_functions, summary_text}`
- Also supports: `npx tsx ... loc <file>` → `{file, loc, blank_lines, comment_lines}`
- No npm install required for basic use — uses only Node stdlib + `tsx`

Create minimal `plugins/autonomous-refactor/package.json`:
```json
{
  "name": "autonomous-refactor",
  "version": "0.1.0",
  "type": "module",
  "devDependencies": {
    "tsx": "^4.0.0",
    "typescript": "^5.0.0"
  }
}
```

Create `plugins/autonomous-refactor/tsconfig.json`:
- `"module": "ESNext"`, `"target": "ES2022"`, `"strict": true`

Verification: `npx tsx plugins/autonomous-refactor/src/metrics.ts loc <any_existing_file>` prints JSON without errors.

---

## Task 4 — Templates

### `plugins/autonomous-refactor/templates/test-generation-ts.md`

Instructions to `test-generator` for TypeScript:
- Use Vitest (import from `vitest`) with `describe`/`it`/`expect`
- Generate tests for every exported function and class method
- Cover: happy path, edge cases (null/undefined inputs, empty arrays), error throwing
- Mock external dependencies with `vi.mock()`
- Target test file location: `.claude/state/refactor-tests/<basename>.test.ts`

### `plugins/autonomous-refactor/templates/test-generation-py.md`

Instructions to `test-generator` for Python:
- Use pytest with fixtures and parametrize
- Generate `test_<module_name>.py` covering every public function
- Cover: happy path, type edge cases, exception handling
- Mock external I/O with `unittest.mock.patch`
- Target test file location: `.claude/state/refactor-tests/test_<basename>.py`

### `plugins/autonomous-refactor/templates/final-report.md`

Report template:
```
# Autonomous Refactor Report — <date>

## Target
<file list>

## Metrics Comparison

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Lines of Code | | | |
| Cyclomatic Complexity | | | |
| Principles Alignment Score | | | |

## Changes Applied (<N> of <total> opportunities)

| # | Opportunity | Priority | Result |
|---|-------------|----------|--------|
| 1 | ... | high | ✅ committed |
| 2 | ... | medium | ❌ reverted |

## Skipped Opportunities
<list with reason>

## Diff Summary
<structured diff output from metrics.ts>

## Convergence Reason
<All opportunities addressed | max_changes reached | oscillation detected>
```

Verification: Visual review only — templates are markdown prose, no execution.

---

## Task 5 — Agents

### `plugins/autonomous-refactor/agents/test-generator.md`

Frontmatter: `tools: Read, Glob, Grep, Bash`

Role: Generate a behavioural test suite for the target files and confirm it passes green.

Process:
1. Read each target file; identify all exported functions, classes, interfaces
2. Load the appropriate template (`test-generation-ts.md` or `test-generation-py.md`) based on language
3. Write test file to `.claude/state/refactor-tests/`
4. Run tests via `bash <PLUGIN_ROOT>/scripts/run-tests.sh`
5. If any tests fail: fix the tests (not the source) until green — retry up to 3 times
6. Return: `## Test-Generator Results\nTest file: <path>\nPassed: N | Failed: 0\nExported symbols covered: [list]`

### `plugins/autonomous-refactor/agents/principles-auditor.md`

Frontmatter: `tools: Read, Glob, Grep`

Role: Read target files and project README.md; produce a ranked list of refactoring opportunities tied to stated principles.

Process:
1. Read all target files in full
2. Read project `README.md` — extract any principles section (look for `## Principles`, `[P1]`, etc.)
3. For each principle: identify concrete violations or improvement opportunities in the code
4. Rank by: severity (breaking principle > partial > stylistic), then file size impact
5. Also compute a principles alignment score 0–100 (start at 100, deduct: high=15, medium=8, low=3)

Return JSON block:
```json
{
  "principles_score": 65,
  "opportunities": [
    {
      "id": 1,
      "description": "Extract shared validation logic into a utility",
      "priority": "high",
      "rationale": "Violates [P3] DRY — same validation pattern repeated in 3 functions",
      "principle_ref": "README.md#principles",
      "affected_files": ["src/auth.ts"]
    }
  ]
}
```

### `plugins/autonomous-refactor/agents/refactor-agent.md`

Frontmatter: `tools: Read, Write, Edit, Bash, Glob, Grep`

Role: Apply a single refactoring opportunity inside a git worktree. Does NOT run tests.

Process:
1. Read target files (at the worktree path provided by orchestrator)
2. Implement the change described in the opportunity object
3. Keep changes minimal — do not refactor adjacent code or address other opportunities
4. Return: `## Refactor-Agent Results\nOpportunity: <id> — <description>\nChanged: <file>:<line-range> — <what changed>\nFiles modified: [list]`

Hard constraints:
- Work only within the provided worktree path — NEVER modify files outside it
- Do not run the test suite — that is the orchestrator's responsibility
- If the change requires touching more than 3 files, report it as `OUT_OF_SCOPE` and return without making changes

### `plugins/autonomous-refactor/agents/report-generator.md`

Frontmatter: `tools: Read, Glob, Bash`

Role: Read the session state and metrics files; format the final report using `templates/final-report.md`.

Process:
1. Read `.claude/state/refactor-session.json`
2. Read `.claude/state/refactor-metrics-baseline.json` and `.claude/state/refactor-metrics-final.json`
3. Read `templates/final-report.md`
4. Populate the template with actual values
5. Run `npx tsx <PLUGIN_ROOT>/src/metrics.ts diff` for each changed file to get diff summary
6. Return the fully populated report markdown

Verification: Visual review of agent frontmatter and structure.

---

## Task 6 — Main orchestrator command

Create `plugins/autonomous-refactor/commands/refactor.md`.

This is the most complex file. Full content in implementation notes below.

### Frontmatter
```yaml
description: Test-driven autonomous refactoring against project design principles. Phases: Snapshot → Analyze → Refactor Loop → Report.
```

### Trigger
User says "refactor", "refactor <file>", "/refactor <file>", "autonomous refactor".

### Setup
```bash
mkdir -p .claude/state/refactor-tests .claude/worktrees
# Parse --max-changes=N (default 10)
MAX_CHANGES=10  # replace with extracted value
# Parse target files from invocation
echo '{"target_files":[],"language":"","test_file":"","baseline":null,"opportunities":[],"completed_changes":[],"reverted_changes":[],"max_changes":'"$MAX_CHANGES"',"current_worktree":null}' > .claude/state/refactor-session.json
echo "✓ Refactor session initialized (max changes: $MAX_CHANGES)"
echo $CLAUDE_PLUGIN_ROOT
```

### Phase 1 — Snapshot
1. If no target files specified: list `.ts`, `.tsx`, `.py` files in `src/` and use `AskUserQuestion` with bounded choices
2. Detect language from file extension
3. Spawn `test-generator` with: file list, language, plugin root path
4. If test-generator returns `Failed: >0`: surface error and stop — do not proceed with failing baseline
5. Run `bash $CLAUDE_PLUGIN_ROOT/scripts/snapshot-metrics.sh --label baseline` for each target
6. Update session state with baseline metrics

### Phase 2 — Analyze
1. Spawn `principles-auditor` with: target file list, README.md path
2. Extract `principles_score` and `opportunities` from auditor output
3. Update session state
4. Emit: `"Phase 2 complete: alignment score <N>/100, <N> opportunities identified"`

### Phase 3 — Refactor Loop
```
Read opportunities from state (status == "pending"), sorted by priority
total_changes = 0

while opportunities_pending and total_changes < max_changes:
  opportunity = next pending opportunity

  # Oscillation check
  revert_count = count of opportunity.id in reverted_changes
  if revert_count >= 2: mark "skipped_oscillation", continue

  # Worktree setup
  bash: git worktree add .claude/worktrees/refactor-{id} HEAD
  Update state: current_worktree = ".claude/worktrees/refactor-{id}"

  # Spawn refactor-agent
  if agent returns OUT_OF_SCOPE: mark "skipped_out_of_scope", delete worktree, continue

  # Run tests
  bash: $PLUGIN_ROOT/scripts/run-tests.sh --worktree .claude/worktrees/refactor-{id}

  if GREEN:
    bash: cd .claude/worktrees/refactor-{id} && git add -A && git commit -m "refactor: <opportunity.description>"
    bash: git worktree remove .claude/worktrees/refactor-{id}
    mark opportunity "completed"
    total_changes += 1
    emit: "✅ Change <N>: <description>"
    # Re-audit
    spawn principles-auditor → update opportunities list (add new, preserve completed)
  else (RED):
    bash: git worktree remove --force .claude/worktrees/refactor-{id}
    mark opportunity "reverted"
    emit: "❌ Reverted: <description> (tests failed)"

  Update state: current_worktree = null

emit convergence reason
```

### Phase 4 — Report
1. Run `bash $CLAUDE_PLUGIN_ROOT/scripts/snapshot-metrics.sh --label final` for each target
2. Spawn `report-generator`
3. Emit the full report
4. Clean up session:
```bash
rm -rf .claude/state/refactor-tests .claude/worktrees
rm -f .claude/state/refactor-session.json .claude/state/refactor-metrics-*.json
echo "✓ Refactor session complete"
```

### Hard Rules
- Do NOT read target source files directly — delegate to agents
- Do NOT run `AskUserQuestion` during Phase 3 — the loop is fully autonomous
- Always delete worktrees (with `--force` on failure) — never leave orphaned worktrees
- On git failure: surface raw error with `git worktree list` output and stop
- On test runner missing (exit 2): surface install instructions and stop

Verification: Read the command file and verify all phase sections are present and phase 3 loop logic is complete.

---

## Task 7 — Validate and smoke test

1. Run `./scripts/validate-marketplace.sh` — must pass
2. Verify file tree matches design: all 4 agents, 3 scripts, 3 templates, 1 command present
3. Run ShellCheck on all `.sh` files: `shellcheck plugins/autonomous-refactor/scripts/*.sh`
4. Commit all plugin files

---
