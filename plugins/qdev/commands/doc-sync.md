---
name: doc-sync
description: Sync inline documentation with current function signatures and behavior. Proposes additions for undocumented functions and updates for stale docs before writing anything.
argument-hint: "[optional: path to file or directory]"
allowed-tools:
  - Read
  - Glob
  - Grep
  - Bash
  - Edit
  - AskUserQuestion
---

# /qdev:doc-sync

Bring inline code documentation in sync with the current implementation.

## Step 1: Establish Scope

If `$ARGUMENTS` is provided, use it as the target path.

Otherwise, scan for source files:

```bash
find . -type f \( \
  -name "*.py" -o -name "*.ts" -o -name "*.tsx" \
  -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.go" -o -name "*.rs" \
\) \
  -not -path "*/.git/*" \
  -not -path "*/node_modules/*" \
  -not -path "*/__pycache__/*" \
  -not -path "*/.venv/*" \
  -not -path "*/dist/*" \
  -not -path "*/build/*" | sort
```

Read each file found. If the total count of undocumented public functions across all files exceeds 25, use `AskUserQuestion`:
- header: `"Scope"`
- question: `"Found N undocumented public functions across M files. How would you like to proceed?"`
- options:
  1. label: `"All N functions"`, description: `"Document everything found"`
  2. label: `"Exported/public only"`, description: `"Focus on the public API surface"`
  3. label: `"Specify a path"`, description: `"I'll narrow the scope to a file or directory"`

If `"Specify a path"` is chosen: ask `"Which file or directory should I focus on?"` as a follow-up open-ended question, then re-run Step 1 scoped to that path.

## Step 2: Detect Documentation Convention

From the source files, identify the style already in use:

- **Python**: detect Google style (`Args:\n    param: desc`), NumPy style (`Parameters\n---`), or reStructuredText (`:param name:`). Default to Google style if none found.
- **TypeScript / JavaScript**: detect JSDoc (`@param`, `@returns`) or TSDoc. Default to JSDoc.
- **Go**: standard doc comment (plain line comment directly before the declaration).
- **Rust**: `///` line comments or `/** */` block comments. Default to `///`.

Note the detected convention. All generated documentation must follow it.

## Step 3: Inventory and Analyze

For each source file in scope, identify:

**ADD** — public functions, methods, classes, and exported types with no doc comment. For Python, exclude `__init__` unless it has non-trivial parameters beyond `self`. For TypeScript/JavaScript, focus on exported declarations. For Go and Rust, focus on exported (capitalized) identifiers.

**UPDATE** — documented functions where the current signature does not match the docs:
- A parameter exists in the signature but is missing from the docs (or vice versa)
- A parameter name has been renamed since the doc was written
- A `@returns` or return description contradicts the current return type annotation
- The doc references a parameter or behavior that no longer exists in the function

For each `ADD` finding, generate the complete proposed doc comment now, before Step 4. Use the function signature, parameter types, return type, and function body to infer intent. Write the full comment in the detected convention.

For each `UPDATE` finding, generate the corrected version of the existing doc comment.

## Step 4: Propose Changes

Before writing anything, present the full list:

```
Proposed doc changes (N changes across M files):
  [ADD]     <file>:<line> — <function_name>: <one-line description of what will be added>
  [UPDATE]  <file>:<line> — <function_name>: <what is stale and how it will be corrected>
```

If there are no changes, emit:

```
All public functions are documented and up to date.
```

and stop.

Otherwise, use `AskUserQuestion`:
- question: `"How would you like to review these N proposed doc changes?"`
- options:
  1. label: `"Approve all"`, description: `"Apply all N changes without individual review"`
  2. label: `"Review each one"`, description: `"Approve or skip each change individually"`
  3. label: `"Cancel"`, description: `"Make no changes"`

If `"Cancel"` is chosen: emit `No changes made.` and stop.

For `"Review each one"`, present each proposed change with `AskUserQuestion`:
- header: `"Change [N/Total]"`
- question: `"[ADD | UPDATE] <file>:<function_name>\n\n<full proposed doc comment>"`
- options:
  1. label: `"Apply"`, description: `"Insert or replace this doc comment"`
  2. label: `"Skip"`, description: `"Leave this function unchanged"`

## Step 5: Apply and Summarize

Apply all approved changes using the `Edit` tool. For `ADD`: insert the new doc comment immediately before the function or class declaration. For `UPDATE`: replace the existing doc comment in place. Never rewrite the function body.

After all edits, emit:

```
Doc sync complete: N added, N updated.
```

If no changes were approved (all skipped or zero approvals), emit `No changes applied.` instead.
