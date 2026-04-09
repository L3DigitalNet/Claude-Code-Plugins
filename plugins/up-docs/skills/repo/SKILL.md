---
name: up-repo
description: "Update repository documentation (README.md, docs/, CLAUDE.md) based on session changes. This skill should be used when the user runs /up-docs:repo."
argument-hint: ""
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# /up-docs:repo

Update the active repository's documentation files to reflect work done in the current session.

## Workflow

### 1. Assess Session Context

Gather what changed during the session:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Also consider the conversation history: files discussed, features implemented, bugs fixed, configuration changes made. Build a mental model of what the session accomplished.

### 2. Locate Documentation Files

Read the project CLAUDE.md for any `## Documentation` section that specifies which files to update.

If no explicit mapping exists, discover documentation files:

```bash
# Find all markdown docs in standard locations
find . -maxdepth 1 -name "*.md" -type f
find ./docs -name "*.md" -type f 2>/dev/null
```

Common targets: `README.md`, `CLAUDE.md`, `CHANGELOG.md`, `docs/*.md`, and any other `.md` files at the project root or in `docs/`.

### 3. Read and Evaluate Each File

Read every candidate documentation file. For each one, determine whether the session's changes make any part of it stale or incomplete.

Evaluation criteria:
- Does the file describe features, commands, or configuration that changed this session?
- Are there sections that reference files, functions, or behavior that no longer match?
- Is anything new from this session missing from the documentation?

Skip files that are clearly unaffected by the session's work.

### 4. Draft and Apply Updates

For each file that needs changes:
- Read the file's current content in full
- Preserve the existing tone, structure, and formatting
- Make targeted edits; do not rewrite sections that are still accurate
- Add new content where the session introduced something not yet documented
- Remove or correct content that the session's changes have invalidated

Do not add boilerplate, badges, or sections that the file doesn't already have. Match the document's existing conventions.

### 5. Summary Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the output format.

Emit the summary report using the **Repo** layer format. Every file examined gets a row in the table, including files where no changes were needed.
