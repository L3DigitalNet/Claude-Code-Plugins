---
description: GitHub Repo Manager helper command reference. Use when looking up gh-manager command syntax or checking what operations are available.
---

# GitHub Repo Manager — Helper Command Reference

All GitHub API calls go through the helper:

```bash
node ${CLAUDE_PLUGIN_ROOT}/helper/bin/gh-manager.js <command> [options]
```

The helper returns structured JSON to stdout. Errors return JSON to stderr with a non-zero exit code. Every successful response includes `_rate_limit` metadata. **Never call GitHub APIs directly.**

## Available Commands

```
# Auth (Phase 0)
gh-manager auth verify                    # Check PAT and report scopes
gh-manager auth rate-limit                # Show rate limit status

# Repo discovery (Phase 0)
gh-manager repos list [--limit N]         # List all accessible repos
gh-manager repos classify --repo X/Y     # Auto-detect tier for a repo

# Repo metadata (Phase 0)
gh-manager repo info --repo X/Y          # Fetch repo metadata
gh-manager repo community --repo X/Y     # Fetch community profile score
gh-manager repo labels list --repo X/Y   # List labels
gh-manager repo labels create --repo X/Y --name N [--color HEX] [--description TEXT] [--dry-run]
gh-manager repo labels update --repo X/Y --name N [--new-name N] [--color HEX] [--description TEXT] [--dry-run]

# File operations (Phase 1)
gh-manager files exists --repo X/Y --path PATH [--branch B]
gh-manager files get --repo X/Y --path PATH [--branch B]
echo "content" | gh-manager files put --repo X/Y --path PATH --message MSG [--branch B] [--dry-run]
gh-manager files delete --repo X/Y --path PATH --message MSG [--branch B] [--dry-run]

# Branch operations (Phase 1)
gh-manager branches list --repo X/Y [--limit N]
gh-manager branches create --repo X/Y --branch NAME --from REF [--dry-run]
gh-manager branches delete --repo X/Y --branch NAME [--dry-run]

# PR operations (Phase 1 + Phase 3)
gh-manager prs list --repo X/Y [--state open|closed|all] [--label L] [--limit N]
gh-manager prs get --repo X/Y --pr N
gh-manager prs diff --repo X/Y --pr N
gh-manager prs comments --repo X/Y --pr N [--limit N]
gh-manager prs create --repo X/Y --head BRANCH --base BRANCH --title T [--body B] [--label L] [--dry-run]
gh-manager prs label --repo X/Y --pr N [--add L] [--remove L] [--dry-run]
gh-manager prs comment --repo X/Y --pr N --body TEXT [--dry-run]
gh-manager prs request-review --repo X/Y --pr N --reviewers USERS [--dry-run]
gh-manager prs merge --repo X/Y --pr N [--method merge|squash|rebase] [--dry-run]
gh-manager prs close --repo X/Y --pr N [--body TEXT] [--dry-run]

# Wiki operations (Phase 2) — git-based, not REST API
gh-manager wiki clone --repo X/Y --dir /tmp/wiki-DIR
gh-manager wiki init --repo X/Y [--dry-run]
gh-manager wiki diff --dir /tmp/wiki-DIR --content-dir /tmp/wiki-generated-DIR
gh-manager wiki push --dir /tmp/wiki-DIR --message MSG [--dry-run]
gh-manager wiki cleanup --dir /tmp/wiki-DIR

# Issue operations (Phase 3)
gh-manager issues list --repo X/Y [--state open|closed|all] [--label L] [--limit N]
gh-manager issues get --repo X/Y --issue N
gh-manager issues comments --repo X/Y --issue N [--limit N]
gh-manager issues label --repo X/Y --issue N [--add L] [--remove L] [--dry-run]
gh-manager issues comment --repo X/Y --issue N --body TEXT [--dry-run]
gh-manager issues close --repo X/Y --issue N [--body TEXT] [--reason completed|not_planned] [--dry-run]
gh-manager issues assign --repo X/Y --issue N --assignees USERS [--dry-run]

# Notification operations (Phase 3)
gh-manager notifications list --repo X/Y [--all] [--limit N]
gh-manager notifications mark-read --repo X/Y [--thread-id ID] [--dry-run]

# Security operations (Phase 4) — all read-only
gh-manager security dependabot --repo X/Y [--state STATE] [--severity LEVEL]
gh-manager security code-scanning --repo X/Y [--state STATE]
gh-manager security secret-scanning --repo X/Y [--state STATE]
gh-manager security advisories --repo X/Y
gh-manager security branch-rules --repo X/Y [--branch NAME]

# Dependency audit operations (Phase 4)
gh-manager deps graph --repo X/Y
gh-manager deps dependabot-prs --repo X/Y

# Release operations (Phase 5)
gh-manager releases list --repo X/Y [--limit N]
gh-manager releases latest --repo X/Y
gh-manager releases compare --repo X/Y
gh-manager releases draft --repo X/Y --tag TAG [--name N] [--body B] [--target BRANCH] [--dry-run]
gh-manager releases publish --repo X/Y --release-id ID [--dry-run]
gh-manager releases changelog --repo X/Y

# Discussion operations (Phase 5) — GraphQL
gh-manager discussions list --repo X/Y [--category ID] [--limit N]
gh-manager discussions comment --repo X/Y --discussion N --body TEXT [--dry-run]
gh-manager discussions close --repo X/Y --discussion N [--reason RESOLVED|OUTDATED|DUPLICATE] [--dry-run]

# Config operations (Phase 6)
gh-manager config repo-read --repo X/Y
echo "YAML" | gh-manager config repo-write --repo X/Y [--branch BRANCH] [--dry-run]
gh-manager config portfolio-read
echo "YAML" | gh-manager config portfolio-write [--dry-run]
gh-manager config resolve --repo X/Y
```

⚠️ **`config portfolio-write`** affects behavior across **all repos in the portfolio** — staleness thresholds, module toggles, expertise level, and per-repo overrides all inherit from portfolio defaults. Always run `config portfolio-read` first and preview with `--dry-run` before writing.
