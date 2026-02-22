# Implementation Plan: Autonomous Convergence Mode

Reference design: `docs/plans/2026-02-21-autonomous-mode-design.md`

## Tasks

### Task 1: Create `agents/regression-guard.md`
Read-only 4th analyst subagent. Receives previously-fixed findings + relevant current files; returns narrative re-check report with holding/regressed status per finding.

Steps:
1. Write `plugins/plugin-review/agents/regression-guard.md`
2. Frontmatter: `tools: Read, Grep, Glob`
3. Include architectural-context comment matching existing agent pattern
4. Input contract: list of `{finding_id, description, files_affected, fix_summary}` objects
5. Process: for each finding, read affected files, verify fix is still intact
6. Output format: `## Regression Guard — Pass <N>` → `### <finding_id>: <holding|regressed>` → one-line evidence
7. Summary line: "N findings checked: N holding, N regressed"

Verification: `grep "tools: Read, Grep, Glob" plugins/plugin-review/agents/regression-guard.md`

---

### Task 2: Create `agents/build-fix-agent.md`
Write-capable subagent for test failure resolution. Mirrors fix-agent pattern but targets build/test failures.

Steps:
1. Write `plugins/plugin-review/agents/build-fix-agent.md`
2. Frontmatter: `tools: Read, Grep, Glob, Edit, Write`
3. Include architectural-context comment
4. Input contract: failing test output, test command, recently-modified files
5. Process: minimal fix to restore tests; escalate if architectural issue
6. Output format matches fix-agent pattern: `## Build-Fix Results — Pass <N>` with per-fix summaries

Verification: `grep "tools: Read, Grep, Glob, Edit, Write" plugins/plugin-review/agents/build-fix-agent.md`

---

### Task 3: Create `scripts/discover-test-commands.sh`
Probes a plugin directory for build and test commands.

Steps:
1. Write `plugins/plugin-review/scripts/discover-test-commands.sh`
2. Accept `$1` = plugin directory path
3. Check for: `package.json` scripts.build/test → npm commands
4. Check for: `Makefile` with build/test targets → make commands
5. Check for: `pytest.ini` or `pyproject.toml` [tool.pytest.ini_options] → pytest command
6. Check for: `scripts/test*.sh` → enumerate each
7. Always add plugin-review self-check if plugin path == `plugins/plugin-review`
8. Output JSON array to stdout: `[{"type": "build|test", "command": "...", "cwd": "..."}]`
9. Exit 0 even if nothing found (empty array)
10. Make executable: `chmod +x`

Verification: `bash plugins/plugin-review/scripts/discover-test-commands.sh plugins/plugin-review | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok', len(d), 'commands')"`

---

### Task 4: Create `scripts/run-build-test.sh`
Runs discovered commands, captures structured results.

Steps:
1. Write `plugins/plugin-review/scripts/run-build-test.sh`
2. Accept `$1` = plugin directory path (discovers commands internally)
3. Run `discover-test-commands.sh $1` to get command list
4. For each command: run with timeout, capture stdout+stderr (limit 2000 chars), record exit code
5. Determine overall pass/fail
6. Output JSON to stdout: `{"pass": bool, "results": [{"type":..., "command":..., "exit_code":..., "output":"..."}]}`
7. Print human-readable summary to stderr for orchestrator embedding
8. Exit 0 if all pass, exit 1 if any fail, exit 2 on script error
9. Make executable: `chmod +x`

Verification: `bash plugins/plugin-review/scripts/run-build-test.sh plugins/plugin-review && echo "self-test passed"`

---

### Task 5: Create `templates/convergence-metrics.md`
Final report metrics template.

Steps:
1. Write `plugins/plugin-review/templates/convergence-metrics.md`
2. Include architectural-context comment: loaded only by review.md Phase 6 in autonomous mode
3. Template shows: Mode, Total passes, Time, Total findings, Tier 1/2/3 counts, Regressions caught, Build/test failures
4. Include placeholder format that the orchestrator fills in from state

Verification: `test -f plugins/plugin-review/templates/convergence-metrics.md`

---

### Task 6: Update `templates/pass-report.md`
Add Tier column and Regression Guard section.

Steps:
1. Read the current file
2. Add `Tier1 | Tier2 | Tier3` columns to the Convergence table in both Pass 1 and Pass 2+ formats
3. Add `### Regression Guard` section after `### Convergence` in Pass 2+ format
4. Update architectural-context comment to note new columns and cross-file dependency with final-report.md
5. Ensure column names are consistent between Pass 1 and Pass 2+ tables

Verification: `grep "Tier1" plugins/plugin-review/templates/pass-report.md`

---

### Task 7: Update `templates/final-report.md`
Add Convergence Metrics section.

Steps:
1. Read the current file
2. Add `### Convergence Metrics` section after `### Files Modified`
3. Section should be marked as autonomous-mode-only with a note
4. Format matches convergence-metrics.md template output
5. Update architectural-context comment to note the new section and its state file dependencies

Verification: `grep "Convergence Metrics" plugins/plugin-review/templates/final-report.md`

---

### Task 8: Update `skills/scoped-reaudit/SKILL.md`
Add regression-guard track mapping.

Steps:
1. Read the current file
2. Add a new section: `## Regression Guard Exception`
3. Document: regression guard is autonomous-mode-only; always spawned on Pass 2+ regardless of which files changed; not subject to the A/B/C track mapping
4. Update the File-to-Track Mapping section to note this exception
5. Update architectural-context comment

Verification: `grep "regression-guard" plugins/plugin-review/skills/scoped-reaudit/SKILL.md`

---

### Task 9: Update `commands/review.md` — Phase 1 and State Schema
Add `--autonomous` flag parsing and extended state initialization.

Steps:
1. Read current review.md
2. In the opening setup block, add `--autonomous` regex parsing (alongside `--max-passes=N`)
3. Add a conditional branch: if `--autonomous` set, write extended state JSON with `mode`, `start_time`, `tier_counts`, `fixed_findings`, `build_test_failures`, `regression_guard_regressions`
4. Update the max-passes bash echo to include mode in the activation message
5. Keep non-autonomous path identical to current

Verification: `grep "\-\-autonomous" plugins/plugin-review/commands/review.md`

---

### Task 10: Update `commands/review.md` — Phase 4 Tier Classification
Add tier decision table and per-finding tier logging.

Steps:
1. After Phase 3 (Present Findings), add tier classification instructions
2. Include the full decision table from the design doc (6-row priority table)
3. Instruct orchestrator to assign tier to each finding before implementing
4. Add logging: Tier 1 = silent (just update count), Tier 2 = one-line summary after fix, Tier 3 = summary + flag in pass report
5. Add `fixed_findings` state update after each fix: append `{finding_id, description, files_affected, fix_summary, pass_fixed, tier}` to state
6. Update `tier_counts` in state after each fix

Verification: `grep "Tier 1\|Tier 2\|Tier 3" plugins/plugin-review/commands/review.md | wc -l`

---

### Task 11: Update `commands/review.md` — Phase 4.5 Build/Test
Add new autonomous-mode build/test phase.

Steps:
1. After Phase 4 implementation block, add `### Phase 4.5 — Build/Test Validation [AUTONOMOUS MODE ONLY]`
2. Step 1: Run `discover-test-commands.sh <target-plugin-path>` and `discover-test-commands.sh plugins/plugin-review`
3. Step 2: If both return empty arrays, skip and note "No build/test commands found"
4. Step 3: Run `run-build-test.sh` for target plugin, then for plugin-review
5. Step 4: If all pass, report and continue
6. Step 5: If any fail, spawn `build-fix-agent` with failures + recently-modified files
7. Step 6: After build-fix-agent returns, re-run `run-build-test.sh`
8. Step 7: Report final outcome; update `build_test_failures` in state
9. Note: build-fix-agent is spawned at most once per pass to prevent loops

Verification: `grep "Phase 4.5" plugins/plugin-review/commands/review.md`

---

### Task 12: Update `commands/review.md` — Phase 2 Regression Guard and Phase 5.5 Convergence
Add regression guard spawn on Pass 2+ and update convergence criteria.

Steps:
1. In Phase 2, add `[AUTONOMOUS MODE, PASS 2+]` block: spawn regression-guard with `fixed_findings` from state + relevant current files
2. Note regression-guard runs in parallel with or after analyst subagents
3. In Phase 2.5, add regression-guard results processing: update `regression_guard_regressions` count
4. In Phase 5.5, update convergence criteria: add that in autonomous mode, loop continues if regression guard reports any regressions (even if confidence = 100%)
5. Update the python3 budget-check block to include regression guard status

Verification: `grep "regression-guard\|regression_guard" plugins/plugin-review/commands/review.md | wc -l`

---

### Task 13: Update `commands/review.md` — Phase 6 Convergence Metrics
Add metrics output in autonomous mode.

Steps:
1. In Phase 6, add `[AUTONOMOUS MODE]` block after the confidence-score python3 block
2. Compute elapsed time from `start_time` in state
3. Read final `tier_counts`, `fixed_findings`, `build_test_failures`, `regression_guard_regressions` from state
4. Load `convergence-metrics.md` template and format with actual values
5. Append metrics section to final report output
6. Clear autonomous-mode state fields alongside existing session cleanup

Verification: `grep "convergence-metrics\|Convergence Metrics" plugins/plugin-review/commands/review.md`

---

### Task 14: Update `.claude-plugin/plugin.json` and `CHANGELOG.md`
Version bump and changelog.

Steps:
1. Read `plugins/plugin-review/.claude-plugin/plugin.json` — bump minor version (e.g., 1.x.y → 1.x+1.0)
2. Update matching version in `.claude-plugin/marketplace.json`
3. Add CHANGELOG entry under `## [Unreleased]` or new version heading:
   - Added: `--autonomous` mode flag
   - Added: regression-guard (4th analyst) for narrative re-verification of fixed findings
   - Added: tier classification system (Tier 1/2/3) for findings metrics
   - Added: Phase 4.5 build/test automation with fix-forward subagent
   - Added: convergence metrics in final report

Verification: `./scripts/validate-marketplace.sh`

---

## Batch Plan

- **Batch 1** (Tasks 1–5): New agent and script files — no modifications to existing files
- **Batch 2** (Tasks 6–8): Template and skill updates — lower risk modifications
- **Batch 3** (Tasks 9–13): Core `review.md` command updates — most complex, done last
- **Batch 4** (Task 14): Version bump and validation
