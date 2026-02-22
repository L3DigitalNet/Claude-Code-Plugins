# Autonomous Refactor Report — {{DATE}}

## Target Files

{{TARGET_FILES}}

---

## Metrics Comparison

| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Lines of Code | {{BEFORE_LOC}} | {{AFTER_LOC}} | {{LOC_DELTA}} |
| Avg Cyclomatic Complexity | {{BEFORE_COMPLEXITY}} | {{AFTER_COMPLEXITY}} | {{COMPLEXITY_DELTA}} |
| Principles Alignment Score | {{BEFORE_SCORE}}/100 | {{AFTER_SCORE}}/100 | {{SCORE_DELTA}} |

> Complexity source: {{COMPLEXITY_TOOL}}. If `ai-estimated`, values are qualitative approximations.

---

## Changes Applied ({{COMPLETED_COUNT}} of {{TOTAL_OPPORTUNITIES}} opportunities)

| # | Opportunity | Priority | Result | Files Changed |
|---|-------------|----------|--------|---------------|
{{CHANGE_TABLE_ROWS}}

### Skipped Opportunities

{{SKIPPED_LIST}}

> Skipped reasons: `oscillation` = reverted twice; `out_of_scope` = required >3 file changes

---

## Diff Summary

{{DIFF_SUMMARY}}

---

## Convergence

**Reason:** {{CONVERGENCE_REASON}}

Options:
- `All opportunities addressed` — full session completed
- `max_changes reached (N)` — hit the change limit; use `--max-changes=N` to increase
- `Oscillation detected` — one or more changes were unstable; manual review recommended
