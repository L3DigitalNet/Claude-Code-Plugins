# GitHub Repo Manager — Usage Guide

## Quick Start

In Claude Code:

```
/repo-manager
Check ha-light-controller
```

That's it. Claude determines the scope from your request and guides you through the session.

## Invocation

The plugin has a single entry point:

```
/repo-manager
```

After activation, state what you need. Claude infers the mode:

| You say | Claude does |
|---------|-------------|
| "Check ha-light-controller" | Deep single-repo assessment |
| "How are the PRs on my-project?" | Narrow single-repo check |
| "Are any repos missing SECURITY.md?" | Cross-repo targeted check |
| "What's the state of my public repos?" | Cross-repo summary |

## Helper CLI Reference

The `gh-manager` helper handles all GitHub API interaction. You don't normally call it directly — Claude invokes it as needed. But it's useful for debugging and verification.

```bash
# All commands output JSON to stdout
node helper/bin/gh-manager.js <command> [options]
```

### Authentication

```bash
# Verify PAT and report scopes
gh-manager auth verify

# Show rate limit status (REST, GraphQL, Search)
gh-manager auth rate-limit
```

### Repository Discovery

```bash
# List all accessible repos (trimmed metadata)
gh-manager repos list
gh-manager repos list --limit 10

# Auto-detect tier for a repo (composite command)
# Returns: signals (visibility, fork, archived, releases, code signals) + suggested tier
gh-manager repos classify --repo owner/name
```

### Single-Repo Metadata

```bash
# Fetch trimmed repo metadata
gh-manager repo info --repo owner/name

# Fetch GitHub community profile score
gh-manager repo community --repo owner/name
```

### Label Management

```bash
# List all labels on a repo
gh-manager repo labels list --repo owner/name

# Create a label (idempotent — no-op if already exists)
gh-manager repo labels create --repo owner/name --name "maintenance" --color "0E8A16" --description "Maintenance task"

# Update an existing label
gh-manager repo labels update --repo owner/name --name "maintenance" --color "1D76DB"

# Preview what would happen (no changes made)
gh-manager repo labels create --repo owner/name --name "stale" --dry-run
```

## Tier System

Repos are classified into four tiers that control how much ceremony the plugin applies:

| Tier | Description | Mutations |
|------|-------------|-----------|
| 1 | Private, docs only | Batch approval, direct commit |
| 2 | Private, runnable code | Show diffs, direct commit |
| 3 | Public, no releases | Detailed review, direct commit |
| 4 | Public, with releases | PRs for file changes, full review |

The tier is auto-detected on first run. You can override it in config.

## Configuration

### Per-Repo Config (`.github-repo-manager.yml`)

Placed in the repo root. Controls module toggles and thresholds per-repo.

### Portfolio Config (`~/.config/github-repo-manager/portfolio.yml`)

Central config for cross-repo settings. Overrides per-repo config.

### Config Precedence (highest to lowest)

1. Portfolio per-repo overrides
2. Per-repo config (`.github-repo-manager.yml`)
3. Portfolio defaults
4. Tier defaults (built-in)

See [POLICIES.md](POLICIES.md) for customizable settings.

### File Operations

```bash
# Check if a file exists
gh-manager files exists --repo owner/name --path SECURITY.md

# Fetch file content (decoded)
gh-manager files get --repo owner/name --path CONTRIBUTING.md

# Create or update a file (content from stdin)
echo "# Security Policy" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md"

# Create file on a branch (Tier 4 PR workflow)
echo "content" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md" --branch maintenance/community-health-2026-02-17

# Delete a file
gh-manager files delete --repo owner/name --path old-file.md --message "Remove old file"

# Preview any mutation
echo "content" | gh-manager files put --repo owner/name --path SECURITY.md --dry-run
```

### Branch Operations

```bash
# List branches
gh-manager branches list --repo owner/name

# Create a branch from the default branch
gh-manager branches create --repo owner/name --branch maintenance/community-health-2026-02-17 --from main

# Delete a branch
gh-manager branches delete --repo owner/name --branch maintenance/community-health-2026-02-17
```

### Pull Request Operations (expanded in Phase 3)

```bash
# List open PRs
gh-manager prs list --repo owner/name

# Get full PR details with reviews, CI status, size
gh-manager prs get --repo owner/name --pr 42

# Get changed files with patches
gh-manager prs diff --repo owner/name --pr 42

# Get comments (for dedup marker checking)
gh-manager prs comments --repo owner/name --pr 42

# Create a maintenance PR
gh-manager prs create --repo owner/name --head maintenance/community-health-2026-02-17 --base main --title "[Maintenance] Add SECURITY.md" --label maintenance

# Add/remove labels
gh-manager prs label --repo owner/name --pr 42 --add "ready-to-merge"

# Post a comment
gh-manager prs comment --repo owner/name --pr 42 --body "Updated with new files"

# Request reviewers
gh-manager prs request-review --repo owner/name --pr 42 --reviewers "user1,org/team"

# Merge (merge, squash, or rebase)
gh-manager prs merge --repo owner/name --pr 42 --method squash

# Close with comment
gh-manager prs close --repo owner/name --pr 42 --body "Superseded by #55"
```

### Issue Operations

```bash
# List open issues (excludes PRs)
gh-manager issues list --repo owner/name

# Get full issue details with linked PRs
gh-manager issues get --repo owner/name --issue 12

# Get comments
gh-manager issues comments --repo owner/name --issue 12

# Add labels
gh-manager issues label --repo owner/name --issue 12 --add "bug,priority-high"

# Post a comment
gh-manager issues comment --repo owner/name --issue 12 --body "Activity check"

# Close as completed (with comment)
gh-manager issues close --repo owner/name --issue 12 --body "Fixed by PR #15" --reason completed

# Close as not planned
gh-manager issues close --repo owner/name --issue 8 --reason not_planned

# Assign
gh-manager issues assign --repo owner/name --issue 12 --assignees "username"
```

### Notification Operations

```bash
# List unread notifications, categorized by priority
gh-manager notifications list --repo owner/name

# Include read notifications
gh-manager notifications list --repo owner/name --all

# Mark a single thread as read
gh-manager notifications mark-read --repo owner/name --thread-id 12345

# Mark all repo notifications as read
gh-manager notifications mark-read --repo owner/name
```

### Wiki Operations

```bash
# Clone wiki repo to a temporary directory
gh-manager wiki clone --repo owner/name --dir /tmp/wiki-myrepo

# Initialize wiki (creates Home page if wiki repo doesn't exist yet)
gh-manager wiki init --repo owner/name

# Diff generated content against current wiki pages
gh-manager wiki diff --dir /tmp/wiki-myrepo --content-dir /tmp/wiki-generated

# Commit and push all wiki changes
gh-manager wiki push --dir /tmp/wiki-myrepo --message "Wiki sync 2026-02-17"

# Clean up temporary directory
gh-manager wiki cleanup --dir /tmp/wiki-myrepo
```

### Security Operations

```bash
# Dependabot vulnerability alerts (with severity summary)
gh-manager security dependabot --repo owner/name
gh-manager security dependabot --repo owner/name --severity critical

# Code scanning alerts (CodeQL, third-party)
gh-manager security code-scanning --repo owner/name

# Secret scanning alerts
gh-manager security secret-scanning --repo owner/name

# Repository security advisories
gh-manager security advisories --repo owner/name

# Branch protection audit (read-only)
gh-manager security branch-rules --repo owner/name
```

### Dependency Audit Operations

```bash
# Dependency graph summary (SBOM)
gh-manager deps graph --repo owner/name

# Open Dependabot PRs with age and severity
gh-manager deps dependabot-prs --repo owner/name
```

### Release Operations

```bash
# List recent releases
gh-manager releases list --repo owner/name --limit 10

# Get latest release details
gh-manager releases latest --repo owner/name

# Commits since last release (unreleased work)
gh-manager releases compare --repo owner/name

# Fetch and parse CHANGELOG.md
gh-manager releases changelog --repo owner/name

# Create a draft release
gh-manager releases draft --repo owner/name --tag v1.3.0 --name "v1.3.0" --body "Release notes..."

# Publish a draft release
gh-manager releases publish --repo owner/name --release-id 12345
```

### Discussion Operations (GraphQL)

```bash
# List discussions with unanswered/stale classification
gh-manager discussions list --repo owner/name

# Post a comment on a discussion
gh-manager discussions comment --repo owner/name --discussion 5 --body "Thanks for the feedback"

# Close a discussion (RESOLVED, OUTDATED, DUPLICATE)
gh-manager discussions close --repo owner/name --discussion 5 --reason RESOLVED
```

### Config Operations

```bash
# Read .github-repo-manager.yml from a repo
gh-manager config repo-read --repo owner/name

# Write .github-repo-manager.yml to a repo (content from stdin)
echo "repo:
  tier: 4" | gh-manager config repo-write --repo owner/name

# Write via PR on Tier 4
echo "YAML" | gh-manager config repo-write --repo owner/name --branch maintenance/add-config

# Read local portfolio.yml
gh-manager config portfolio-read

# Write local portfolio.yml (content from stdin)
echo "owner:
  expertise: intermediate
repos:
  my-fork:
    skip: true" | gh-manager config portfolio-write

# Resolve effective config (merged precedence)
gh-manager config resolve --repo owner/name
```

## Current Phase

**v0.2.1 — All Phases Complete.** The plugin covers all 9 assessment modules (security, release health, community health, PR management, issue triage, dependency audit, notifications, discussions, wiki sync), cross-repo batch operations, config management (per-repo and portfolio), report generation, and cross-module intelligence.
