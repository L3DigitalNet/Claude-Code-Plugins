# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [2.1.1] - 2026-03-04

### Changed
- update remaining L3Digital-Net references
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply audit findings — CHANGELOG, README, marketplace, agents, templates


## [2.1.0] - 2026-03-02

### Added
- Make marketplace name configurable via `RELEASE_PIPELINE_MARKETPLACE` environment variable (default: `l3digitalnet-plugins`)

### Changed
- Fix structural README issues and docs path

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

### Fixed
- Suppress `set -e` exit in `test-fix-git-email.sh`

### Breaking
- Dirty working tree no longer blocks mode-2/mode-3/mode-7 releases — auto-stash is applied automatically before pre-flight; restore is automatic after release
- Non-noreply git email no longer blocks releases — auto-fix is applied automatically before pre-flight using gh CLI or remote URL detection

## [1.6.0] - 2026-02-20

### Added
- `scripts/reconcile-tags.sh` — compare local/remote tag state; auto-fetch REMOTE_ONLY tags before push
- `scripts/api-retry.sh` — exponential backoff + jitter retry wrapper (3 attempts) for `gh` CLI calls
- `scripts/check-waivers.sh` — look up pre-flight check waivers from `.release-waivers.json`
- `.release-waivers.json` support — permanently waive checks per-plugin (`dirty_working_tree`, `protected_branch`, `noreply_email`, `tag_exists`, `missing_tests`, `stale_docs`)
- Mode 7: Batch Release All Plugins — sequential release of all unreleased plugins with quarantine-and-continue semantics and summary report
- `agents/git-preflight.md`: remote tag check (check 6) and waiver support for all git checks
- `agents/test-runner.md`: waiver support for `missing_tests`
- `agents/docs-auditor.md`: waiver support for `stale_docs`

### Changed
- Fix README version ref and add release waivers documentation
- Align plugin principles with trust-based philosophy
- `templates/mode-2-full-release.md` Phase 3: tag reconciliation before push, retry on `gh release create`
- `templates/mode-3-plugin-release.md` Phase 3: same as mode-2
- `scripts/verify-release.sh`: `gh release view` calls now use retry wrapper

### Fixed
- Correct LOCAL_ONLY branch logic and minor hardening in `reconcile-tags.sh`
- Guard `BASE_DELAY_MS=0`, add EXIT trap, bc fallback in `api-retry.sh`
- Use `grep -qF` for tag matching; update test mocks with peeled refs

## [1.5.0] - 2026-02-19

### Added
- `MERGE COMPLETE` named block in Quick Merge final report — consistent with Full Release and Plugin Release output format
- Explicit AskUserQuestion option labels for monorepo scope question in Dry Run and Changelog Preview modes

### Changed
- Changelog write now happens after the approval gate in Full Release and Plugin Release — prevents a dirty `git checkout -- .` on abort; --preview is used before the gate
- Quick Merge commit step no longer requires a separate confirmation — invocation with uncommitted changes implies consent; the merge gate is the single decision point
- `sync-local-plugins.sh` SessionStart hook now suppresses output when no files changed

### Fixed
- Remove redundant release-detection skill (was listed in README but never created)
- Show changelog entry before approval gate in Phase 2 so users review it before committing

## [1.4.2] - 2026-02-19

### Fixed
- Remove redundant release-detection skill (was listed in README but never created)
- Show changelog entry before approval gate in Phase 2 so users review it before committing

## [1.4.1] - 2026-02-19

### Added
- `auto-build-plugins.sh` PreToolUse hook — auto-builds TypeScript plugins and stages `dist/` before git commits
- `sync-local-plugins.sh` SessionStart hook — syncs local plugin source to Claude Code cache on session start

## [1.4.0] - 2026-02-19

### Changed
- Add Principles section to all 7 plugin READMEs
- Standardise all plugin READMEs with consistent sections

## [1.3.0] - 2026-02-18

### Added
- Simplify release-detection skill to route to menu
- Rewrite /release as interactive context-aware menu
- Add --preview flag to generate-changelog.sh
- Add suggest-version.sh for auto semver suggestion
- Update release-detection skill for plugin names
- Add Mode 3 (Plugin Release) to release command
- Add --plugin flag to verify-release.sh
- Add --plugin flag to generate-changelog.sh
- Add --plugin flag to bump-version.sh
- Add detect-unreleased.sh for monorepo scanning

### Changed
- Add monorepo usage to README
