# Pass Report Template

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

### Convergence
| Pass | Upheld | Partial | Violated | Checkpoints | UX Issues | Stale Docs | Trend |
|------|--------|---------|----------|-------------|-----------|------------|-------|
| 1    | ...    | ...     | ...      | ...         | ...       | ...        | —     |
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

### Convergence
| Pass | Upheld | Partial | Violated | Checkpoints | UX Issues | Stale Docs | Trend |
|------|--------|---------|----------|-------------|-----------|------------|-------|
| ...  | ...    | ...     | ...      | ...         | ...       | ...        | ...   |
```

## Rules

Open findings get detail. Clean items get roll-ups. Always include the convergence table. On Pass 3+, add a budget notice if findings remain.
