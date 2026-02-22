# github-repo-manager

Conversational GitHub repository maintenance — health auditing, wiki sync, PR triage, security posture, and community file management via PAT.

## Summary

github-repo-manager turns Claude Code into an interactive GitHub repository maintenance assistant. Invoke `/repo-manager`, tell it which repo (or repos) to look at, and it runs a structured health assessment across up to nine modules — security, releases, community files, PRs, issues, dependencies, notifications, discussions, and wiki — then surfaces findings in a single prioritized view and proposes specific actions for your approval. Every mutation goes through the `gh-manager` helper CLI (a Node.js wrapper around the GitHub API) and requires explicit owner confirmation before execution. Sessions are scoped: the plugin activates on `/repo-manager` and exits cleanly when you're done, leaving no residual behavior.

## Principles

**No action without approval** — The plugin never mutates a repository without explicit owner approval during the session. It explains what it's about to do and why, then waits. The PreToolUse hook provides a mechanical enforcement layer that warns the agent before any write command runs.

**Fail transparently, succeed quietly** — Errors are surfaced in plain language with recovery options. Rate-limit warnings, permission gaps, and API failures are reported conversationally; the session never silently skips something consequential. Successful steps collapse to a single confirmation line.

**Tier-aware ceremony** — The plugin classifies each repo into one of four tiers (private/docs, private/code, public/no-releases, public/releases) and scales mutation strategy, explanation depth, and staleness thresholds to match. A private scratch repo gets batch approvals and brief summaries; a public repo with releases gets PRs for file changes and full diff review.

**Expertise-aware communication** — Default explanation level is beginner: GitHub concepts get explained on first mention, irreversible actions get flagged, and jargon gets translated. Owners can shift to intermediate or advanced mid-session, and persist the preference in the portfolio config.

## Requirements

- Claude Code (any recent version)
- Node.js 18 or later (for the `gh-manager` helper)
- `gh` CLI authenticated with `repo`, `read:org`, and `notifications` scopes (used by the helper)
- GitHub Personal Access Token (PAT) set as `GITHUB_PAT` in your environment
  - Classic PAT minimum scopes: `repo`, `notifications`
  - Fine-grained PATs: grant Repository read/write access for the target repos

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install github-repo-manager@l3digitalnet-plugins
```

For local development:

```bash
claude --plugin-dir ./plugins/github-repo-manager
```

### Post-Install Steps

1. Install helper dependencies (the plugin does this automatically on first `/repo-manager` invocation via `ensure-deps.sh`, but you can also run it manually):

   ```bash
   bash plugins/github-repo-manager/scripts/setup.sh
   ```

2. Set your GitHub PAT:

   ```bash
   export GITHUB_PAT=ghp_your_token_here
   ```

3. Verify authentication before your first session:

   ```bash
   node plugins/github-repo-manager/helper/bin/gh-manager.js auth verify
   ```

## How It Works

```mermaid
flowchart TD
    User([User]) -->|/repo-manager| CMD[Command loads core skill]
    CMD --> DEPS[ensure-deps.sh — verify Node + npm deps]
    DEPS --> PAT{PAT valid?}
    PAT -->|No| ONBOARD[Onboarding: explain PAT, prompt to set]
    PAT -->|Yes| SCOPE{Scope?}
    ONBOARD --> PAT
    SCOPE -->|Single repo| TIER[repos classify — detect Tier 1-4]
    SCOPE -->|Cross-repo| CROSS[Cross-repo orchestration]
    TIER --> CONFIG[Read .github-repo-manager.yml if present]
    CONFIG --> LABELS[Bootstrap maintenance labels if missing]
    LABELS --> ASSESS[Run 9 assessment modules in order]
    ASSESS --> UNIFIED((Unified findings view))
    UNIFIED --> ACTIONS[Propose actions — await approval]
    ACTIONS --> EXEC[Execute via gh-manager helper]
    EXEC --> WRAP((Session wrap-up + optional report))
```

## Usage

Invoke the plugin with a natural-language request:

```
/repo-manager check my ha-light-controller repo
/repo-manager are any of my public repos missing a SECURITY.md?
/repo-manager what PRs need attention across my repos?
/repo-manager show me the security posture on owner/my-repo
```

**Session flow:**

1. The plugin determines scope (single-repo or cross-repo) from your request.
2. On first run it checks dependencies, verifies your PAT, detects the repo tier, and bootstraps maintenance labels — steps that succeed silently collapse to one confirmation line.
3. For a full assessment it runs all nine modules in order, emitting a progress line per module, then presents one consolidated findings view grouped by severity (critical / needs attention / healthy).
4. For each actionable finding it proposes a specific action and waits for your approval before executing.
5. At session end it summarizes actions taken, lists any deferred items, and offers to generate a markdown report.

The plugin exits cleanly when you change topic or say you're done.

## Commands

| Command | Description |
|---------|-------------|
| `/repo-manager` | Activate a GitHub repository management session |

## Skills

| Skill | Description |
|-------|-------------|
| `repo-manager` | Core session orchestrator — onboarding, tier detection, communication style, and session lifecycle |
| `repo-manager-assessment` | Full multi-module assessment orchestration — module sequencing, cross-module deduplication, and unified findings presentation |
| `repo-manager-reference` | `gh-manager` helper command reference — all available CLI commands and their options |
| `security` | Audit repository security posture — Dependabot alerts, code scanning, secret scanning, advisories, and branch protection rules |
| `release-health` | Audit release health — unreleased commits, CHANGELOG drift, release cadence, and draft releases |
| `community-health` | Audit and manage GitHub community health files (README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, issue/PR templates) |
| `pr-management` | Manage pull requests — triage, staleness detection, label management, review requests, and merge workflow |
| `issue-triage` | Triage GitHub issues — label, categorize, detect linked PRs, identify stale issues, and close resolved ones |
| `dependency-audit` | Audit dependency health via dependency graph and Dependabot PRs |
| `notifications` | Process GitHub notifications with priority classification |
| `discussions` | Manage GitHub Discussions — find unanswered questions, stale threads, and close resolved discussions |
| `wiki-sync` | Synchronize GitHub wiki content — clone, diff, generate, and push wiki pages |
| `cross-repo` | Cross-repository operations — scope inference, batch mutations, and portfolio scanning |
| `repo-config` | Configuration system — per-repo and portfolio config files, precedence rules, and validation |
| `self-test` | Run the plugin self-test suite to validate helper installation and API connectivity |

## Hooks

| Hook | Event | What it does |
|------|-------|--------------|
| `gh-manager-guard.sh` | PreToolUse (Bash) | Detects `gh-manager` mutation commands about to run, emits a warning to the agent context to verify owner approval was given, and logs a pending entry to the audit trail at `~/.github-repo-manager-audit.log`. Non-blocking (exits 0). |
| `gh-manager-monitor.sh` | PostToolUse (Bash) | Watches `_rate_limit` in every `gh-manager` response and warns when the API budget drops below 300 (warning) or 100 (critical). Logs all completed non-dry-run mutations to the audit trail. |

Both hooks match only Bash tool calls and only when the command contains `gh-manager`. Dry-run invocations are always skipped. The mutation pattern lists in both scripts are kept in sync — if a new write command is added to the helper, both scripts must be updated.

## Planned Features

No unreleased items are currently tracked in the changelog.

## Known Issues

- Notification pagination is limited — the `notifications list` command does not paginate beyond the first page of results; large notification backlogs will be truncated.
- Wiki operations hardcode the `master` branch for git operations, which will fail on wikis that use `main` as the default branch.
- Fine-grained PATs cannot have their scopes verified via response headers — the `auth verify` command reports PAT type but cannot enumerate permissions for fine-grained tokens.
- The `config portfolio-write` command affects staleness thresholds and module behavior across all repos in the portfolio; running it without reviewing the current config first can silently change behavior for unrelated repos.

## Links

- Repository: [L3DigitalNet/Claude-Code-Plugins](https://github.com/L3DigitalNet/Claude-Code-Plugins)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
- Issues: [GitHub Issues](https://github.com/L3DigitalNet/Claude-Code-Plugins/issues)
