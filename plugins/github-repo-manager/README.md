# GitHub Repo Manager

Conversational GitHub repository health assessment and maintenance.

## Summary

GitHub Repo Manager provides a single `/repo-manager` command that assesses and fixes repository health interactively, with owner approval at every step. State what you want in natural language — Claude determines the scope, auto-detects the repository tier, and guides you through a structured session covering 9 assessment modules: security, release health, community health, PR management, issue triage, dependency audit, notifications, discussions, and wiki sync. A structured maintenance report is generated at session end.

## Principles

**[P1] Context at Decision Points** — Surface relevant context when a decision is required — enough to act, not a tutorial. Skip explanation for actions whose purpose is obvious from the invocation.

**[P2] Implication Warnings** — When an action has consequences the owner may not anticipate, name them before acting. This applies especially to publicly visible or hard-to-reverse actions.

**[P3] Irreversibility Flags** — Actions that cannot be easily undone are called out clearly before execution, with specific guidance on what becomes hard to recover.

**[P4] Risk-Proportional Friction** — Confirmation depth scales with the repository's public footprint and action reversibility. Private internal repos get minimal friction; public repos with active releases warrant additional care before irreversible operations.

**[P5] Progressive Depth** — Concise by default; deeper detail available on request.

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install github-repo-manager@l3digitalnet-plugins
```

## Installation Notes

After installation, the plugin's `ensure-deps.sh` script runs automatically on first use and installs the Node.js helper dependencies — no manual step required.

To pre-install explicitly (optional):

```bash
cd ~/.claude/plugins/cache/l3digitalnet-plugins/github-repo-manager
bash scripts/setup.sh
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
| `repo-manager` | Session onboarding, tier system, communication style, and error handling |
| `repo-manager-assessment` | Full assessment orchestration — module order, cross-module dedup, unified findings, reports |
| `repo-manager-reference` | gh-manager helper command reference |
| `repo-config` | Configuration system — per-repo, portfolio config, precedence, validation |
| `community-health` | Audit and manage CONTRIBUTING, SECURITY, CODE_OF_CONDUCT, issue/PR templates |
| `cross-repo` | Scope inference, batch mutations, and portfolio scanning across multiple repos |
| `dependency-audit` | Audit dependency health via dependency graph and Dependabot PRs |
| `discussions` | Manage GitHub Discussions — find unanswered questions, close resolved threads |
| `issue-triage` | Triage issues — label, categorize, detect linked PRs, identify stale issues |
| `notifications` | Process GitHub notifications with priority classification |
| `pr-management` | Manage PRs — triage, staleness, label management, review requests, merge workflow |
| `release-health` | Audit release health — unreleased commits, CHANGELOG drift, release cadence |
| `security` | Audit security posture — Dependabot alerts, code scanning, secret scanning |
| `wiki-sync` | Synchronize GitHub wiki content with in-repo docs |
| `self-test` | Self-diagnostics — verify PAT scopes, gh-manager install, and API connectivity |

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

- Node.js 18+
- GitHub PAT with `repo`, `read:org`, and `notifications` scopes
- Target repositories must be accessible via the authenticated GitHub account

## Architecture Note

This plugin intentionally runs entirely in the owner's main context window — no subagents are spawned during a session. This is a deliberate design choice: the owner must stay in the conversation loop at every step (tier confirmation, action approvals, module redirects), which requires continuous access to the shared context. The trade-off is that a full 9-module assessment consumes more context than a subagent-isolated design would. This is mitigated by keeping command files thin, delegating all API interaction to the external `gh-manager` helper (which runs outside the context window), and structured module presentation that avoids redundant output.

The core approval invariant ("no action without owner approval") is enforced behaviorally — conversational approval happens in prose and cannot be captured as a programmatic signal for hooks. Two mechanical layers complement the behavioral enforcement: a **PreToolUse guard** (`scripts/gh-manager-guard.sh`) that warns the agent when a mutation command is about to execute so it can abort if no prior approval exists, and a **PostToolUse audit trail** (`scripts/gh-manager-monitor.sh`) that logs completed mutations to `~/.github-repo-manager-audit.log` for recovery. Both hooks also provide rate-limit awareness via the `_rate_limit` field in gh-manager JSON output.

## Planned Features

- **GitLab support** — `glab`-backed equivalent for GitLab repositories and merge requests
- **Stale issue auto-close** — configurable threshold for automatically closing inactive issues after owner review
- **Scheduled reports** — cron-driven maintenance reports without requiring a manual session

## Known Issues

- **Insufficient PAT scopes cause silent module failures** — if the PAT lacks `notifications` scope, the notifications module returns empty results with no error; verify scopes with `gh-manager auth verify`
- **Cross-repo operations are rate-limited** — large portfolios may hit GitHub API rate limits during batch scans; check status with `gh-manager auth rate-limit` and use per-module checks to stay within limits
- **No dry-run for most mutation types** — only wiki operations (`wiki init`, `wiki push`) support `--dry-run`. PR merges, issue closes, label operations, and direct file commits do not have a dry-run preview; the tier system and owner approval flows are the primary safeguards for these actions
