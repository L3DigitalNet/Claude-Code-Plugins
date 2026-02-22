# autonomous-refactor

Test-driven autonomous refactoring against your project's own design principles.

## Summary

`/refactor <file>` captures a green test baseline, audits the code against principles in your project's README.md, then iterates through refactoring opportunities one at a time — each in an isolated git worktree. Changes that break tests are automatically reverted. The entire loop runs without human input. A before/after report is produced at the end.

## Principles

- **[P1] Snapshot before touching** — Tests are generated and confirmed green before any source changes. A failing baseline stops the run immediately.
- **[P2] Isolation per change** — Each refactoring opportunity lives in its own `git worktree`. Failures never touch the working branch.
- **[P3] Principle-driven opportunities** — Every opportunity cites the README.md principle it violates. Aesthetic or stylistic changes are out of scope.
- **[P4] Convergence over confirmation** — Phase 3 runs to completion autonomously. Human input is collected only at invocation.
- **[P5] Fail transparently** — Test failures, git errors, and missing tools surface immediately with raw output and recovery steps. No silent workarounds.

## Installation

```
/plugin marketplace add https://github.com/L3DigitalNet/Claude-Code-Plugins
/plugin install autonomous-refactor
```

## Usage

```
/refactor src/auth.ts
/refactor src/auth.ts src/utils.ts --max-changes=5
refactor the auth module
```

The command detects language from file extension and infers the test runner from `package.json` or `pyproject.toml`.

**Prerequisites:**
- Target project must be a git repository
- For TypeScript: `package.json` with a `test` script, or Vitest/Jest reachable via `npx`
- For Python: `pytest` installed in the active environment

**Optional (for precise complexity metrics):**
- Python: `pip install radon`
- TypeScript: `npm i -g complexity-report`

The plugin prompts to install these if missing and falls back to AI-estimated complexity.

## Commands

| Command | Description |
|---------|-------------|
| `/refactor <file> [files...] [--max-changes=N]` | Run the full 4-phase refactor workflow |

## Agents

| Agent | Role | Tools |
|-------|------|-------|
| `test-generator` | Phase 1: generates behavioural tests and confirms green baseline | Read, Glob, Grep, Bash |
| `principles-auditor` | Phase 2 & 3b: audits code against README.md principles, returns ranked opportunities | Read, Glob, Grep |
| `refactor-agent` | Phase 3: applies a single opportunity inside the provided git worktree | Read, Write, Edit, Bash, Glob, Grep |
| `report-generator` | Phase 4: formats before/after comparison from metrics and state | Read, Glob, Bash |

## Phase Flow

```
Phase 1 — Snapshot
  test-generator generates tests → confirms GREEN baseline → snapshot metrics

Phase 2 — Analyze
  principles-auditor reads source + README.md → ranked opportunities list

Phase 3 — Refactor Loop (autonomous, no human gates)
  for each opportunity:
    git worktree add → refactor-agent applies change → run tests
    GREEN: commit → remove worktree → re-audit
    RED:   remove worktree (no merge) → continue

Phase 4 — Report
  snapshot final metrics → report-generator formats before/after table
```

## Convergence Rules

| Condition | Behaviour |
|-----------|-----------|
| All opportunities addressed | Proceed to Phase 4 |
| `--max-changes=N` reached | Stop loop, note remaining, proceed to Phase 4 |
| Same opportunity reverted twice | Skip (oscillation detected), continue |
| Test runner missing | Stop immediately, surface install instructions |
| Git worktree failure | Stop immediately, surface raw error |
