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

Read `${CLAUDE_PLUGIN_ROOT}/references/gap-analysis.md` for the full detection methodology.

1. If an argument was provided (e.g., `/test-driver:analyze src/api/`), scope the analysis to that directory.
2. Detect the project type:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-project.sh [scope-arg]
```
3. Parse the JSON. Load the matching profile from `${CLAUDE_PLUGIN_ROOT}/references/profiles/<profile>`.
4. If confidence is "low" or profile is null, offer to create one (see gap-analysis reference, "No Profile Match" section).

## Step 2: Read Prior State

Read prior state:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-status-update.sh read
```
If output shows `last_analysis: null`, this is the first analysis. Read `${CLAUDE_PLUGIN_ROOT}/references/test-status.md` for schema details.

## Step 3: Run Gap Analysis

Follow the full gap-analysis methodology (from the gap-analysis reference):

1. Inventory source files:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/inventory-sources.sh <project-type> [scope]
```

2. Inventory test files:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/inventory-tests.sh <project-type> [scope]
```

3. Check for recent changes (if prior state exists):
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/git-function-changes.sh <last-analysis-date> [scope]
```

4. **Read each source file** to enumerate functions and behaviors (this step stays with Claude — function-level behavioral enumeration requires reading code and understanding intent).

5. Map coverage by comparing source inventory functions against test inventory. Priority-boost functions from git-function-changes output. Identify and prioritize gaps — one gap per untested function/behavior, not per file.

**opus-context alignment:** Read source files fully (no offset/limit for files under 4000 lines). The function-level enumeration in step 4 is the foundation of accurate gap detection — skipping it collapses the analysis to file-level mapping, which dramatically under-reports gaps.

## Step 4: Present Results and Offer Convergence

If gaps were found, present results using Template 1 (Gap Analysis Report) from `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md`. Follow with the `AskUserQuestion` options defined in that template (fill all, fill specific, record only).

## Step 5: Report

After the convergence loop completes (or if the user chose "Record gaps only"):

1. Pipe the updated status JSON to the update script:
```bash
echo '<merged-json>' | bash ${CLAUDE_PLUGIN_ROOT}/scripts/test-status-update.sh update
```
2. Present a compact summary: gaps found, gaps filled, gaps deferred, coverage status, any source bugs fixed.
