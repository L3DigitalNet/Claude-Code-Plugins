---
name: convergence-loop
description: >
  Iterative test generation and fix engine. Use when filling test gaps identified by gap-analysis:
  generates tests in batches, runs them, fixes failures, and iterates until all pass or exit
  criteria are met. Includes oscillation detection, bug fix boundaries, and convergence reporting.
  Triggers on: convergence loop, test loop, generate and fix tests, iterate tests, fill test gaps,
  run tests until green, test convergence.
---

# Convergence Loop: Iterative Test Generation Engine

The convergence loop takes a gap report from the gap-analysis skill and iteratively generates tests, runs them, fixes failures, and repeats until all tests pass or exit criteria are met.

## Loop Phases

```
ANALYZE ── read gap report, prioritize by severity
   |
GENERATE ── write 3-5 tests for highest-priority gaps
   |
RUN ─────── execute test suite via stack profile command
   |
EVALUATE ── classify each failure
   |   |-- Test bug ────── fix the test, loop back to RUN
   |   |-- Source bug:
   |   |     |-- Simple ── fix autonomously, loop back to RUN
   |   |     |-- Behavioral ── STOP, surface to user
   |   |-- All green ──── proceed to EXIT CHECK
   |
EXIT CHECK
   |-- All generated tests pass? ─── no: back to EVALUATE
   |-- Coverage target defined and not met? ─── generate more: back to GENERATE
   |-- No more meaningful tests to write? ─── exit with REPORT
   |-- Oscillation detected? ─── STOP, surface to user
   |-- Max 10 iterations reached? ─── forced STOP with REPORT
   |
REPORT ──── update TEST_STATUS.json, summarize to user
```

## Phase Details

### ANALYZE

Read the gap report produced by gap-analysis. Sort gaps by priority (high first). Select the top 3-5 gaps for the first batch.

### GENERATE

Write 3-5 tests per batch, targeting the highest-priority unfilled gaps.

- Consult the `test-design` skill for universal principles (isolation, naming, assertions)
- Consult the active stack profile for framework conventions (test runner, fixture patterns, file locations)
- Consult framework-specific plugins when available (e.g., `python-dev:python-testing-patterns`)
- Place test files according to the profile's discovery conventions

#### Category-Specific Generation

When generating tests for non-unit gaps, adapt the test approach to match the category:

| Category | Approach |
|----------|----------|
| **Unit** | Mock external dependencies. Test isolated function/class behavior. One function per test. |
| **Integration** | Use real components (test database, actual HTTP client, real service instances). Assert on observable outcomes across component boundaries, not internal state. |
| **E2E** | Full request lifecycle through the actual app stack with minimal mocking. Test critical user-facing workflows (e.g., authenticate, perform action, verify result). Accept slower execution. |
| **Contract** | Validate API response schemas, status codes, required fields, content-type headers, and error response shapes. Use schema validation (jsonschema, pydantic model parsing) rather than value equality. Tests should pass regardless of data state. |
| **Security** | Each test represents a specific attack vector: SQL injection in user inputs, auth token manipulation, accessing resources without credentials, accessing another user's resources. Assert the attack fails gracefully (proper error code, no data leakage in error messages). |
| **UI** | Use the framework's UI testing tool (pytest-qt, XCUITest, Charlotte). Interact via accessibility identifiers. Assert on what the user sees (text content, visibility, enabled state), not internal widget state. |

#### Category Ordering

When the gap report contains gaps across multiple categories, generate tests in this order:

1. **Unit** — fastest to write and run, catches the most bugs per iteration
2. **Integration** — validates component interactions
3. **Contract** / **Security** — validates API shape and attack resistance
4. **E2E** / **UI** — slowest, run last

Within each category, follow the gap report's priority ordering (high before medium before low).

### RUN

Execute the test suite using the command from the stack profile:
- Python: `pytest tests/ -v`
- Swift: `swift test`
- Use the specific command for the test category being filled

### EVALUATE

For each failing test, classify the failure:

**Test bug:** The test itself has an error (wrong assertion, incorrect setup, import error). Fix the test and re-run.

**Simple source bug:** The test correctly exposed a real bug in the source code that is clearly incorrect. Fix autonomously and re-run.

**Behavioral source bug:** The test exposed something that would require changing functionality, API contracts, or features. Stop and surface to the user.

## Bug Fix Boundary

**Fix autonomously (simple bugs):**
- Typos in variable names, strings, or comments
- Off-by-one errors in loops or comparisons
- Missing null/None checks that cause crashes
- Wrong return types (returning string instead of int, etc.)
- Incorrect comparison operators (`<` instead of `<=`)
- Missing import statements

**Stop and surface to user (behavioral changes):**
- Changed function signatures (different parameters, return types)
- Altered business logic (different calculation, different flow)
- Modified API contracts (changed response shape, status codes)
- Removed or added features
- Changed error handling behavior (different exception types, error messages that consumers depend on)

When in doubt, stop and surface. False positives (asking unnecessarily) cost less than false negatives (changing behavior silently).

## Exit Criteria

The loop exits when any of these conditions are met:

1. **All generated tests pass** and either:
   - No coverage target is defined in the stack profile, OR
   - The coverage target is met
2. **No more meaningful tests to write.** All high and medium priority gaps have been filled; remaining gaps are too low-priority or too complex to generate automatically.
3. **Oscillation detected.** See below.
4. **Max 10 iterations reached.** Forced stop with a status report of what was accomplished and what remains.

## Oscillation Detection

**Heuristic:** If any test that was previously green turns red after a fix, that counts as a **regression**. Two regressions within the same convergence run equals **oscillation**.

When oscillation is detected:
1. **Stop immediately.** Do not attempt further fixes.
2. **List the involved tests and fixes:** which test went red, what fix caused it, and what the relationship is.
3. **Surface the pattern to the user** with a clear explanation of the cycle.

Oscillation usually indicates a design issue (tightly coupled components, shared mutable state) that requires human judgment to resolve.

## Reporting

After the loop exits (for any reason), produce a summary and update `TEST_STATUS.json`:

**Summary format:**
```
## Convergence Loop Results

- **Iterations:** 4 of 10 max
- **Tests generated:** 8
- **Tests passing:** 8
- **Source bugs fixed:** 1 (off-by-one in auth.py token expiry check)
- **Gaps filled:** 5 of 7
- **Gaps deferred:** 2 (reason: max complexity, would need architectural changes)
- **Exit reason:** All generated tests pass, coverage target met
```

**TEST_STATUS.json updates** (defer to the `test-status` skill for schema details):
- Update `categories` with new test counts and pass/fail status
- Update `coverage` if coverage was measured during the run
- Record any source bugs fixed in `source_bugs_fixed`
- Move filled gaps out of `known_gaps`; set `reason_deferred` on remaining gaps
- Append a history entry with date, action "convergence_loop", and summary

## Source Modification Tracking

Every autonomous source fix must be recorded. For each fix, track:
- **Date** of the fix
- **File** that was modified
- **Description** of what changed and why
- **Test that caught it** (which test exposed the bug)

These records go into the `source_bugs_fixed` array in TEST_STATUS.json, giving the user visibility into what Claude changed in their source code during the loop.
