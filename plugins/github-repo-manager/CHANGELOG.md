# Changelog

All notable changes to the github-repo-manager plugin are documented here.

## [0.3.1] - 2026-03-04

### Fixed
- apply audit findings — plugin.json, CHANGELOG, skills


## [Unreleased]

## [0.3.0] - 2026-03-04

### Added
- **Org-aware assessments**: `owner_type` (User | Organization) is now established as session context during onboarding. All subsequent modules apply org-specific rules only where relevant.
- **Community health: org inheritance resolution** (new Step 0): For org repos, checks the org's `.github` repository before any per-file checks. Files inherited at the org level are reported as `✅ Inherited (org .github)` rather than flagged as missing.
- **Community health: API score caveat**: The GitHub community profile API excludes inherited files from its percentage. Org repo assessments now present this score with an explicit caveat and use the per-file breakdown as the authoritative view.
- **Community health: CODEOWNERS team pattern validation**: `@org/team-name` patterns are accepted as valid for org repos; flagged as likely invalid for user repos (personal accounts have no teams).
- **Security: org ruleset audit** (new Step 6): For org repos, checks `GET /orgs/{org}/rulesets` for org-level branch rulesets. Rulesets that cover the default branch suppress or contextualize per-repo "unprotected branch" findings.
- **Security: branch protection Applicability column**: The branch protection recommendation table now shows which rules apply to all repos vs. org repos only (e.g., team reviewers are only recommended for org repos).
- **Mutation guard hook** (`scripts/gh-manager-guard.sh`): PreToolUse hook that emits a mutation warning to the agent context window before any `gh-manager` write command runs. Exits 0 (non-blocking). Complements the existing PostToolUse audit trail in `gh-manager-monitor.sh`.
- `hooks/hooks.json` updated to register the PreToolUse Bash hook (`gh-manager-guard.sh`) alongside the existing PostToolUse hook (`gh-manager-monitor.sh`).


## [0.2.3] - 2026-03-02

### Fixed
- Add missing waivers and fix gh-manager PATH detection
- Remove invalid plugin.json fields and refactor mutation guards
- Apply auto-fixes from hygiene sweep


## [0.2.2] - 2026-02-20

### Changed
- Align plugin principles with trust-based philosophy


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

#### Configuration System
- Per-repo config (`.github-repo-manager.yml` committed to repo)
- Portfolio config (`~/.config/github-repo-manager/portfolio.yml` for multi-repo)
- Schema validation via `config validate` command

#### Skills and Intelligence
- 11 module skill files with YAML frontmatter for context-aware loading
- Cross-module intelligence framework with deduplication rules
- Orchestrator skill for multi-module assessment coordination

#### Templates
- Community file templates: CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, ISSUE_TEMPLATE, PR_TEMPLATE
