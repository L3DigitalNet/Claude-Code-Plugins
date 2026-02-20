# Changelog

All notable changes to the github-repo-manager plugin are documented here.

## [0.2.2] - 2026-02-20

### Changed
- align plugin principles with trust-based philosophy
- pre-release staging — update github-repo-manager, linux-sysadmin-mcp, release-pipeline


## [Unreleased]

### Added
- `scripts/gh-manager-guard.sh` — PreToolUse hook that emits a mutation-warning to the agent context window before any `gh-manager` write command runs. Exits 0 (non-blocking warning). Complements the existing PostToolUse audit trail in `gh-manager-monitor.sh`.
- `hooks/hooks.json` updated to register the PreToolUse Bash hook (`gh-manager-guard.sh`) alongside the existing PostToolUse hook (`gh-manager-monitor.sh`).

## [0.2.1] - 2026-02-19

### Fixed
- `repos classify`: added `tier` key as alias for `suggested_tier` for consistent field naming in skill layer and tests
- `files exists`: now exits 1 when file is not found (404), matching the command contract (exit code signals presence)
- `security dependabot`: returns success with `accessible: false` on 403/404 for graceful skill-layer degradation
- `security code-scanning`: same graceful degradation pattern on 403
- `repo labels create/update`: flattened label fields to top level (`name`, `color`, `description`) instead of nesting under `label` object
- `branches create`: added `name` alias alongside `branch` field in response shapes for consistent key naming
- All three self-test tiers now pass (Tier A: 61/61, Tier B: 28/28, Tier C: 40/40 + 3 expected skips)

## [0.2.0] - 2026-02-18

### Added
- YAML frontmatter on all 12 skills (11 modules + orchestrator) for proper Claude Code trigger matching
- `ensure-deps.sh` for automatic first-run dependency installation
- `.gitignore` in `helper/` to exclude `node_modules/` from git

### Fixed
- Fixed PAT leak in wiki error messages — sanitize token from git URLs in clone/init/push errors
- Fixed `--name` to `--branch` flag in cross-repo, release-health skills and Tier C tests
- Fixed `--comment` to `--body` flag in Tier C tests for `issues close` and `prs close`
- Fixed stdin handling: `files put` and `config write` commands no longer hang or silently accept empty input on TTY
- Fixed GraphQL injection vector in `discussions list` — `categoryId` now uses proper GraphQL variable
- Fixed `branches create --from` CLI description to accurately state "branch name" (not tags/SHAs)
- Simplified `error()` exit code in `output.js` — removed dead ternary
- Removed stale Phase 0 "not yet implemented" note from orchestrator skill
- Changed Phase 6 status from ⏳ to ✅ in orchestrator skill availability section
- Updated `docs/SETUP.md` with working directory clarification and script references
- Added `set -e` omission comment in `tests/run-all.sh`
- Added explanatory comments for hardcoded `master` branch in wiki operations
- Added pagination limitation comment in `notifications list`

## [0.1.1] - 2026-02-17

### Fixed
- `hooks/hooks.json` schema corrected from empty array `[]` to valid record `{"hooks": {}}`

## [0.1.0] - 2026-02-17

### Added
- Initial release with conversational GitHub repository maintenance

#### Assessment Modules (9)
- **Security posture** — vulnerability alerts, code scanning, secret scanning, branch protection audit
- **Release health** — tag cadence, changelog drift, stale release detection
- **Community health** — license, README, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, issue/PR templates
- **PR management** — stale PR detection, review bottleneck analysis, label enforcement
- **Issue triage** — stale/unlabeled issue detection, assignment gaps, duplicate candidates
- **Dependency audit** — Dependabot alert aggregation, outdated dependency tracking
- **Notifications** — unread notification processing, filtering, mark-read operations
- **Discussions** — discussion listing, commenting, close operations via GraphQL
- **Wiki sync** — clone, diff, push workflow for repository wikis

#### gh-manager Helper CLI
- Full CLI with 40+ commands across repos, issues, PRs, files, branches, releases, config, wiki, discussions, and notifications
- JSON-structured output for all commands (machine-parseable by skill layer)
- PAT-based authentication with `auth verify` command

#### Test Framework
- Three-tier test architecture: Tier A (offline/infrastructure), Tier B (read-only API), Tier C (mutation tests)
- Shared test library (`lib.sh`) with JSON assertion helpers
- `run-all.sh` orchestrator with per-tier selection

#### Configuration System
- Per-repo config (`.github-repo-manager.yml` committed to repo)
- Portfolio config (`~/.config/github-repo-manager/portfolio.yml` for multi-repo)
- Schema validation via `config validate` command
- Config resolution with source precedence chain

#### Skills and Intelligence
- 11 module skill files with YAML frontmatter for context-aware loading
- Cross-module intelligence framework with deduplication rules
- Orchestrator skill for multi-module assessment coordination

#### Templates
- Community file templates: CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, ISSUE_TEMPLATE, PR_TEMPLATE
