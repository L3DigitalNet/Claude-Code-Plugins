# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [2.1.0] - 2026-03-02

### Added
- make marketplace name configurable via env var

### Changed
- fix structural README issues and docs path
- Update GitHub org references from L3DigitalNet to L3DigitalNet
- reduce AI writing signals across all plugin READMEs
- add PTH test suite (19 tests, 19 passing)
- Enhance Release Pipeline and Repo Hygiene Plugins

### Fixed
- remove em dashes from all READMEs; add hygiene check
- replace \n with <br/> in mermaid node labels across all plugin READMEs


## [Unreleased]

### Fixed

- `sync-local-plugins.sh` marketplace name is now configurable via `RELEASE_PIPELINE_MARKETPLACE` environment variable (default: `l3digitalnet-plugins`)

## [2.0.0] - 2026-02-21

### Changed
- release-pipeline updates, plugin-review agents, plan doc
- add release-pipeline tests, refresh-plugin-cache skill, gitignore PTH locks

### Fixed
- suppress set -e exit in test-fix-git-email.sh


## [2.0.0] - 2026-02-21

### Added
- `scripts/auto-stash.sh` — auto-stash and restore dirty working tree (stash|pop|check)
- `scripts/fix-git-email.sh` — check and auto-repair noreply git email before release
- Phase 0.5 (Auto-Heal) in mode-2 and mode-3: auto-stash dirty tree, auto-fix git email before pre-flight
- Phase 3.5 (Stash Restore) in mode-2 and mode-3: restore stash after push, before GitHub API call
- Auto-Heal step in mode-7 (Batch Release): global stash before loop, restore after summary
- `tests/test-auto-stash.sh` — 11 tests including untracked file capture and safety against user stashes
- `tests/test-fix-git-email.sh` — 7 tests including HTTPS/SSH remote URL parsing and scope handling
- `tests/test-bump-version.sh` — 7 tests covering plugin.json, pyproject.toml, --plugin, --dry-run
- `tests/test-generate-changelog.sh` — 8 tests covering categorization, --preview, scoped output
- `tests/test-suggest-version.sh` — 7 tests covering major/minor/patch bumps and --plugin scope
- `tests/test-detect-unreleased.sh` — 6 tests covering TSV output, single-plugin guard, per-plugin detection
- `tests/run-all.sh` — aggregating test runner with `--filter` support

### Changed
- `scripts/api-retry.sh`: abort immediately on permanent HTTP 4xx errors (400, 401, 403, 404, 409, 410) without retry; 429 (rate-limit) still retried normally
- `tests/test-api-retry.sh`: added 3 new tests covering HTTP 400, HTTP 404, and HTTP 429 behavior

### Breaking
- Dirty working tree no longer blocks mode-2/mode-3/mode-7 releases — auto-stash is applied automatically before pre-flight; restore is automatic after release
- Non-noreply git email no longer blocks releases — auto-fix is applied automatically before pre-flight using gh CLI or remote URL detection

## [1.6.0] - 2026-02-20

### Added
- v1.6.0 — resilience layer (tag reconcile, retry, waivers, batch release)
- add Batch Release option to /release menu
- add mode-7-batch-release.md template
- add tag reconciliation and retry to mode-3 plugin release
- add tag reconciliation and retry to mode-2 full release
- add waiver support and remote tag check to pre-flight agents
- wrap gh release view calls with api-retry in verify-release.sh
- add check-waivers.sh for pre-flight check waivers
- add api-retry.sh with exponential backoff and jitter
- add reconcile-tags.sh for local/remote tag reconciliation
- update changelog format, enhance sync scripts, and improve user prompts
- update version to 0.2.0 and enhance documentation with new hooks and validation features

### Changed
- fix README version ref and add release waivers
- align plugin principles with trust-based philosophy

### Fixed
- correct LOCAL_ONLY branch logic and minor hardening
- guard BASE_DELAY_MS=0, add EXIT trap, bc fallback in api-retry.sh
- use grep -qF for tag matching; update test mocks with peeled refs


## [1.6.0] - 2026-02-20

### Added
- `scripts/reconcile-tags.sh` — compare local/remote tag state; auto-fetch REMOTE_ONLY tags before push
- `scripts/api-retry.sh` — exponential backoff + jitter retry wrapper (3 attempts) for `gh` CLI calls
- `scripts/check-waivers.sh` — look up pre-flight check waivers from `.release-waivers.json`
- `.release-waivers.json` support — permanently waive checks per-plugin (`dirty_working_tree`, `protected_branch`, `noreply_email`, `tag_exists`, `missing_tests`, `stale_docs`)
- Mode 7: Batch Release All Plugins — release all unreleased plugins sequentially with quarantine-and-continue semantics and summary report
- `agents/git-preflight.md`: remote tag check (check 6) and waiver support for all git checks
- `agents/test-runner.md`: waiver support for `missing_tests`
- `agents/docs-auditor.md`: waiver support for `stale_docs`

### Changed
- `templates/mode-2-full-release.md` Phase 3: tag reconciliation before push, retry on `gh release create`
- `templates/mode-3-plugin-release.md` Phase 3: same as mode-2
- `scripts/verify-release.sh`: `gh release view` calls now use retry wrapper

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

