# Summary Report Template

Use this template for the final output of every /up-docs command.

---

## Format

```markdown
## Documentation Update: [Layer]

**Context:** [1-2 sentence summary of what changed in the session]

| # | Page/File | Action | Summary of Changes |
|---|-----------|--------|---------------------|
| 1 | path/or/title | Created/Updated/No change needed | Brief description |
| 2 | ... | ... | ... |

**Totals:** N updated | N created | N unchanged
```

## Rules

- "Layer" is one of: Repo, Wiki, Notion, or All (with sub-sections per layer)
- "Context" derives from git diff and session activity, not user input
- Every page or file examined gets a row, even if no change was needed
- Action is exactly one of: Created, Updated, No change needed
- Summary of Changes is one sentence max
- For /up-docs:all, emit one table per layer under its own heading
- Totals line goes at the bottom of each table

## /up-docs:all Format

```markdown
## Documentation Update: All Layers

### Repo
**Context:** ...

| # | File | Action | Summary of Changes |
|---|------|--------|---------------------|
| ... | ... | ... | ... |

**Totals:** ...

### Wiki (Outline)
**Context:** ...

| # | Page | Action | Summary of Changes |
|---|------|--------|---------------------|
| ... | ... | ... | ... |

**Totals:** ...

### Notion
**Context:** ...

| # | Page | Action | Summary of Changes |
|---|------|--------|---------------------|
| ... | ... | ... | ... |

**Totals:** ...
```
