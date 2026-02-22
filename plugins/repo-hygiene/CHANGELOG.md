# Changelog

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
