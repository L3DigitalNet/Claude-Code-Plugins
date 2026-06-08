# UX & Output Templates

All output templates for test-driver. These ensure consistent formatting when reporting test status, gap analysis results, and convergence loop progress.

## Visual Grammar

| Symbol | Meaning                              |
| ------ | ------------------------------------ |
| ✅     | Tests passing, coverage met          |
| ❌     | Tests failing, coverage below target |
| ⚠️     | Stale status, approaching threshold  |

---

## Template 1 — Gap Analysis Report

**When:** After gap-analysis completes (gap-analysis.md Step 7). Also used by `/test-driver:analyze` Step 4.

```markdown
## Gap Analysis Report

**Project:** <project-name> **Profile:** <stack-profile> **Date:** <ISO-8601 timestamp> **Source files analyzed:** <count>

### Gaps Found: <total-count>

| Priority | File | Category | Description |
| --- | --- | --- | --- |
| high | src/api/auth.py | unit | No unit tests for token validation functions |
| high | src/api/auth.py | integration | No integration test for token refresh with expired session |
| medium | src/services/email.py | unit | Email template rendering has no tests |
| low | src/utils/formatting.py | unit | String formatting helpers untested (low complexity) |

### Category Summary

| Category    | Applicable | Existing Tests | Gaps |
| ----------- | ---------- | -------------- | ---- |
| unit        | yes        | 38             | 3    |
| integration | yes        | 12             | 1    |
| e2e         | yes        | 4              | 0    |
| contract    | yes        | 0              | 0    |
```

Follow with `AskUserQuestion`:

- **"Fill all gaps"** — enter convergence-loop for all identified gaps
- **"Fill specific files only"** — follow up with file selection
- **"Record gaps only"** — update TEST_STATUS.json without generating tests

---

## Template 2 — Convergence Loop Results

**When:** After the convergence loop exits (convergence-loop.md Reporting section).

```markdown
## Convergence Loop Results

- **Iterations:** N of 10 max
- **Tests generated:** N
- **Tests passing:** N
- **Source bugs fixed:** N (description of each)
- **Gaps filled:** N of M
- **Gaps deferred:** N (reason: max complexity, would need architectural changes)
- **Exit reason:** [All generated tests pass | Coverage target met | Oscillation detected | Max iterations | User stopped]
```

---

## Template 3 — Test Posture Summary

**When:** `/test-driver:status` renders TEST_STATUS.json. Also used as the compact report after convergence or analysis.

```markdown
## Test Posture: <project-name>

**Last analysis:** <date> (<N> source files analyzed) **Profile:** <stack-profile>

### Categories

| Category    | Tests | Passing | Failing |
| ----------- | ----- | ------- | ------- |
| unit        | 38    | 38      | 0       |
| integration | 12    | 11      | 1       |
| e2e         | 4     | 4       | 0       |
| contract    | —     | —       | —       |

### Coverage

**Current:** 74% | **Target:** 80% | **Gap:** 6%

### Top Known Gaps

1. [high] `src/api/auth.py` — integration: No test for token refresh with expired session
2. [medium] `src/services/email.py` — unit: Email template rendering untested
3. [low] `src/utils/formatting.py` — unit: String formatting helpers untested

### Source Bugs Fixed (Last Loop)

- `src/api/auth.py`: Off-by-one in token expiry check (caught by test_auth_token_expiry_boundary)
```

Omit sections with no data (e.g., skip "Source Bugs Fixed" if the array is empty).

---

## Template 4 — Staleness Warning

**When:** `/test-driver:status` detects stale data (time-based or change-based).

```markdown
⚠️ Status may be stale — source files have changed since the last analysis. Run `/test-driver:analyze` to refresh.
```

---

## Template 5 — Oscillation Alert

**When:** Convergence loop detects oscillation (2 regressions within one run).

```markdown
⚠️ Oscillation Detected — Stopping

The following tests are cycling between pass and fail:

| Test                   | Was | After Fix To                 | Became |
| ---------------------- | --- | ---------------------------- | ------ |
| test_auth_token_expiry | ✅  | fix off-by-one in validate() | ❌     |
| test_validate_input    | ✅  | fix type check in parse()    | ❌     |

This usually indicates tightly coupled components or shared mutable state that requires a design change to resolve.
```

---

## Template 6 — Loop Phase Indicator

**When:** During convergence loop iterations, emitted as each phase completes.

```text
Loop iteration N/10:
  GENERATE  ✅  3 tests written
  RUN       ✅  all passing
  EVALUATE  ✅  0 failures
  → Proceeding to exit check
```

```text
Loop iteration N/10:
  GENERATE  ✅  5 tests written
  RUN       ❌  2 failures
  EVALUATE  → 1 test bug (fixing), 1 source bug (simple, fixing)
  → Re-running after fixes
```

---

## Template Usage

References should point to this file for output formatting rather than defining templates inline. Use:

> Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template N.
