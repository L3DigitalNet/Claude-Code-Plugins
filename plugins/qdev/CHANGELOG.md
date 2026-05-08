# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.4.0] - 2026-05-07

### Changed
- qdev v1.4.0 — add Tavily MCP support across all commands and agents


## [1.4.0] - 2026-05-07

### Added

- All `/qdev` commands and agents now support the `tavily` MCP server. New tools available to relevant agents/commands: `mcp__tavily__tavily_search` (content-heavy queries that previously required search→scrape) and `mcp__tavily__tavily_extract` (JS-rendered page extraction; replaces `WebFetch` as the preferred fetch tool for documentation, advisory, and issue pages). `brave-search` + `serper-search` remain the primary parallel search pair.

### Changed

- `/qdev:research`: 3-5 deep-dive pages identified after dual-source search are now read via `mcp__tavily__tavily_extract` instead of `WebFetch`. Includes a `search_depth=basic` note to avoid the broken `fast` mode currently in Tavily's MCP.
- `qdev-quality-reviewer` agent: docs/issue/advisory pages requiring JS rendering or full extraction now route through `tavily_extract`.
- `qdev-deps-auditor` agent: CVE advisory pages (GHSA, NVD detail pages) are now read via `tavily_extract` with `WebFetch` as fallback.
- `README.md`: prerequisites now list `tavily` MCP as recommended; mermaid diagrams updated to show the third research surface.

### Notes

- Existing `brave-search` and `serper-search` tool calls are unchanged in shape and parallelism. Tavily is additive, not a replacement for the dual-source primary pair.
- This release follows the marketplace-wide swap from `garylab/serper-mcp-server` (Python, all-Google-verticals) to `marcopesani/serper-search-scrape-mcp-server` (Node, search + scrape only). All `mcp__serper-search__google_search` references continue to resolve correctly.

## [1.3.0] - 2026-04-23

### Changed

- `/qdev:deps-audit`, `/qdev:quality-review`, and `/qdev:doc-sync` are now thin orchestrators that dispatch dedicated subagents rather than performing the research, analysis, and edit work inline. Estimated ~50K tokens saved per typical weekly usage cycle when invoked from Opus sessions.

### Added

- `plugins/qdev/agents/qdev-deps-auditor.md` — Haiku agent for manifest parsing plus per-dependency CVE and version research.
- `plugins/qdev/agents/qdev-quality-reviewer.md` — Sonnet agent for research-first iterative quality review with oscillation detection. Handles the pass loop; the command drives AskUserQuestion for needs-approval findings.
- `plugins/qdev/agents/qdev-doc-syncer.md` — Haiku agent for docstring/JSDoc sync against current signatures. Dry-run and apply modes.

## [1.2.1] - 2026-04-13

### Changed
- `/qdev:quality-review` finding classification now uses a principled decision test instead of type-based lists: a fix is auto-applied when exactly one correct answer exists, no design decision is required, no dependency action is involved, and no non-trivial logic is removed. GAP findings with derivable answers, naming violations, weak requirement words, and dead imports now auto-fix without prompting.

## [1.2.0] - 2026-04-13

### Added
- `/qdev:deps-audit` command: dependency security and freshness audit across all package manifests; researches CVEs and version lag using both search tools; optionally generates upgrade commands for critical and high findings
- `/qdev:doc-sync` command: sync inline code documentation (docstrings, JSDoc, Go doc comments, etc.) with current function signatures; proposes additions for undocumented functions and updates for stale docs before writing anything

## [1.1.0] - 2026-04-13

### Added
- `/qdev:research` command: dual-source internet research sweep covering official docs, community best practices, footguns, and existing tools before designing or building

## [1.0.0] - 2026-04-13

### Added
- `/qdev:quality-review` command: research-first iterative quality review for spec, plan, and code artifacts
- `/qdev:spec-update` command: one-shot sync of a spec file to match current implementation
