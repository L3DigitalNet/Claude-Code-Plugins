---
name: status
description: View current test posture from TEST_STATUS.json without running any tests or analysis.
allowed-tools:
  - Read
  - Glob
  - Bash
---

# /test-driver:status — Test Posture Summary

Display the current testing posture from the persistent status file without running any tests or analysis.

## Step 1: Read Status File

Read `docs/testing/TEST_STATUS.json`.

If the file does not exist:
> "No test status file found. Run `/test-driver:analyze` to create one."

Stop here.

## Step 2: Render Summary

Present a compact summary:

```
## Test Posture: <project-name>

**Last analysis:** <date> (<N> source files analyzed)
**Profile:** <stack-profile>

### Categories

| Category | Tests | Passing | Failing |
|----------|-------|---------|---------|
| unit | 38 | 38 | 0 |
| integration | 12 | 11 | 1 |
| e2e | 4 | 4 | 0 |
| contract | — | — | — |

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

## Step 3: Staleness Check

Check for staleness using two signals:

1. **Time-based:** If `last_analysis.date` is more than 7 days ago, the status is likely stale.
2. **Change-based:** Run `git log --since="<last_analysis_date>" --oneline -- "*.py" "*.swift" "*.ts"` to check for source changes since the last analysis.

If either signal fires:
> "Status may be stale — source files have changed since the last analysis. Consider running `/test-driver:analyze` to refresh."

## Step 4: End

> "Run `/test-driver:analyze` to refresh."
