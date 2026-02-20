# Changelog

All notable changes to the docs-manager plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

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
