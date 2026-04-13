---
name: spec-update
description: One-shot sync that brings a spec or design document up to date with the current implementation. Identifies features added, behaviors changed, sections now stale, and removed features. Proposes all changes before writing anything.
argument-hint: "[optional: path to spec/design file]"
allowed-tools:
  - Read
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# /qdev:spec-update

Bring a spec or design document up to date with the current implementation.

## Step 1: Locate Spec

If `$ARGUMENTS` is provided, use it as the spec path. Read the file with the `Read` tool. If the file does not exist, report `File not found: <path>` and stop.

Otherwise, search for spec candidates:

```bash
find . -maxdepth 3 -name "*.md" -not -path "*/.git/*" | xargs grep -l "" 2>/dev/null | sort
```

Filter to files whose **filename** (not directory path) contains `spec`, `design`, or `architecture`. For example, `docs/superpowers/specs/my-spec.md` qualifies; `spec-output/notes.md` does not (the keyword is in the directory name, not the filename). If multiple candidates exist, use `AskUserQuestion` to present them as bounded choices (up to 4). If no candidates are found, report:

```
No spec file found. Provide the path explicitly:
  /qdev:spec-update path/to/spec.md
```

and stop.

## Step 2: Read and Compare

Read the spec file in full.

Locate and read all source files in the project:

```bash
find . -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.sh" -o -name "*.rb" \) \
  -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/__pycache__/*" | sort
```

Read `CHANGELOG.md` if it exists at the project root. Read all files under `docs/` if the directory exists.

Compare the spec against the full implementation. Identify:

- **Features added**: behaviors or components present in the code that are absent from the spec
- **Behaviors changed**: code behavior that contradicts what the spec currently describes
- **Sections now stale**: spec language that describes how something worked previously, not how it works now
- **Removed features**: spec sections describing functionality that no longer exists in the codebase

## Step 3: Propose Changes

Before writing anything, present the full list of proposed changes:

```
Proposed spec updates (N changes):
  [ADD]     <section name or location> — document <what needs to be added>
  [UPDATE]  <section name> — <old behavior> → <new behavior>
  [REMOVE]  <section name> — <feature> no longer exists in the codebase
```

If there are no changes needed, report:

```
Spec is up to date — no changes needed.
```

and stop.

Otherwise, use `AskUserQuestion`:
- question: `"How would you like to review these N proposed changes?"`
- options:
  1. label: `"Approve all"`, description: `"Apply all N changes without individual review"`
  2. label: `"Review each one"`, description: `"Approve or skip each change individually"`
  3. label: `"Cancel"`, description: `"Make no changes"`

If `"Cancel"` is chosen, emit `No changes made.` and stop.

For `"Review each one"`, present each proposed change with `AskUserQuestion`:
- header: `"Change [N/Total]"`
- question: `"[ADD | UPDATE | REMOVE] <section>\n\n<what changes and why>"`
- options:
  1. label: `"Apply"`, description: `"Make this change"`
  2. label: `"Skip"`, description: `"Leave this section unchanged"`

## Step 4: Apply and Summarize

Apply all approved changes using the `Edit` tool. "Approved" means the user selected `Apply` for that change in the per-item review, or all changes when `Approve all` was chosen. Changes where the user selected `Skip` are not applied. Use targeted edits: change only the specific section identified in Step 3. Never rewrite the entire file.

After all edits are applied, emit:

```
Spec updated: N additions, N modifications, N removals.
```

If no changes were approved (all were skipped or the session produced zero approvals), emit `No changes applied.` instead of the summary and stop.
