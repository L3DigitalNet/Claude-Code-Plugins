---
name: test-status
description: >
  Persistent test status file management. Governs reading and writing docs/testing/TEST_STATUS.json,
  the persistent record of a project's testing posture. Use when checking test status, updating
  test results, reading TEST_STATUS.json, writing test reports, tracking test history, or
  managing deferred test gaps.
---

# Test Status: Persistent State Management

Governs the `docs/testing/TEST_STATUS.json` file, which tracks a project's testing posture across sessions. This path is a convention default; projects without a `docs/` directory get it created on first analysis.

## JSON Schema

```json
{
  "project": "project-name",
  "stack_profile": "python-fastapi",
  "last_analysis": {
    "date": "2026-03-16T14:30:00Z",
    "source_files_analyzed": 42,
    "gaps_found": 7,
    "gaps_filled": 5,
    "gaps_deferred": 2
  },
  "categories": {
    "unit": {
      "applicable": true,
      "test_count": 38,
      "passing": 38,
      "failing": 0
    },
    "integration": {
      "applicable": true,
      "test_count": 12,
      "passing": 11,
      "failing": 1
    },
    "e2e": {
      "applicable": true,
      "test_count": 4,
      "passing": 4,
      "failing": 0
    },
    "ui": {
      "applicable": false
    },
    "contract": {
      "applicable": true,
      "test_count": 0,
      "passing": 0,
      "failing": 0
    },
    "security": {
      "applicable": false
    }
  },
  "coverage": {
    "target_percent": 80,
    "current_percent": 74,
    "tool": "coverage.py"
  },
  "known_gaps": [
    {
      "file": "src/api/auth.py",
      "category": "integration",
      "description": "No test for token refresh with expired session",
      "priority": "high",
      "reason_deferred": null
    }
  ],
  "source_bugs_fixed": [
    {
      "date": "2026-03-16T14:35:00Z",
      "file": "src/api/auth.py",
      "description": "Off-by-one in token expiry check: used < instead of <=",
      "test_that_caught_it": "test_auth_token_expiry_boundary"
    }
  ],
  "history": [
    {
      "date": "2026-03-16T14:30:00Z",
      "action": "gap_analysis",
      "summary": "7 gaps found across unit and integration categories"
    }
  ]
}
```

### Field Notes

- **`categories`**: All six categories are present. Non-applicable categories have `"applicable": false` and no count fields.
- **`coverage`**: Only populated after a convergence loop runs the coverage tool. `target_percent` comes from the stack profile (default: 80). `tool` records which coverage tool was used.
- **`known_gaps`**: Active gaps. `reason_deferred` is null for unfilled gaps, or a string explaining why the gap was deferred.
- **`source_bugs_fixed`**: Bugs in source code that were found and fixed autonomously during a convergence loop.
- **`history`**: Append-only log of analysis and convergence actions.

## Update Rules

### Session Start

If `docs/testing/TEST_STATUS.json` exists, read it to understand the project's current testing posture. Note:
- When was the last analysis? (stale if more than 7 days or if significant source changes since)
- How many known gaps exist?
- What is the current coverage vs target?
- Are any tests failing?

Use this information to calibrate whether testing should be a priority during the session.

### After Gap Analysis

Update these fields:
- `last_analysis.date` — current ISO-8601 timestamp
- `last_analysis.source_files_analyzed` — count from the analysis
- `last_analysis.gaps_found` — total gaps identified
- `last_analysis.gaps_filled` — 0 (analysis doesn't fill gaps)
- `last_analysis.gaps_deferred` — 0 (fresh analysis resets deferrals)
- `categories` — refresh test counts per category from the inventory
- `known_gaps` — replace with the current gap list from the analysis

### After Convergence Loop

Update these fields:
- `last_analysis.gaps_filled` — increment by gaps filled during the loop
- `last_analysis.gaps_deferred` — count of gaps remaining with reason_deferred set
- `categories` — update test counts and pass/fail status
- `coverage` — update current_percent if coverage was measured
- `source_bugs_fixed` — append any bugs fixed during this loop
- `known_gaps` — remove filled gaps; set `reason_deferred` on remaining gaps
- `history` — append entry with date, action "convergence_loop", and summary

### Create if Missing

On first analysis of a new project, create `docs/testing/` directory and `TEST_STATUS.json` with all fields initialized. Set `project` from the directory name or manifest, `stack_profile` from detection, and empty arrays for gaps, bugs, and history.

## Deferred Gaps

Gaps get `reason_deferred` set in two cases:

1. **User declines the convergence loop** after gap analysis. All unfilled gaps are recorded with `reason_deferred: "User deferred"`.
2. **Max iterations reached** during convergence loop. Remaining unfilled gaps are recorded with `reason_deferred: "Max iterations reached"`.

Deferred gaps persist across sessions. A future gap analysis will re-evaluate them: if the gap is still present, it remains; if the source changed such that the gap no longer applies, it is removed.
