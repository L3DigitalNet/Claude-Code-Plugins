---
name: up-drift
description: "Comprehensive documentation drift analysis across infrastructure and wiki. Gathers live server state via SSH, syncs Outline wiki, resolves internal contradictions, verifies and enriches links, then updates Notion. This skill should be used when the user runs /up-docs:drift."
argument-hint: "[collection-name]"
allowed-tools: Read, Glob, Grep, Bash, WebFetch, AskUserQuestion, mcp__plugin_mcp-outline_mcp-outline__search_documents, mcp__plugin_mcp-outline_mcp-outline__read_document, mcp__plugin_mcp-outline_mcp-outline__update_document, mcp__plugin_mcp-outline_mcp-outline__create_document, mcp__plugin_mcp-outline_mcp-outline__list_collections, mcp__plugin_mcp-outline_mcp-outline__get_collection_structure, mcp__plugin_mcp-outline_mcp-outline__get_document_backlinks, mcp__plugin_mcp-outline_mcp-outline__get_document_id_from_title, mcp__plugin_Notion_notion__notion-search, mcp__plugin_Notion_notion__notion-fetch, mcp__plugin_Notion_notion__notion-update-page, mcp__plugin_Notion_notion__notion-create-pages
---

# /up-docs:drift [collection-name]

Comprehensive drift analysis and correction across live infrastructure, Outline wiki, and Notion. Designed for Opus with 1M context: read aggressively, hold many pages simultaneously, and minimize re-reads.

If a collection name is provided, scope the analysis to that Outline collection. Otherwise, analyze all collections.

## Overview

Four sequential phases, each running in a convergence loop:

1. **Infrastructure → Wiki**: SSH into servers, compare live state against wiki docs, update wiki
2. **Wiki Consistency**: Cross-reference wiki pages for contradictions, resolve them
3. **Link Integrity & Enrichment**: Verify all links, fix broken ones, add useful cross-references
4. **Notion Sync**: Update Notion's strategic layer to reflect the corrected wiki state

Each phase converges independently before the next begins. Read `${CLAUDE_PLUGIN_ROOT}/skills/drift/references/convergence-tracking.md` for the iteration mechanics.

## Setup

Before starting any phase, gather session context and initialize convergence tracking:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/context-gather.sh
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh init
```

## Phase 1: Infrastructure → Wiki Sync

### Discovery

Browse all Outline collections (or the scoped collection):

```
list_collections()
get_collection_structure(id: "<collection_id>")
```

Build a page inventory: page title, page ID, collection, and any hostname or service name extractable from the title or structure.

Read the project CLAUDE.md for any explicit hostname/service mappings. Also check Notion's infrastructure hierarchy for the authoritative inventory of what exists:

```
notion-search(query: "infrastructure")
```

### Iteration Loop

For each documented service/server page in the inventory:

1. **Read the wiki page** in full. Extract:
   - Hostnames, IP addresses, ports
   - Service names and versions
   - Configuration values and file paths
   - Dependencies (upstream/downstream)
   - Documented procedures and commands

2. **Inspect the server** using the batched inspection script:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/scripts/server-inspect.sh <hostname> <service-type> --config-paths <paths>
   ```
   Read `${CLAUDE_PLUGIN_ROOT}/skills/drift/references/server-inspection.md` for service type selection guidance. The script batches all SSH commands into a single session, returning structured JSON with system info, service status, config files, and listening ports.

3. **Compare** documented state against actual state. Categorize each discrepancy:
   - **Factual drift**: version numbers, ports, paths, config values that have changed
   - **Missing documentation**: running services or configurations not mentioned in the wiki
   - **Stale documentation**: documented services or configs that no longer exist

4. **Update the wiki page** with corrections. Preserve existing structure and tone. For missing documentation, add new sections following the page's existing conventions. For stale content, remove or mark as deprecated.

After each iteration, record findings and check convergence:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh start-phase 1
echo '<findings-json>' | bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh record-iteration 1
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh check-convergence 1
bash ${CLAUDE_PLUGIN_ROOT}/scripts/convergence-tracker.sh check-oscillation 1
```

**Convergence**: A pass with zero discrepancies across all pages. If a pass finds discrepancies, apply fixes and re-check only the affected pages on the next pass.

### Batch Reading

Use the full 1M context window. Read 10-20 related wiki pages before beginning SSH inspection, grouping by host. This allows cross-referencing during inspection and reduces re-reads.

## Phase 2: Wiki Internal Consistency

### Cross-Reference Map

Read all wiki pages touched or related to Phase 1 (and any additional pages in scope). For each page, extract factual claims:
- Port assignments
- Hostnames and IP addresses
- Service dependencies ("X depends on Y")
- Configuration values referenced across pages
- Version numbers

Build an in-context map of these claims, keyed by the fact being claimed.

### Contradiction Detection Loop

Scan the map for contradictions:
- Page A says service X runs on port 8080; page B says port 8443
- Page A says service X depends on Y; page C says X has no external dependencies
- Different pages cite different versions of the same tool
- Upstream/downstream dependency chains that don't agree

For each contradiction:

1. **Try to resolve from page metadata**: the more recently updated page, the page with more specificity, or the page that is the canonical reference for that service wins.

2. **If unresolvable from pages alone**, SSH to the relevant server to check actual state. This is the exception in Phase 2, not the rule — most contradictions can be resolved by identifying which page is authoritative.

3. **Update the incorrect page(s)**. When both pages contain partially correct information, update both to be consistent.

Track per iteration: `contradictions_found`, `resolved_from_pages`, `resolved_via_ssh`, `pages_updated`.

**Convergence**: A full pass with zero contradictions.

## Phase 3: Link Integrity & Enrichment

### Link Audit

For each wiki page in scope:

1. **Extract all links**:
   - External URLs (https://...)
   - Inter-wiki links (links to other Outline pages)
   - Internal anchors

2. **Verify external URLs** using the link audit script:
   ```bash
   echo '<page-markdown>' | bash ${CLAUDE_PLUGIN_ROOT}/scripts/link-audit.sh - --timeout 10
   ```
   The script classifies each link as live, dead, redirected, timed out, or rate-limited. For internal links marked `needs_verification`, check via MCP.

3. **Verify inter-wiki links** using `get_document_id_from_title` or `read_document`. Check each linked page exists and the link target is correct.

4. **Fix broken links**:
   - Dead external URLs: remove the link or replace with a current URL if discoverable
   - Broken inter-wiki links: find the correct page (may have been renamed/moved) and update
   - Redirected URLs: update to the final destination

### Link Enrichment

After fixing broken links, scan for enrichment opportunities:

1. **Missing cross-references**: when page A discusses a concept, service, or tool that page B is the canonical reference for, and there's no link from A → B, add one.

2. **Related services**: when two services have a dependency relationship documented in their respective pages but neither links to the other, add bidirectional links.

3. **Orphan pages**: pages with zero incoming links that are still relevant. Find natural insertion points in related pages to link to them.

Use `get_document_backlinks(id: "<page_id>")` to understand existing link topology.

Do not over-link. Add a cross-reference only when it provides genuine navigational value. A page about nginx does not need to link to every page that mentions HTTP.

Track per iteration: `links_checked`, `broken_fixed`, `new_links_added`.

**Convergence**: Zero broken links found and zero high-value enrichment opportunities remaining.

## Phase 4: Notion Sync

Read `${CLAUDE_PLUGIN_ROOT}/skills/notion/references/notion-guidelines.md` before making any Notion changes.

Review all changes made in Phases 1-3. For each change, determine whether it has strategic or organizational significance:

- New service discovered → Notion should know it exists and its purpose
- Service removed → Notion should reflect the removal
- Dependency changes → Notion should update relationship documentation
- Major configuration shifts → Notion may need updated context on why
- Minor config value changes (ports, versions) → typically not Notion-relevant

For each Notion-relevant change:

1. Search Notion for the corresponding page
2. Fetch and read the current page
3. Apply targeted updates at the organizational level (what/why, not how)
4. Preserve existing tone and structure

## Summary Report

Read `${CLAUDE_PLUGIN_ROOT}/templates/summary-report.md` for the base format. Extend it for drift analysis:

```markdown
## Drift Analysis Report

### Phase 1: Infrastructure → Wiki Sync
**Iterations:** N | **Converged:** yes/no

| # | Wiki Page | Host | Discrepancies Found | Action |
|---|-----------|------|---------------------|--------|
| 1 | Page title | hostname | 3 config values drifted | Updated |

**Totals:** N pages checked | N discrepancies found | N pages updated

### Phase 2: Wiki Internal Consistency
**Iterations:** N | **Converged:** yes/no

| # | Contradiction | Pages Involved | Resolution |
|---|--------------|----------------|------------|
| 1 | Port conflict for service X | Page A, Page B | Updated Page B (confirmed via SSH) |

**Totals:** N contradictions found | N resolved

### Phase 3: Link Integrity & Enrichment
**Iterations:** N | **Converged:** yes/no

| # | Page | Link Issue | Action |
|---|------|-----------|--------|
| 1 | Page title | Dead URL: example.com/old | Removed |
| 2 | Page title | Missing cross-ref to Page B | Added |

**Totals:** N links checked | N broken fixed | N new links added

### Phase 4: Notion Sync

| # | Notion Page | Action | Summary |
|---|-------------|--------|---------|
| 1 | Page title | Updated | New service added to dependencies |

**Totals:** N pages updated | N created | N unchanged
```
