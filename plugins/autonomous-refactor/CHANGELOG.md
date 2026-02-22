# Changelog

All notable changes to the autonomous-refactor plugin will be documented here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.0] - 2026-02-21

### Added
- Phase 1 (Snapshot): `test-generator` agent creates a behavioural test suite and confirms a green baseline before any changes
- Phase 2 (Analyze): `principles-auditor` agent audits target files against project README.md design principles, produces ranked opportunity list with alignment score
- Phase 3 (Refactor Loop): fully autonomous change loop — each opportunity runs in a git worktree; commits on green, reverts on red, re-audits after each success
- Phase 4 (Report): `report-generator` agent produces before/after comparison of LOC, cyclomatic complexity, principles alignment score, and diff summary
- `run-tests.sh`: language-aware test runner (TypeScript via package.json, Python via pytest) with worktree support
- `measure-complexity.sh`: cyclomatic complexity via `radon` (Python) or `npx complexity-report` (TypeScript), with graceful fallback to AI estimation and install prompt
- `snapshot-metrics.sh`: captures LOC and complexity at baseline and final checkpoints
- `src/metrics.ts`: TypeScript utility for precise LOC counting and structured diff summaries via `npx tsx`
- Oscillation detection: skips any opportunity reverted twice in the same session
- `--max-changes=N` flag for controlling loop depth (default: 10)
