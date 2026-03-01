# Pass Report Template

<!-- architectural-context
  Loaded by: commands/review.md (orchestrator) at Phase 3, after receiving subagent summaries.
  Not loaded by subagents — subagents return structured text; the orchestrator formats it
    using this template. If subagents load this template, it violates [P3].
  Output contract: the Convergence table columns (Tier1/Tier2/Tier3/Upheld/Partial/Violated/
    Checkpoints/UX Issues/Stale Docs/Confidence/Trend) must be consistent across all passes
    so that final-report.md's Pass History table can aggregate them correctly.
  Cross-file dependency: final-report.md's Pass History table uses the same column names.
    Changing column headers here requires updating final-report.md's Pass History section.
  Autonomous mode additions: Tier1/Tier2/Tier3 columns added to Convergence table (populated
    from tier_counts in state). Regression Guard section added to Pass 2+ format. Both are
    omitted when --autonomous is not set.
  Track D addition: "Context Efficiency" summary line added to Pass 1 Summary block.
    "Open Findings — Context Efficiency" section added after Documentation in Pass 1 Format.
-->

Use this template to format the unified findings report after collecting subagent summaries.

## Pass 1 Format

Lead with open findings. Roll up clean items.

```
## Plugin Review: <plugin-name> — Pass 1

### Summary
- Principles: <N> checked | <N> upheld | <N> partial | <N> violated
- Checkpoints: <N> checked | <status per checkpoint>
- UX touchpoints: <N> reviewed | <N> clean | <N> with issues
- Documentation: <N> files reviewed | <N> current | <N> stale
- Context Efficiency: <N> checked | <N> upheld | <N> partial | <N> violated
- Open findings: <N> total

### Upheld (no action needed)
Principles <list IDs> are fully upheld. UX touchpoints for <list names> are clean. Docs for <list paths> are current.

### Open Findings — Principles

#### [Pn] <Principle Name> — <STATUS>
**Principle**: <definition>
**Evidence**: <what supports/contradicts>
**Gap**: <specific misalignment>
**Enforcement layer**: <actual> → **Expected**: <what principle implies>

### Open Findings — Checkpoints
(only checkpoints with status below "Good")

#### [Cn] <Checkpoint Name> — <STATUS>
**Key gaps**: <brief list of what's missing or wrong>
**Worst offenders**: <specific files or patterns>

### Open Findings — Root Architectural Alignment
(only items with gaps)

### Open Findings — UX
🔴 **High**: <touchpoint> — <issue summary>
🟡 **Medium**: <touchpoint> — <issue summary>
🟢 **Low**: <touchpoint> — <issue summary>

### Open Findings — Documentation
- **<file path>**: <issue type> — <brief description>. Triggered by: <pre-existing / Pass N changes>.

### Open Findings — Context Efficiency

#### [Pn] <Principle Name> — <STATUS>
**Principle**: <one-line definition>
**Evidence**: <what supports/contradicts, with file reference>
**Gap**: <specific misalignment — what should be different>

### Convergence
| Pass | Tier1 | Tier2 | Tier3 | Upheld | Partial | Violated | Checkpoints | UX Issues | Stale Docs | Confidence | Trend |
|------|-------|-------|-------|--------|---------|----------|-------------|-----------|------------|------------|-------|
| 1    | —     | —     | —     | ...    | ...     | ...      | ...         | ...       | ...        | N%         | —     |
(Tier1/Tier2/Tier3 columns: autonomous mode only — omit if --autonomous not set)
```

## Pass 2+ Format

Focus on what changed. Unchanged items get one-line confirmation.

```
## Plugin Review: <plugin-name> — Pass <N>

### Summary
- Open findings: <N> total (was <N> last pass)
- Resolved this pass: <N> | New this pass: <N> | Unchanged: <N>
- Trend: <↑ improving / → stable / ↓ regressing>

### Resolved
- [Pn] <Principle> — now Upheld ✅
- UX: <touchpoint> — fixed ✅
- Docs: <file> — updated ✅

### Status Changes
(findings that moved between categories but aren't fully resolved)

### New Findings
(findings introduced by changes in the previous pass)

### Unchanged Open Findings
(one line each)

### Regression Guard [AUTONOMOUS MODE, PASS 2+ ONLY]
(omit if --autonomous not set or no previously-fixed findings)
- <finding_id> — <Holding ✅ | Regressed ❌ | Indeterminate ⚠️> — <one-line evidence>
- Summary: <N> holding, <N> regressed, <N> indeterminate

### Convergence
| Pass | Tier1 | Tier2 | Tier3 | Upheld | Partial | Violated | Checkpoints | UX Issues | Stale Docs | Confidence | Trend |
|------|-------|-------|-------|--------|---------|----------|-------------|-----------|------------|------------|-------|
| ...  | —     | —     | —     | ...    | ...     | ...      | ...         | ...       | ...        | N%         | ...   |
(Tier1/Tier2/Tier3 columns: autonomous mode only — omit if --autonomous not set)
```

## Rules

Open findings get detail. Clean items get roll-ups. Always include the convergence table. On Pass 3+, add a budget notice if findings remain.
