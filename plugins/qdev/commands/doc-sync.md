---
name: doc-sync
description: Sync inline documentation with current function signatures via qdev-doc-syncer subagent (Haiku). Propose before apply.
argument-hint: "[optional: path to file or directory]"
allowed-tools:
  - Agent
  - AskUserQuestion
---

# /qdev:doc-sync

Bring inline code documentation in sync with current function signatures by dispatching the `qdev-doc-syncer` subagent.

## Why this is a subagent

Enumerating public symbols + reading function bodies + generating docstrings across a source tree is mechanical translation work. Running it in Opus costs ~12K tokens per sync. Haiku handles signature-to-docstring mapping cleanly; the subagent keeps raw source content out of the Opus context.

## How to run it

1. Determine the scope. If `$ARGUMENTS` is provided, use it. Otherwise, default to `./` (or `src/` if present at repo root).

2. Dispatch `qdev-doc-syncer` in **dry-run mode first** so the user can review proposals before any edits.

   Use the `Agent` tool with `subagent_type: qdev:qdev-doc-syncer` and a prompt like:

   > Sync inline docs in `<scope>`. Set dry_run=true. Inventory, classify (Missing / Stale / Current / manual-review-needed), and return the proposals table. Do not apply any edits in this run.

## After the dry-run returns

1. If the response shows zero Missing/Stale symbols, emit:
   ```
   ✓ All public functions are documented and up to date.
   ```
   and stop.

2. If the proposals count is >25, use `AskUserQuestion` to narrow scope first:
   - question: `"Found N proposed doc changes across M files. How would you like to proceed?"`
   - options:
     1. label: `"Apply all N"`, description: `"Accept all proposals without individual review"`
     2. label: `"Public-surface only"`, description: `"Filter to exported/public API"`
     3. label: `"Narrow to a path"`, description: `"I'll specify a subdirectory"`
     4. label: `"Review each one"`, description: `"Approve or skip each proposal"`
     5. label: `"Cancel"`, description: `"Make no changes"`

3. If the proposals count is ≤25, skip the scope-narrowing prompt and go straight to:
   - question: `"Apply the N proposed doc changes?"`
   - options:
     1. label: `"Apply all"`, description: `"Apply all proposals"`
     2. label: `"Review each one"`, description: `"Approve each individually"`
     3. label: `"Cancel"`, description: `"Make no changes"`

4. Based on the choice:

   - **Apply all / Apply all N:** re-dispatch the subagent with `dry_run=false` and the same scope. Present the applied-edits summary.

   - **Public-surface only / Narrow to a path:** re-dispatch the subagent with `dry_run=false` and the narrowed scope.

   - **Review each one:** for each proposal, use `AskUserQuestion`:
     - header: `"Change [N/Total]"`
     - question: `"[ADD | UPDATE] <file>:<symbol>\n\n<full proposed doc comment>"`
     - options:
       1. label: `"Apply"`, description: `"Insert or replace this doc comment"`
       2. label: `"Skip"`, description: `"Leave unchanged"`

     Apply approved changes via `Edit` in this session (do not re-dispatch the agent for individual edits).

   - **Cancel:** emit `No changes made.` and stop.

5. Final summary:
   ```
   Doc sync complete: N added, M updated, K skipped.
   ```
