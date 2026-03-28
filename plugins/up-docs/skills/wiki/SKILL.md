---
name: up-wiki
description: "Update Outline wiki documentation with implementation-level details from the current session. This skill should be used when the user runs /up-docs:wiki."
argument-hint: ""
allowed-tools: Read, Glob, Grep, Bash, mcp__plugin_mcp-outline_mcp-outline__search_documents, mcp__plugin_mcp-outline_mcp-outline__read_document, mcp__plugin_mcp-outline_mcp-outline__update_document, mcp__plugin_mcp-outline_mcp-outline__create_document, mcp__plugin_mcp-outline_mcp-outline__list_collections, mcp__plugin_mcp-outline_mcp-outline__get_collection_structure
---

# /up-docs:wiki

Update the Outline wiki to reflect implementation-level changes from the current session.

## What Belongs in the Wiki

Outline is the implementer's reference shelf. Content answers: *does this help an implementer execute correctly without guessing?*

Write in the wiki:
- Configuration details and environment variables
- Service-specific procedures and deployment steps
- Code patterns, integration notes, troubleshooting steps
- Command references and CLI usage
- Architecture decisions with technical rationale
- How authentication, networking, and dependencies are wired

Do not write in the wiki:
- Strategic reasoning or project goals (those go in Notion)
- Personal records, plans, or life admin
- Content that duplicates what's already in the repo's own docs

## Workflow

### 1. Assess Session Context

Gather what changed:

```bash
git diff --stat HEAD~5 HEAD 2>/dev/null || git diff --stat
git log --oneline -10
```

Combine with conversation history to build a picture of what the session accomplished: services configured, code written, bugs fixed, infrastructure changed.

### 2. Find the Wiki Mapping

Read the project's CLAUDE.md for a `## Documentation` section (or similar) that indicates which Outline collection or document area corresponds to this project.

If no explicit mapping exists, search Outline for the project name or key terms from the session:

```
search_documents(query: "<project name or service name>")
```

### 3. Read Current Wiki Pages

For each relevant page found, read its full content. Understand its current state before making changes.

If the collection has a structure, browse it:

```
get_collection_structure(id: "<collection_id>")
```

Identify pages that cover the topics affected by this session's work.

### 4. Draft and Apply Updates

For each page that needs changes:
- Fetch the current content first; never update from memory
- Make targeted updates; preserve existing structure and tone
- Add new sections where the session introduced something not yet documented
- Correct any content the session's changes have invalidated
- Keep the detail level technical and concrete: configs, commands, procedures

For new topics with no existing page, create a new document in the appropriate collection. Title it clearly and place it at the right level in the collection hierarchy.

### 5. Summary Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the output format.

Emit the summary report using the **Wiki (Outline)** layer format. Every page examined gets a row, including pages where no changes were needed.

## Ground Truth

The live server or repository is ground truth. If the wiki says one thing and the actual configuration says another, update the wiki to match reality. The wiki may lag slightly, but when there's a conflict, what's actually running wins.
