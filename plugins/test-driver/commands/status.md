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

Read the status file via script:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-status-update.sh read
```

If the output shows `last_analysis: null` or the file does not exist:
> "No test status file found. Run `/test-driver:analyze` to create one."

Stop here.

## Step 2: Render Summary

Present a compact summary using Template 3 (Test Posture Summary) from `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md`.

## Step 3: Staleness Check

Check for staleness using two signals:

1. **Time-based:** If `last_analysis.date` is more than 7 days ago, the status is likely stale.
2. **Change-based:** Run `git log --since="<last_analysis_date>" --oneline --stat -- "*.py" "*.swift" "*.ts"` to check for source changes since the last analysis. If changes exist, also estimate scope: `git log --since="<last_analysis_date>" -p -- <source_files> | grep -c "^[+-].*def \|^[+-].*async def \|^[+-].*func "` to count how many function signatures were added or modified.

If either signal fires, emit Template 4 (Staleness Warning) from `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md`. Include the count of modified source files and estimated function changes to help the user gauge how stale the analysis is.

## Step 4: End

> "Run `/test-driver:analyze` to refresh."
