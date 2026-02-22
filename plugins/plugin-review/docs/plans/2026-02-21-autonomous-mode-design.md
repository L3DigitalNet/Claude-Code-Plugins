# Design: Autonomous Convergence Mode

## Problem

The current review loop auto-implements all findings but has no way to verify that fixes from a previous pass haven't been inadvertently undone by subsequent changes. It also lacks: (1) a tier-based classification that distinguishes high-risk architectural changes from low-risk documentation fixes for metrics purposes, (2) build/test validation after each implementation pass, and (3) a rich convergence metrics report. This design adds an `--autonomous` mode that addresses all three gaps while keeping the existing interactive behavior unchanged.

## Approach

Extend `commands/review.md` with inline `[AUTONOMOUS MODE]` conditional blocks that activate when `--autonomous` is detected. This follows the existing "Pass 2+ only" conditional pattern already in the file. All orchestrator logic stays in one place, and the diff is auditable.

Two alternative approaches were considered and rejected:
- **Separate `review-autonomous.md` command**: Duplicates ~100 lines of setup and Phase 1–2 logic.
- **Skill-based extension**: Adds indirection without composability benefit since the extensions are phase-specific blocks, not reusable across commands.

## New Components (5 files)

### `agents/regression-guard.md`

Read-only subagent (tools: `Read, Grep, Glob`). Spawned on Pass 2+ in autonomous mode only. Receives: a list of previously-fixed findings with `{finding_id, description, files_affected, fix_summary}` and the current state of the relevant files. Performs a narrative re-check — qualitative re-analysis verifying that each fix is still intact — and returns a structured list of `{finding_id, status: "holding" | "regressed", evidence}`. Does not generate assertions; produces human-readable narrative verification.

**Why a separate agent vs extending run-assertions.sh**: Shell assertions test for specific mechanical properties (grep patterns, file existence). Regression analysis for qualitative findings (e.g., "confirmation dialogs removed", "UX output restructured") requires reading implementation files and applying analytical judgment — not a shell command.

### `agents/build-fix-agent.md`

Write-capable subagent (tools: `Read, Grep, Glob, Edit, Write`). Spawned when Phase 4.5 build/test fails. Receives: failing test output, the test command that failed, and the files most recently modified in Phase 4. Implements the minimum fix needed to restore tests to passing. Returns a structured summary of what changed.

**Scope boundary**: Fix only what the failing tests require. If a test failure exposes a deeper architectural issue, report it as unresolvable rather than expanding scope.

### `scripts/discover-test-commands.sh`

Probes a plugin directory for build and test commands. Checks in order:
1. `package.json` with `scripts.build` / `scripts.test` → `npm run build`, `npm test`
2. `Makefile` with `build` / `test` targets → `make build`, `make test`
3. `pytest.ini` or `pyproject.toml` with `[tool.pytest.ini_options]` → `pytest`
4. Shell scripts in `scripts/test*.sh` → enumerate each
5. `scripts/run-assertions.sh` (plugin-review self-check) → always included for plugin-review itself

Outputs JSON array: `[{"type": "build"|"test", "command": "...", "cwd": "..."}]`.

If nothing is found, outputs `[]` and exits 0 — absence of tests is not an error.

### `scripts/run-build-test.sh`

Accepts a plugin path and runs the discovered commands in order. For each command:
- Captures stdout + stderr
- Records pass/fail and exit code
- Limits output capture to 2000 chars per command

Outputs structured JSON: `{"pass": bool, "results": [{"type": ..., "command": ..., "exit_code": ..., "output": "..."}]}`. Also prints a human-readable summary to stdout for the orchestrator to embed in the pass report.

### `templates/convergence-metrics.md`

Template for the final report Convergence Metrics section. Loaded by the orchestrator in Phase 6 when `--autonomous` was set. Format:

```
### Convergence Metrics
- Mode: autonomous
- Total passes: N  |  Time: Xm Ys
- Total findings: N  →  N resolved  |  N open (accepted)
- Tier 1 (docs/format):  N auto-fixed
- Tier 2 (error/validation):  N auto-fixed
- Tier 3 (architectural):  N auto-fixed
- Regressions caught by guard: N  (N resolved, N accepted)
- Build/test failures: N  (N resolved by fix-forward agent)
```

## Modified Components (6 files)

### `commands/review.md`

**Phase 1 (Setup)**: Parse `--autonomous` flag (regex: `--autonomous`). When set, initialize state with additional fields: `mode: "autonomous"`, `start_time: <ISO>`, `tier_counts: {t1: 0, t2: 0, t3: 0}`, `fixed_findings: []`, `build_test_failures: 0`. Default `max_passes` remains 5 (overridden by `--max-passes=N`).

**Phase 2 (Analyze)**: Add `[AUTONOMOUS MODE, PASS 2+]` block: spawn regression-guard with the list of fixed findings from state + relevant current files. Run regression guard in parallel with analyst subagents or after them.

**Phase 4 (Implement)**: Add tier classification before implementing each finding. Classification is orchestrator-owned and applied via a decision table (see Tier Classification section below). Log tier assignment; update `tier_counts` in state. Behavior is identical for all tiers — auto-fix everything — but tier is recorded for metrics.

**Phase 4.5 (Build/Test) [AUTONOMOUS MODE ONLY]**: After Phase 4 implementation:
1. Run `discover-test-commands.sh <target-plugin-path>` → get command list
2. Run `discover-test-commands.sh plugins/plugin-review` → add plugin-review self-check
3. Run `run-build-test.sh` with combined command list
4. If all pass: report "Build/test: all pass" and continue
5. If any fail: spawn `build-fix-agent` with failure details and recently-changed files
6. After fix-agent returns: re-run `run-build-test.sh`
7. Report final build/test outcome; update `build_test_failures` count in state

**Phase 5.5 (Assertions)**: Add `[AUTONOMOUS MODE]` convergence criteria: loop back only if BOTH `confidence < 100%` AND regression guard reports zero regressions. If either condition fails, loop back to Phase 2.

**Phase 6 (Convergence)**: Add `[AUTONOMOUS MODE]` block: load `convergence-metrics.md`, compute elapsed time from `start_time`, read final `tier_counts` and `build_test_failures` from state, format and append metrics section to final report.

### `templates/final-report.md`

Add `### Convergence Metrics` section after `### Files Modified`. Section is omitted if mode was not `autonomous` (no metrics to report).

### `templates/pass-report.md`

Add `Tier` column to the Convergence table: `| Pass | Tier1 | Tier2 | Tier3 | Upheld | ... |`. Add `### Regression Guard` section (Pass 2+ autonomous only) listing holding/regressed findings.

### `skills/scoped-reaudit/SKILL.md`

Add regression-guard track mapping: the regression-guard agent is affected when any file that was previously modified appears in the changed-files list. Since it re-checks specific previously-fixed findings, it always runs on Pass 2+ in autonomous mode regardless of which files changed — this is noted as an exception to the normal track-mapping logic.

### `.claude-plugin/plugin.json` + `CHANGELOG.md`

Version bump and changelog entry.

## Tier Classification

Tier is assigned by the orchestrator (not the analyst subagents) when processing their output. Decision table, evaluated top-to-bottom, first match wins:

| Priority | Tier | Condition |
|----------|------|-----------|
| 1 | 3 | Finding modifies command output contract, agent `tools:` frontmatter, state file schema, or hook trigger conditions |
| 2 | 3 | Track A; finding type "Violated"; affects `commands/` or `agents/` files |
| 3 | 2 | Keywords in finding description: "error handling", "validation", "missing check", "test gap", "boundary", "exception" |
| 4 | 1 | Track C finding (documentation) |
| 5 | 1 | Keywords: "formatting", "comment", "type annotation", "import ordering", "whitespace", "style" |
| 6 | 2 | Default (unclassified) |

Tier 3 is fixed without a human gate (user chose "auto-fix everything"). Tier is surfaced only in the per-pass tier column and final convergence metrics.

## Convergence Criteria (autonomous mode)

Loop back to Phase 2 only if ALL are true:
1. `confidence < 100%` (assertions failing)
2. `pass_number < max_passes` (budget not reached)
3. Regression guard (if spawned) reports zero new regressions — regressions extend the loop regardless of assertion confidence

Stop conditions:
1. `confidence == 100%` AND regression guard reports zero regressions → Zero open findings
2. `pass_number >= max_passes` → Budget reached
3. Plateau (two identical consecutive passes)
4. Divergence (more new findings than resolved)

## State Schema Extensions

```json
{
  "mode": "autonomous",
  "start_time": "2026-02-21T10:00:00Z",
  "impl_files": [],
  "doc_files": [],
  "pass_number": 1,
  "max_passes": 5,
  "tier_counts": {"t1": 0, "t2": 0, "t3": 0},
  "fixed_findings": [
    {"finding_id": "P3", "description": "...", "files_affected": [], "fix_summary": "...", "pass_fixed": 1, "tier": 2}
  ],
  "build_test_failures": 0,
  "regression_guard_regressions": 0
}
```

Fields added only when `--autonomous` is set. Non-autonomous sessions write the original schema unchanged.

## Enforcement Mapping

| Constraint | Layer | Mechanism |
|-----------|-------|-----------|
| Tier 3 auto-fix (no gate) | Behavioral | Instruction in Phase 4: "fix all tiers, record tier for metrics only" |
| Build/test required after each pass | Structural | Phase 4.5 is a mandatory block in autonomous mode; loop cannot proceed to Phase 5 without it |
| Regression guard required for convergence | Structural | Phase 5.5 convergence check explicitly requires guard status in addition to assertion confidence |
| Regression guard read-only | Structural + Mechanical | `tools: Read, Grep, Glob` in agent frontmatter; `validate-agent-frontmatter.sh` hook warns on violations |
| Build-fix agent write-capable | Structural | `tools: Read, Grep, Glob, Edit, Write`; matches fix-agent pattern |
