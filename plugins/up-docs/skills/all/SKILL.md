---
name: up-all
description: "Update all three documentation layers (repo, wiki, Notion) sequentially from the current session. This skill should be used when the user runs /up-docs:all."
argument-hint: ""
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, mcp__plugin_mcp-outline_mcp-outline__search_documents, mcp__plugin_mcp-outline_mcp-outline__read_document, mcp__plugin_mcp-outline_mcp-outline__update_document, mcp__plugin_mcp-outline_mcp-outline__create_document, mcp__plugin_mcp-outline_mcp-outline__list_collections, mcp__plugin_mcp-outline_mcp-outline__get_collection_structure, mcp__plugin_Notion_notion__notion-search, mcp__plugin_Notion_notion__notion-fetch, mcp__plugin_Notion_notion__notion-update-page, mcp__plugin_Notion_notion__notion-create-pages
---

# /up-docs:all

Update all three documentation layers in sequence: Repo, then Wiki, then Notion.

## Workflow

### 1. Assess Session Context (once)

Gather the session's changes up front, since all three layers draw from the same context:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
```

Combine with conversation history. Build a complete picture of what the session accomplished.

### 2. Update Repo Docs

Follow the full procedure from `${CLAUDE_PLUGIN_ROOT}/skills/repo/SKILL.md`:
- Locate documentation files (README.md, docs/, CLAUDE.md)
- Read and evaluate each file against session changes
- Apply targeted updates where needed
- Track results for the summary

### 3. Update Wiki (Outline)

Follow the full procedure from `${CLAUDE_PLUGIN_ROOT}/skills/wiki/SKILL.md`:
- Find the Outline mapping from CLAUDE.md or by searching
- Read current wiki pages
- Apply implementation-level updates
- Track results for the summary

### 4. Update Notion

Follow the full procedure from `${CLAUDE_PLUGIN_ROOT}/skills/notion/SKILL.md` (and read `${CLAUDE_PLUGIN_ROOT}/skills/notion/references/notion-guidelines.md` before making changes):
- Find the Notion mapping from CLAUDE.md or by searching
- Fetch current pages
- Apply strategic/organizational updates
- Track results for the summary

### 5. Combined Summary Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the output format.

Emit one combined report using the **/up-docs:all** format: a heading per layer, each with its own table and totals line.

## Layer Boundaries

Each layer gets the right kind of content:

| Layer | Content Level | Example |
|-------|--------------|---------|
| Repo | Project-specific docs | "Added `--verbose` flag to the CLI" |
| Wiki | Implementation reference | "Authentik OIDC client config for the new service" |
| Notion | Strategic/organizational | "New monitoring service added to the homelab stack" |

If information only belongs in one layer, update only that layer. Not every session change needs to propagate to all three.
