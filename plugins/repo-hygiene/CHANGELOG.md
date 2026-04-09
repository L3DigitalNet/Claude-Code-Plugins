# Changelog

## [1.3.0] - 2026-04-09

### Added
- `check-readme-structure.sh`: validates plugin READMEs against the canonical template headings, with synonym groups and component-based conditional headings
- `check-readme-placeholders.sh`: detects unmodified template placeholder strings in plugin READMEs
- `check-readme-refs.sh`: verifies backtick paths, relative markdown links, and /plugin:command references resolve to existing files

### Changed
- `/hygiene` command now runs 7 parallel scripts (was 4) in Step 1

## [1.2.0] - 2026-03-04

### Added
- universalize plugin to any git repository (v1.2.0)

### Changed
- update org references from L3Digital-Net to L3DigitalNet

### Fixed
- apply audit findings — em dashes, model name, deploy gate, error handling


## [1.2.0] - 2026-03-02

### Changed
- Plugin is now universal: works in any git repository, not only the Claude-Code-Plugins monorepo
- `check-manifests.sh` treats `marketplace.json` as optional — Source A (plugin manifest checks) is skipped gracefully when the file is absent; Source B (installed_plugins.json path checks) runs in all repos
- `/hygiene` command adds repo-type detection at Step 0 via `IS_CLAUDE_PLUGIN_REPO` flag; Step 2 (README/docs scan) is gated on that flag and skipped in generic repos
- Step 8 detects the remote default branch dynamically instead of hardcoding `main`; merge-to-default-branch only runs when the current branch differs from the default
- Step 8 warns about staged stale-commit files before the push sequence begins, with an `AskUserQuestion` gate to let users commit first
- Step 5 DRY_RUN now shows the full grouped findings list instead of a count-only message
- `stale-commits` and `orphans` approval items retain per-item multi-select granularity regardless of N (prevents category-collapse for destructive actions)
- Step 6 no longer double-confirms gitignore removals already approved via Step 5 multi-select
- README updated to reflect universal scope, conditional check table with Scope column, and dynamic branch detection in Step 8 description

## [1.1.1] - 2026-02-22

### Added
- Step 8: after the sweep, auto-commits any file changes from auto-fixes and approved edits, pushes the current branch, then merges to `main` and pushes — remote is always left up-to-date after a successful non-dry-run sweep
- Stale-commits staged files are called out separately in Step 8 and excluded from the auto-commit (they require a user-authored commit message)

## [1.1.0] - 2026-02-22

### Changed
- Check 3 (README scan) restructured into three leaf-to-root sub-phases: plugin READMEs (2a), root README.md (2b), and `docs/` files (2c)
- Plugin README scan now detects unmodified template placeholders from `docs/plugin-readme-template.md`
- Plugin README scan now cross-references each Commands, Skills, Agents, Hooks, and Tools table entry against actual files on disk
- Root README.md is now checked for plugin coverage against `marketplace.json`
- Added new check type `docs-accuracy`: verifies repo-relative paths and plugin name references in `docs/` files exist on disk
- Step 5 multi-select now includes "All docs/ accuracy findings" category
- Step 6 handles `docs-accuracy` findings by displaying context for review

## [1.0.0] - 2026-02-20

### Added
- `/hygiene` command with `--dry-run` flag
- Check 1: `.gitignore` stale pattern detection and missing-pattern suggestions
- Check 2: Marketplace manifest `source` path cross-reference
- Check 3: README `Known Issues` / `Principles` semantic staleness (inline AI)
- Check 4: Plugin state orphan detection (`installed_plugins.json` vs `settings.json` vs FS)
- Check 5: Uncommitted changes older than 24 hours
- Auto-fix for safe findings; `AskUserQuestion` multi-select for risky changes

### Fixed
- Address code review — stale-pattern false positives, fix_cmd absolute paths, orphan safety guard, trailing-slash auto-fix, .claude/state note
