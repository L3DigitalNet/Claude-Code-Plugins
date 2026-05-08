# Changelog

All notable changes to the docs-manager plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.2.4] - 2026-05-07

### Changed
- docs-manager v0.2.4 — replace forbidden WebSearch with MCP search backends


## [0.2.4] - 2026-05-07

### Changed

- `agents/full-review.md` and `agents/upstream-verify.md`: replaced forbidden `WebSearch` tool with `mcp__brave-search__brave_web_search` + `mcp__serper-search__google_search`, and added `mcp__tavily__tavily_extract` for upstream URL fetching. Tavily handles JS-rendered upstream documentation pages (Home Assistant docs, vendor wikis) more reliably than `WebFetch`. Aligns with the marketplace-wide search-tool migration.

## [0.2.3] - 2026-04-09

### Added
- add scripts for context gathering, config management, and status dashboards

### Changed
- pass 3 — close remaining gaps, 293 total tests across 9 plugins
- close gap analysis findings, 247 total tests across 9 plugins
- add 166 bats tests across 9 plugins for new scripts


## [0.2.3] - 2026-04-09

### Added
- `scripts/status-dashboard.sh` consolidating 5-6 individual health checks into a single script call

### Changed
- `commands/docs.md` status subcommand now uses status-dashboard.sh

## [0.2.2] - 2026-03-04

### Changed
- update remaining L3Digital-Net references
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply audit findings — plugin.json, CHANGELOG


## [Unreleased]

## [0.2.1] - 2026-03-02

### Changed
- Strengthen skill triggers and extract long content to reference files

## [0.2.0] - 2026-02-20

### Added
- Complete documentation lifecycle management plugin (v0.2.0)
- Skills: `doc-creation`, `project-entry`, `session-boundary`
- Agents: `bulk-onboard`, `full-review`, `upstream-verify`
- Template registration script
- `/docs` command router with `queue`, `status`, `help`, and 20+ subcommands
- Index system: register, query, locking, rebuild-md, source-lookup, and Path B detection
- PostToolUse hook (Path A and Path B detection)
- Stop hook for session-end queue surfacing
- Survival-context classifier (P5 rule)
- Frontmatter reader utility (Python 3 stdlib, no pyyaml dependency)
- Queue scripts: append with dedup, read with fallback merge, clear, merge-fallback
- State bootstrap script

### Changed
- Add Principles Registry with enforcement heuristics and risk areas


## [0.1.0] - 2026-02-20

### Added
- Plugin scaffold with marketplace entry
- State directory bootstrap (`~/.docs-manager/`)
- Queue system: append, read, clear, merge-fallback with deduplication
- Frontmatter reader (Python 3 stdlib, no pyyaml dependency)
- Survival-context classifier (P5 rule implementation)
- PostToolUse hook: Path A (direct doc edit) and Path B (source-file association)
- Stop hook: session-end queue summary
- `/docs` command router with 20+ subcommands
- Queue review: multi-select approval workflow
- Status dashboard: operational + library health
- Index system: register, query, rebuild-md, locking, source-lookup
- Index commands: init, sync, audit, repair
- Library and find commands
- Document lifecycle: new, onboard, update, review, organize
- Template registration and inference
- Maintenance: audit, dedupe, consistency, streamline, compress
- Upstream verification with tiered batching
- Skills: project-entry, doc-creation, session-boundary
- Agents: bulk-onboard, full-review, upstream-verify
- 63 bats tests across 4 test files
