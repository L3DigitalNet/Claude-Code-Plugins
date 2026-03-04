# Design: autonomous-refactor Plugin

**Date:** 2026-02-21
**Status:** Approved
**Author:** L3DigitalNet

---

## Problem

Refactoring code against design principles is iterative, test-risky, and easy to abandon mid-way. There is no existing tool that (a) captures behavioural tests before touching code, (b) audits against project-specific principles, (c) applies changes one-at-a-time inside git worktree isolation, and (d) auto-reverts on test failure — all without human input in the loop.

---

## Solution

A Claude Code plugin (`autonomous-refactor`) that runs a 4-phase test-driven refactoring workflow autonomously. The user invokes `/refactor <file>` and walks away. The plugin captures a green baseline, identifies principle violations, iterates changes inside isolated worktrees, and emits a before/after report.

---

## Architecture

### Approach Selected

**Command + Agents + Shell Scripts** (Approach A).
The orchestrator is a markdown command that delegates analysis to read-only subagents and writes to a single write-capable subagent. Shell scripts handle language detection, test running, and worktree lifecycle. A TypeScript metrics helper (`src/metrics.ts`, run via `npx tsx`) provides precise LOC and diff output with graceful fallback to AI estimation.

This mirrors the `plugin-review` pattern which is proven for this style of multi-pass autonomous orchestration in this repository.

---

## Plugin Structure

```
plugins/autonomous-refactor/
├── .claude-plugin/plugin.json
├── commands/
│   └── refactor.md              # 4-phase orchestrator
├── agents/
│   ├── test-generator.md        # Phase 1: generate + run test suite
│   ├── principles-auditor.md    # Phase 2 & 3b: audit against README.md
│   ├── refactor-agent.md        # Phase 3: one change per invocation, in worktree
│   └── report-generator.md     # Phase 4: before/after comparison
├── scripts/
│   ├── run-tests.sh             # Detect TS/Python, run appropriate test command
│   ├── measure-complexity.sh    # radon / ts-complexity + AI fallback + install prompt
│   └── snapshot-metrics.sh     # Capture LOC + complexity at a point in time
├── src/
│   └── metrics.ts               # TypeScript for precise LOC/diff output (optional)
├── templates/
│   ├── test-generation-ts.md    # Instructions for generating TS test suites
│   ├── test-generation-py.md    # Instructions for generating Python test suites
│   └── final-report.md          # Before/after report format
├── README.md
└── CHANGELOG.md
```

---

## State Schema

**Location:** `.claude/state/refactor-session.json`

```json
{
  "target_files": ["src/auth.ts"],
  "language": "typescript",
  "test_file": ".claude/state/refactor-tests/auth.test.ts",
  "baseline": {
    "loc": 312,
    "complexity_score": 47,
    "principles_score": 58,
    "timestamp": "2026-02-21T10:00:00Z"
  },
  "opportunities": [
    { "id": 1, "description": "Extract shared validation logic", "priority": "high", "status": "pending" },
    { "id": 2, "description": "Add error handling to async calls", "priority": "medium", "status": "pending" }
  ],
  "completed_changes": [],
  "reverted_changes": [],
  "max_changes": 10,
  "current_worktree": null
}
```

---

## Phase Flow

### Phase 1 — Snapshot

1. Orchestrator parses target file(s) and language from invocation
2. Spawn **test-generator** (read-only) with target files + language-appropriate template
3. test-generator writes test file to `.claude/state/refactor-tests/`
4. Run `scripts/run-tests.sh` — must be GREEN before proceeding; agent fixes tests until green
5. Run `scripts/snapshot-metrics.sh` — captures baseline LOC + complexity
6. Write baseline to session state

### Phase 2 — Analyze

1. Spawn **principles-auditor** (read-only) with target files + project `README.md`
2. Auditor returns ranked JSON array: `[{id, description, priority, rationale}]`
3. Each opportunity cites the README.md principle it violates
4. Write opportunities list to session state

### Phase 3 — Refactor Loop (fully autonomous, no `AskUserQuestion`)

```
for each opportunity (highest priority first):
  1. git worktree add .claude/worktrees/refactor-{id} HEAD
  2. Spawn refactor-agent with: opportunity object, worktree path, target files
  3. Run scripts/run-tests.sh --worktree .claude/worktrees/refactor-{id}
  4. GREEN → merge worktree to main branch → git commit → delete worktree
              → mark opportunity "completed"
  5. RED   → delete worktree (no merge) → mark opportunity "reverted"
  6. Spawn principles-auditor again → update remaining opportunities list
  7. Continue to next opportunity

Stop when:
  - All opportunities have status != "pending"
  - max_changes reached (default 10, override: --max-changes=N)
  - Oscillation: same opportunity reverted twice → skip it, continue
```

### Phase 4 — Report

1. Run `scripts/snapshot-metrics.sh` — captures final LOC + complexity
2. Spawn **report-generator** (read-only) with baseline, final metrics, change log, template
3. Emit formatted before/after report (no files written — output only)

---

## Agent Contracts

### test-generator
- **Tools:** `Read, Glob, Grep, Bash`
- **Input:** target file list, language, template path
- **Output:** test file written to `.claude/state/refactor-tests/`, returns `{test_file, pass_count, fail_count}`
- **Constraint:** must reach GREEN before returning; fixes its own generated tests if they fail

### principles-auditor
- **Tools:** `Read, Glob, Grep`
- **Input:** target file list, project README.md path
- **Output:** JSON array `[{id, description, priority: "high"|"medium"|"low", rationale, principle_ref}]`
- **Constraint:** each item must cite the README.md section/principle it violates

### refactor-agent
- **Tools:** `Read, Write, Edit, Bash, Glob, Grep`
- **Input:** single opportunity object, worktree path, relevant files
- **Output:** `{changed_files: [], description: string, test_result: "not_run"}`
- **Constraint:** touches only files relevant to the single opportunity; does not expand scope; does NOT run tests (orchestrator runs them)

### report-generator
- **Tools:** `Read, Glob, Bash`
- **Input:** baseline metrics, final metrics, completed/reverted change list, `templates/final-report.md`
- **Output:** formatted markdown report (returned to orchestrator, not written to disk)
- **Constraint:** read-only; no file writes

---

## Metrics Strategy

**Complexity measurement** (`scripts/measure-complexity.sh`):
1. Attempt external tool: `radon cc` (Python) or `npx --yes ts-complexity` (TypeScript)
2. If tool missing: prompt user to install (`pip install radon` / `npm i -g ts-complexity`) and offer AI-estimated fallback
3. Output: `{file, cyclomatic_complexity, loc}` JSON per file

**LOC** (`scripts/snapshot-metrics.sh`): counts non-blank, non-comment lines via `wc -l` with comment stripping.

**Principles alignment score** (AI-rated 0–100): `principles-auditor` returns a numeric score alongside the opportunities list. Score = `100 - (sum of priority weights)` where high=15, medium=8, low=3, capped at 0.

---

## Convergence & Safety Rules

| Condition | Behaviour |
|-----------|-----------|
| All opportunities addressed | Proceed to Phase 4 |
| `max_changes` reached | Stop loop, note remaining, proceed to Phase 4 |
| Same opportunity reverted twice | Skip it (oscillation), continue |
| Test runner not found | Stop immediately, surface error + install instructions |
| Git worktree creation fails | Stop immediately, surface raw error |
| Phase 3 produces more violations than it resolves (2 consecutive passes) | Flag divergence, stop, recommend manual review |

---

## Language Detection

`scripts/run-tests.sh` detects language from:
1. Target file extension (`.ts`/`.tsx` → TypeScript, `.py` → Python)
2. Presence of `package.json` → check `scripts.test` for test command
3. Presence of `pyproject.toml` or `pytest.ini` → use `pytest`
4. Fallback: prompt user to specify test command

---

## Plugin Principles

- **[P1] Snapshot before touching** — tests are generated and confirmed green before any code changes
- **[P2] Isolation per change** — each refactoring opportunity lives in its own git worktree; failures never pollute the working branch
- **[P3] Principle-driven opportunities** — every refactoring item traces back to a stated project principle in README.md; aesthetic or stylistic changes are out of scope
- **[P4] Convergence over confirmation** — Phase 3 runs to completion autonomously; human input is only collected at invocation time
- **[P5] Fail transparently** — test failures, git errors, and missing tools surface immediately with raw output and recovery steps; no silent workarounds
