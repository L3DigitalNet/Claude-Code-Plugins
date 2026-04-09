# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [0.2.0] - 2026-04-09

### Added
- add scripts for context gathering, config management, and status dashboards

### Changed
- pass 3 — close remaining gaps, 293 total tests across 9 plugins
- close gap analysis findings, 247 total tests across 9 plugins
- add 166 bats tests across 9 plugins for new scripts


## [0.2.0] - 2026-04-09

### Added
- `scripts/gather-context.sh` consolidating machine and git context gathering for save
- `scripts/find-latest-handoff.sh` for discovering and parsing most recent handoff file

### Changed
- `skills/save/SKILL.md` Step 1 now uses gather-context.sh
- `skills/load/SKILL.md` Step 1 now uses find-latest-handoff.sh

## [0.1.0] - 2026-03-28

### Added

- `/handoff:save` command to write task handoff files to shared network drive
- `/handoff:load` command to read the most recent handoff file and resume work
