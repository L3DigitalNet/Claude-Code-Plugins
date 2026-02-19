# GitHub Repo Manager

Conversational GitHub repository health assessment and maintenance.

## Summary

GitHub Repo Manager provides a single `/repo-manager` command that assesses and fixes repository health interactively, with owner approval at every step. State what you want in natural language — Claude determines the scope, auto-detects the repository tier, and guides you through a structured session covering 9 assessment modules: security, release health, community health, PR management, issue triage, dependency audit, notifications, discussions, and wiki sync. A structured maintenance report is generated at session end.

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install github-repo-manager@l3digitalnet-plugins
```

## Installation Notes

After installation, install Node.js dependencies for the helper CLI:

```bash
cd ~/.claude/plugins/<marketplace>/github-repo-manager
npm install
```

A GitHub Personal Access Token (PAT) with `repo`, `read:org`, and `notifications` scopes is required. See [docs/SETUP.md](docs/SETUP.md) for full setup instructions.

## Usage

```
/repo-manager
Check ha-light-controller
```

After activation, state what you need — Claude infers the mode:

| You say | Claude does |
|---------|-------------|
| "Check ha-light-controller" | Deep single-repo assessment |
| "How are the PRs on my-project?" | Narrow single-repo check |
| "Are any repos missing SECURITY.md?" | Cross-repo targeted check |
| "What's the state of my public repos?" | Cross-repo summary |

## Commands

| Command | Description |
|---------|-------------|
| `/repo-manager` | Activate GitHub repository management session |

## Skills

| Skill | Description |
|-------|-------------|
| `repo-manager` | Core orchestration — session lifecycle, tier system, module coordination |
| `community-health` | Audit and manage CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue/PR templates |
| `cross-repo` | Orchestrate operations across multiple repositories |
| `dependency-audit` | Audit dependency health via dependency graph and Dependabot PRs |
| `discussions` | Manage GitHub Discussions — find unanswered questions, close resolved threads |
| `issue-triage` | Triage issues — label, categorize, detect linked PRs, identify stale issues |
| `notifications` | Process GitHub notifications with priority classification |
| `pr-management` | Manage PRs — triage, staleness, label management, review requests, merge workflow |
| `release-health` | Audit release health — unreleased commits, CHANGELOG drift, release cadence |
| `security` | Audit security posture — Dependabot alerts, code scanning, secret scanning |
| `wiki-sync` | Synchronize GitHub wiki content with in-repo docs |

## Tier System

Repos are auto-classified into four tiers that control how much ceremony the plugin applies:

| Tier | Repo type | Mutations |
|------|-----------|-----------|
| 1 | Private, docs only | Batch approval, direct commit |
| 2 | Private, runnable code | Show diffs, direct commit |
| 3 | Public, no releases | Detailed review, direct commit |
| 4 | Public, with releases | PRs for file changes, full review |

Tier is auto-detected on first run and can be overridden in config.

## Configuration

| File | Location | Purpose |
|------|----------|---------|
| `.github-repo-manager.yml` | Repo root | Per-repo module toggles and thresholds |
| `portfolio.yml` | `~/.config/github-repo-manager/` | Central config for cross-repo settings |

Config precedence (highest to lowest): portfolio per-repo overrides → per-repo config → portfolio defaults → tier defaults.

See [docs/POLICIES.md](docs/POLICIES.md) for all customizable settings and [docs/USAGE.md](docs/USAGE.md) for the full helper CLI reference.

## Requirements

- Node.js 20+
- GitHub PAT with `repo`, `read:org`, and `notifications` scopes
- Target repositories must be accessible via the authenticated GitHub account

## Planned Features

- **GitLab support** — `glab`-backed equivalent for GitLab repositories and merge requests
- **Stale issue auto-close** — configurable threshold for automatically closing inactive issues after owner review
- **Scheduled reports** — cron-driven maintenance reports without requiring a manual session

## Known Issues

- **`npm install` must be run manually** — the plugin installer does not execute `npm install`; dependencies are not available until you run it in the plugin cache directory (see Installation Notes above)
- **Insufficient PAT scopes cause silent module failures** — if the PAT lacks `notifications` scope, the notifications module returns empty results with no error; verify scopes with `gh-manager auth verify`
- **Cross-repo operations are rate-limited** — large portfolios may hit GitHub API rate limits during batch scans; check status with `gh-manager auth rate-limit` and use per-module checks to stay within limits
