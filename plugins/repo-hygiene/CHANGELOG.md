# Changelog

## [1.1.1] - 2026-03-02

### Added
- add Step 8 — auto-commit fixes and push to remote (v1.1.1)
- expand Check 3 to leaf-to-root README and docs/ accuracy scan (v1.1.0)

### Changed
- Update GitHub org references from L3DigitalNet to L3Digital-Net
- Enhance Release Pipeline and Repo Hygiene Plugins
- update plugin docs, PTH README for v0.6.0, and repo template

### Fixed
- remove em dashes from all READMEs; add hygiene check
- cross-cutting standards sweep across marketplace
- replace \n with <br/> in mermaid node labels across all plugin READMEs


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
- add /hygiene orchestrating command
- add check-stale-commits.sh
- add check-orphans.sh
- add check-manifests.sh
- add check-gitignore.sh
- scaffold plugin structure v1.0.0

### Fixed
- address code review — stale-pattern false positives, fix_cmd absolute paths, orphan safety guard, trailing-slash auto-fix, .claude/state note


## [1.0.0] - 2026-02-20

### Added
- `/hygiene` command with `--dry-run` flag
- Check 1: `.gitignore` stale pattern detection and missing-pattern suggestions
- Check 2: Marketplace manifest `source` path cross-reference
- Check 3: README `Known Issues` / `Principles` semantic staleness (inline AI)
- Check 4: Plugin state orphan detection (`installed_plugins.json` vs `settings.json` vs FS)
- Check 5: Uncommitted changes older than 24 hours
- Auto-fix for safe findings; `AskUserQuestion` multi-select for risky changes
