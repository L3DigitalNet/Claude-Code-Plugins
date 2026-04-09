# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.1.0] - 2026-04-09

### Added
- `scripts/config-block.sh` for reading, writing, and validating the claude-sync config block in CLAUDE.md
- `scripts/apply-snapshot.sh` for applying snapshot files by category with mtime-based conflict resolution

### Changed
- `commands/sync-import.md` Steps 1 and 5 now use config-block.sh and apply-snapshot.sh
- `commands/sync-export.md` Step 1 now uses config-block.sh

## [1.0.0] - 2026-04-07

### Added
- `/claude-sync:sync-export` command: full git sync cycle on all repos, then captures `~/.claude/` environment and MCP server configs into a `.tar.gz` snapshot
- `/claude-sync:sync-import` command: reads snapshot, backs up local state, applies changes with mtime-based merge, reviews local-only files, then runs full git sync
- Wholesale `~/.claude/` capture with explicit exclusions (projects/, .credentials.json, statsig/, Claude Sync config block)
- MCP server extraction from `~/.claude.json` with install method inference (npm, pip, binary, manual)
- File-level mtime conflict resolution for all categories; `~/.claude.json` mtime for MCP block merge
- Per-machine exclude list stored in global CLAUDE.md, applies to both files and git repos
- Local-only file review with keep / keep-and-exclude / remove decisions
- Pre-import backup written to sync path before any changes are applied
- Git sync cycle: auto-commit tracked changes, push, fetch, pull on all repos under configured root
- First-run setup flow for sync path, secret store path, and repos root path
- Reference file architecture: 4 knowledge files loaded on demand by commands
