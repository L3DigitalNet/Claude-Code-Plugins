---
name: analyze
description: Force a full gap analysis on the current project. Detects project type, loads stack profile, inventories source and test files, identifies gaps, and optionally enters a convergence loop to fill them.
argument-hint: "[optional: path to scope analysis]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# /test-driver:analyze — Gap Analysis and Test Generation

Run a full test gap analysis on the current project. Optionally enter a convergence loop to generate tests and fill the gaps.

## Step 1: Detect and Load Profile

Consult the `gap-analysis` skill for the full detection methodology.

1. If an argument was provided (e.g., `/test-driver:analyze src/api/`), scope the analysis to that directory.
2. Scan for marker files to detect the project type.
3. Load the matching stack profile skill.
4. If no profile matches, offer to create one (see gap-analysis skill, "No Profile Match" section).

## Step 2: Read Prior State

Check if `docs/testing/TEST_STATUS.json` exists:
- If present: read it. Note last analysis date, known gaps, current coverage. Consult the `test-status` skill for schema details.
- If missing: this is the first analysis. The file will be created at the end.

## Step 3: Run Gap Analysis

Follow the full gap-analysis methodology (consult the `gap-analysis` skill):

1. Determine applicable test categories from the stack profile
2. Inventory existing tests (Glob for test files, categorize by type)
3. Inventory source files (exclude non-source patterns)
4. Map coverage (structural: which source files have corresponding tests)
5. Identify and prioritize gaps

**opus-context alignment:** Read source files fully (no offset/limit for files under 4000 lines). Read test files in parallel batches.

## Step 4: Present Results and Offer Convergence

If gaps were found, present a structured summary:

```
## Gap Analysis Results

Found **N gaps** across M source files.

| Priority | File | Category | Description |
|----------|------|----------|-------------|
| high | src/api/auth.py | unit | No unit tests for token validation |
| ... | ... | ... | ... |

Coverage: X% (target: Y%)
```

Then ask via `AskUserQuestion`:

**Question:** "Found N gaps. How would you like to proceed?"
**Options:**
- "Fill all gaps" — enter convergence-loop for all identified gaps
- "Fill specific files only" — follow up with another AskUserQuestion listing gap files as options, then enter convergence-loop scoped to selection
- "Record gaps only" — update TEST_STATUS.json with gap inventory without generating tests

## Step 5: Report

After the convergence loop completes (or if the user chose "Record gaps only"):

1. Update `docs/testing/TEST_STATUS.json` per the `test-status` skill's update rules.
2. Present a compact summary: gaps found, gaps filled, gaps deferred, coverage status, any source bugs fixed.
