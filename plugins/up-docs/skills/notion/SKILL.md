---
name: up-notion
description: "Update Notion pages with strategic and organizational context from the current session. This skill should be used when the user runs /up-docs:notion."
argument-hint: ""
allowed-tools: Read, Glob, Grep, Bash, mcp__plugin_Notion_notion__notion-search, mcp__plugin_Notion_notion__notion-fetch, mcp__plugin_Notion_notion__notion-update-page, mcp__plugin_Notion_notion__notion-create-pages
---

# /up-docs:notion

Update Notion to reflect the strategic and organizational impact of the current session's work.

## What Belongs in Notion

Notion is the project manager's desk. Content answers: *does this help a project manager understand the landscape and make decisions?*

Before writing or updating any Notion page, read the detailed guidelines in `${CLAUDE_PLUGIN_ROOT}/skills/notion/references/notion-guidelines.md`. Those guidelines govern tone, structure, and content boundaries.

Key principles:
- Write about what exists, why it exists, relationships, status, and decisions
- Use plain narrative prose; tables for structured data surrounded by explanatory context
- Never add code, configs, or step-by-step procedures
- Preserve the existing tone and information level of each page
- Fetch every page before editing; never update from memory

## Workflow

### 1. Assess Session Context

Gather what changed:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history. Focus on the *strategic* impact: what was accomplished, what decisions were made, what changed in the project's landscape. Filter out implementation details.

### 2. Find the Notion Mapping

Read the project's CLAUDE.md for a `## Documentation` section that indicates which Notion area corresponds to this project (page name, database, or section).

If no explicit mapping exists, search Notion:

```
notion-search(query: "<project name>")
```

### 3. Read Current Notion Pages

Fetch each relevant page to understand its current state:

```
notion-fetch(resourceUri: "notion://page/<page-id>")
```

Understand the page's existing structure, tone, and level of detail before planning changes.

### 4. Draft and Apply Updates

For each page that needs changes:
- Make targeted updates that match the page's existing style
- Add or update status, context, and decisions from this session
- Update relationship information if dependencies or integrations changed
- Note new components, services, or initiatives at the organizational level
- Do not add implementation detail; link to the Outline wiki when technical depth exists

For genuinely new topics not covered by any existing page, create a new page in the appropriate location with clear purpose framing in the opening lines.

### 5. Summary Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the output format.

Emit the summary report using the **Notion** layer format. Every page examined gets a row, including pages where no changes were needed.

## Ground Truth

The live server or repository is ground truth for both documentation layers. Notion may lag slightly on intent documentation, and that is acceptable. But when there's a factual conflict, what's actually running wins. Update Notion to reflect reality rather than preserving outdated intent.
