# Plan: test-driver

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 12 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 5 shell scripts (`detect-project.sh`, `git-function-changes.sh`, `inventory-sources.sh`, `inventory-tests.sh`, `test-status-update.sh`) |
| Existing tests | 5 bats (1:1 with scripts) |
| Framework | bats |
| Coverage ratio | 1:1 |

Principles: `[P1] Test at Breakpoints, Not Every Edit`, `[P2] Inline Over Delegated`, `[P3] Converge, Don't Repeat`, `[P4] Profile-Driven Stack Knowledge`.

Like nominal, this plan is gap-fill against existing 1:1 coverage.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Test at Breakpoints | Behavioral — out of scope | n/a | Breakpoint detection is in skill prompts. |
| [P2] Inline Over Delegated | Behavioral — out of scope | n/a | "No agent delegation" is a prompt-level constraint. |
| [P3] Converge, Don't Repeat | Mechanical | Extend `tests/test-status-update.bats` — sequence of four status updates with alternating pass/fail counts → status file flags `oscillating: true`; monotonic improvement → flags `converging: true`. | Oscillation-detection math is testable; the consumer agent reads the flag. |
| [P4] Profile-Driven Stack Knowledge | Structural | New `tests/profile-shape.bats` — every profile file under `references/profiles/` has the required keys (`name`, `framework`, `runner_command`, `gap_analyzer`); profile loader rejects malformed profile with a single-line error. | Profile schema = mechanical. Adding a new stack must be a one-file change; this test enforces the contract. |
| Cross-cutting (detect-project) | Mechanical | Extend `tests/detect-project.bats` — multi-language repo (e.g., Python + TS) returns a list, not just the dominant one; ambiguous repo (no manifests) returns "unknown" with exit 0 + suggestion. | Multi-stack detection is the value-add over heuristic single-detection. |
| Cross-cutting (git-function-changes) | Mechanical | Extend `tests/git-function-changes.bats` — diff hunks straddling function boundaries are attributed to the *enclosing* function, not the next one; renamed functions tracked across rename. | Edge cases in the function-change detector. |
| Cross-cutting (inventory-sources / -tests) | Mechanical | Verify existing tests cover the marketplace-relevant case: a directory containing `.bats` test files and `.sh` source files in a sibling tree (matches the marketplace's own layout). | Self-host: test-driver should work on this very repo. |

## Files to create / modify

```
plugins/test-driver/tests/
├── detect-project.bats         (extend)
├── git-function-changes.bats   (extend)
├── inventory-sources.bats      (verify coverage)
├── inventory-tests.bats        (verify coverage)
├── test-status-update.bats     (extend — convergence math)
└── profile-shape.bats          (new — profile contract)
```

## Fixtures needed

- `tests/fixtures/multi-stack-repo/` — a repo with both Python and TS manifests.
- `tests/fixtures/ambiguous-repo/` — no manifests, just source.
- `tests/fixtures/profiles/` — valid profile, missing-key profile, malformed profile.
- `tests/fixtures/git-diffs/` — synthetic diffs covering rename + boundary-straddle cases.

## Runtime estimate

- 5 extended + 1 new bats file × ~3–4 cases = ~20 added cases. Sub-second to ~3 s.

## Risks (flag, do not fix)

1. **Profile contract may not be enforced by code yet.** The README says "adding a new stack means adding one file"; if the loader silently ignores malformed profiles, the test will reveal it. **Report**, do not fix.
2. **`git-function-changes.sh` rename detection** depends on `git diff -M` thresholds. If the script uses default `-M50%`, edge cases at exactly 50% may be flaky. Pin the threshold in tests via env override if available; flag if hardcoded.
3. **Self-hosting test (test-driver against this repo) is tempting** but introduces a circular dependency: changes to test-driver could break its own tests via the very inventory it scans. Limit self-host tests to small fixture trees, not the live repo.

## What this plan does NOT do

- Test the `testing-mindset` skill. Behavioral.
- Test convergence-loop *quality* (does it actually fix tests?). Behavioral / PTH-coverage.
- Cross-plugin tests with `python-dev` / `qt-suite` / `home-assistant-dev` enhancements. Out of scope.
- Modify scripts.

## Phase 2 execution log (2026-04-25)

### Built / extended

- **`tests/profile-shape.bats` (new, 3 cases)** — encodes [P4] Profile-Driven Stack Knowledge: every profile has the description-line + `---`-separator + `# Stack Profile` heading shape; filenames match `[a-z0-9](-[a-z0-9])+\.md` for stable detection.
- **`tests/manifest.bats` (new, 1 case)** — Zod-strict allow-list.
- **`tests/run-bats.sh`** — bats wrapper.

### Suite

`bash plugins/test-driver/tests/run-bats.sh` — **57 of 57 passing** (53 baseline + 4 added).

### Findings

1. **Profile shape is NOT YAML frontmatter** — initial test assumption was wrong. Actual shape: a one-line description on line 1, blank, `---` separator, then `# Stack Profile: Name` heading. Test PS1 now asserts that actual shape. The profile loader code likely parses the description line specially; this test locks the convention.
2. **Existing 53-case baseline already covered** detect-project (multi-language hints), git-function-changes, inventory-sources, inventory-tests, test-status-update. Plan extensions about multi-stack detection and rename-tracking turned out already-present in baseline. Net new value: profile-shape contract.

### Coverage delta

| Layer | Before | After |
|---|---|---|
| Mechanical (script) | 53 cases | (no extension — baseline already strong) |
| Structural (profile shape) | 0 | 3 cases — locks the [P4] one-file-per-stack contract |
| Structural (manifest) | 0 | 1 case |
| Behavioral [P1]/[P2] | (out of scope) | (out of scope — explicitly noted) |
