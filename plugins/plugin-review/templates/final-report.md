# Final Report Template

<!-- architectural-context
  Loaded by: commands/review.md (orchestrator) at Phase 6 only — when the review loop
    terminates. Not loaded during the review loop itself.
  Not loaded by subagents. If loaded mid-review, the orchestrator terminated prematurely.
  Output contract: the Pass History table aggregates convergence data from all passes.
    Column names must match pass-report.md's Convergence table. If pass-report.md columns
    change, update the Pass History table here to match.
  Cross-file dependency: pass-report.md defines the data format for each row in Pass History.
    The Principle Status table uses the same status vocabulary as track-a-criteria.md.
-->

Use this template when the review loop terminates (Phase 6).

```
## Final Review State: <plugin-name>

### Convergence: <Zero findings / User-accepted / Budget-reached / Plateau / Divergence>
### Passes completed: <N>

### Pass History
| Pass | Upheld | Partial | Violated | Checkpoints | UX Issues | Stale Docs | Changes made |
|------|--------|---------|----------|-------------|-----------|------------|--------------|
| 1    | ...    | ...     | ...      | ...         | ...       | ...        | (initial)    |
| 2    | ...    | ...     | ...      | ...         | ...       | ...        | <brief list> |

### Principle Status
| ID  | Principle        | Status | Enforcement Layer | Notes |
|-----|------------------|--------|-------------------|-------|
| P1  | <short name>     | ✅     | Mechanical        |       |
| P2  | <short name>     | ⚠️     | Behavioral        | Accepted gap: <reason> |

### Checkpoint Status
| ID  | Checkpoint              | Status   | Notes |
|-----|-------------------------|----------|-------|
| C1  | LLM-Optimized Commenting | <status> | <key findings or "Good — no action needed"> |

### UX Status
| Touchpoint       | Category           | Status | Notes |
|------------------|--------------------|--------|-------|
| <tool/output>    | <UX category>      | ✅     |       |
| <tool/output>    | <UX category>      | ⚠️     | Accepted: <reason> |

### Documentation Status
| File             | Status       | Notes |
|------------------|--------------|-------|
| README.md        | ✅ Current   |       |
| docs/DESIGN.md   | ✅ Updated   | Updated in Pass 2 |

### Accepted Gaps
(omit if none)
- **[Pn] <Principle>**: <description and rationale>

### Files Modified
(grouped by pass; omit if no files were modified during the review)
```

## Rules

Every principle from the original checklist must appear in Principle Status. Every checkpoint must appear in Checkpoint Status. Touchpoints clean from Pass 1 can be summarized in one line. Documentation Status lists every reviewed file. Accepted Gaps includes enough context for someone reading months later.
