# Changelog

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
