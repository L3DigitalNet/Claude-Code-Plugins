# Convergence Metrics Template

<!-- architectural-context
  Loaded by: commands/review.md Phase 6 [AUTONOMOUS MODE ONLY] — only when --autonomous was set.
  Never loaded during the review loop or by subagents.
  Output contract: the orchestrator substitutes placeholder values and appends this section
    to the final-report.md output. All values come from .claude/state/plugin-review-writes.json:
    mode, start_time, tier_counts, fixed_findings, build_test_failures, regression_guard_regressions.
  Cross-file dependency: final-report.md references this template by name in its Convergence Metrics
    section. If the format here changes, update final-report.md's Rules section to match.
-->

Use this section when `--autonomous` was set. Append it to the final report after `### Files Modified`.

```
### Convergence Metrics
- Mode: autonomous
- Total passes: <N>  |  Time to convergence: <Xm Ys>
- Total findings discovered: <N>  →  <N> resolved  |  <N> open (accepted gaps)
- Tier 1 auto-fixed (docs/formatting):  <N>
- Tier 2 auto-fixed (error handling/validation):  <N>
- Tier 3 auto-fixed (architectural/behavioral):  <N>
- Regressions caught by guard: <N>  (<N> resolved, <N> accepted)
- Build/test failures encountered: <N>  (<N> resolved by fix-forward agent, <N> unresolvable)
```

## Rules

Omit this section entirely if `--autonomous` was not set — do not emit a partial or zeroed-out metrics block for interactive mode sessions.

**Time format**: compute elapsed as `(end_time - start_time)` from the ISO timestamps in state. Format as `Xm Ys` (e.g., `4m 32s`). If under 60s, use `Ys` only.

**Findings counts**: "Total findings discovered" is the union of all unique finding IDs seen across all passes. "Resolved" means confidence eventually reached pass for those assertions, or the finding was marked fixed in `fixed_findings`. "Open (accepted gaps)" are findings that remain open at convergence — either budget was reached or they were explicitly accepted.

**Tier counts**: read `tier_counts.t1`, `tier_counts.t2`, `tier_counts.t3` from state. These are cumulative across all passes.

**Regressions**: "caught" = `regression_guard_regressions` total from state. "Resolved" = ones where a subsequent pass re-fixed. "Accepted" = ones that remained regressed at convergence.

**Build/test failures**: total `build_test_failures` count from state. Resolved = build-fix-agent successfully fixed. Unresolvable = escalated without fix.
