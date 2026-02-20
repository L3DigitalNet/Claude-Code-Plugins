# Final Report Template

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
(grouped by pass; "No files modified — review-only session" if none)
```

## Rules

Every principle from the original checklist must appear in Principle Status. Every checkpoint must appear in Checkpoint Status. Touchpoints clean from Pass 1 can be summarized in one line. Documentation Status lists every reviewed file. Accepted Gaps includes enough context for someone reading months later.
