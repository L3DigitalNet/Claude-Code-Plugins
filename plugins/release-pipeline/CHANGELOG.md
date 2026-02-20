# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [1.5.0] - 2026-02-19

### Added
- `MERGE COMPLETE` named block in Quick Merge final report — consistent with Full Release and Plugin Release output format
- Explicit AskUserQuestion option labels for monorepo scope question in Dry Run and Changelog Preview modes

### Changed
- Changelog write now happens after the approval gate in Full Release and Plugin Release — prevents a dirty `git checkout -- .` on abort; --preview is used before the gate
- Quick Merge commit step no longer requires a separate confirmation — invocation with uncommitted changes implies consent; the merge gate is the single decision point
- `sync-local-plugins.sh` SessionStart hook now suppresses output when no files changed

### Fixed
- remove redundant release-detection skill (was listed in README but never created)
- show changelog entry before approval gate in Phase 2 so users review it before committing


## [1.4.2] - 2026-02-19

### Fixed
- remove redundant release-detection skill (was listed in README but never created)
- show changelog entry before approval gate in Phase 2 so users review it before committing

## [1.4.1] - 2026-02-19

### Added
- `auto-build-plugins.sh` PreToolUse hook — auto-builds TypeScript plugins and stages `dist/` before git commits
- `sync-local-plugins.sh` SessionStart hook — syncs local plugin source to Claude Code cache on session start

## [1.4.0] - 2026-02-19

### Changed
- add Principles section to all 7 plugin READMEs
- standardise all plugin READMEs with consistent sections


## [1.3.0] - 2026-02-18

### Added
- simplify release-detection skill to route to menu
- rewrite /release as interactive context-aware menu
- add --preview flag to generate-changelog.sh
- add suggest-version.sh for auto semver suggestion
- update release-detection skill for plugin names
- add Mode 3 (Plugin Release) to release command
- add --plugin flag to verify-release.sh
- add --plugin flag to generate-changelog.sh
- add --plugin flag to bump-version.sh
- add detect-unreleased.sh for monorepo scanning

### Changed
- add monorepo usage to README

