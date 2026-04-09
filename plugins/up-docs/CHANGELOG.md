# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.3.0] - 2026-04-09

### Added
- add 4 scripts for context gathering, server inspection, link auditing, convergence tracking

### Changed
- pass 3 — close remaining gaps, 293 total tests across 9 plugins
- close gap analysis findings, 247 total tests across 9 plugins
- add 166 bats tests across 9 plugins for new scripts

### Fixed
- add handoff to root README, fix up-docs skill names


## [0.3.0] - 2026-04-09

### Added
- `scripts/context-gather.sh` consolidating git context assessment for all 5 skills
- `scripts/server-inspect.sh` batching 5-15 SSH commands per host into a single session
- `scripts/link-audit.sh` for markdown link extraction and verification
- `scripts/convergence-tracker.sh` for managing iteration state across drift analysis phases

### Changed
- All 5 skill files (repo, wiki, notion, all, drift) now use context-gather.sh for session context
- `skills/drift/SKILL.md` Phase 1 uses server-inspect.sh and convergence-tracker.sh
- `skills/drift/SKILL.md` Phase 3 uses link-audit.sh for external link verification

## [0.2.0] - 2026-03-28

### Added

- `/up-docs:drift` command for comprehensive drift analysis: SSHes into live infrastructure, syncs Outline wiki across four convergence phases (infrastructure sync, wiki consistency, link integrity, Notion update)
- Server inspection reference with patterns for systemd, Docker, web servers, databases, DNS, VPN, monitoring, and backup services
- Convergence tracking reference with iteration mechanics, oscillation detection, and narrowing strategy

## [0.1.0] - 2026-03-28

### Added

- `/up-docs:repo` command to update repository documentation (README.md, docs/, CLAUDE.md)
- `/up-docs:wiki` command to update Outline wiki with implementation-level details
- `/up-docs:notion` command to update Notion with strategic and organizational context
- `/up-docs:all` command to update all three layers sequentially
- Summary report template for consistent output formatting across all commands
- Notion content guidelines reference document
