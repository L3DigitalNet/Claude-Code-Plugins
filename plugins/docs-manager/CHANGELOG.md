# Changelog

All notable changes to the docs-manager plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] - 2026-02-20

### Added
- complete v0.1.0 — documentation lifecycle management plugin
- add skills and agents
- add template registration script
- expand /docs command with all subcommands
- add index system with register, query, locking, and Path B detection
- add /docs command router with queue, status, help
- add Stop hook and hooks.json registration
- add PostToolUse hook detection (Path A)
- add survival-context classifier (P5 rule)
- add frontmatter reader utility with tests
- add queue clear and fallback merge scripts
- add queue read script with fallback merge
- add queue append script with dedup and fallback
- add state bootstrap script with tests
- add plugin scaffold and marketplace entry

### Changed
- Add Principles Registry for docs-manager with enforcement heuristics and risk areas


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
