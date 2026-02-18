# GitHub Repo Manager — Customizable Policies

## Overview

The plugin ships with sensible defaults for every setting. You only need to customize what you want to change. Unspecified values cascade from tier defaults.

## Staleness Thresholds

Control when PRs, issues, and discussions are flagged as needing attention.

| Setting | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Configurable |
|---------|--------|--------|--------|--------|-------------|
| PR flagged as stale | 7 days | 14 days | 21 days | 30 days | `pr_management.staleness_threshold_days` |
| PR proposed for closing | 30 days | 60 days | Owner decision | Owner decision | `pr_management.staleness_threshold_days` |
| Issue flagged as stale | 14 days | 21 days | 30 days | 30 days | `issue_triage.staleness_threshold_days` |
| Discussion flagged as stale | 14 days | 21 days | 30 days | 30 days | `discussions.staleness_threshold_days` |

Set to `auto` (the default) to use the tier-based value, or specify a number to override:

```yaml
pr_management:
  staleness_threshold_days: 14  # Override tier default
```

## Ignore Labels

PRs and issues with these labels are excluded from staleness checks and close proposals:

```yaml
pr_management:
  ignore_labels:
    - "do-not-close"
    - "long-running"

issue_triage:
  ignore_labels:
    - "long-term"
    - "backlog"
```

## PR Size Thresholds

Control the S/M/L/XL size classification for PR triage:

```yaml
pr_management:
  size_thresholds:
    small: 50       # Lines changed
    medium: 200
    large: 500
    xlarge: 1000
```

## Community Health Files

Control which files the community health module requires:

```yaml
community_health:
  required_files:
    - README.md
    - CONTRIBUTING.md
    - CODE_OF_CONDUCT.md
    - SECURITY.md
    - LICENSE
```

## Module Toggles

Enable or disable any module per-repo:

```yaml
modules:
  wiki_sync:
    enabled: true          # Tiers 3-4 only
  community_health:
    enabled: true
  pr_management:
    enabled: true
  notifications:
    enabled: true
  security:
    enabled: true
  discussions:
    enabled: true
  dependency_audit:
    enabled: true
  issue_triage:
    enabled: true
  release_health:
    enabled: true          # Tier 4 only
```

**Note:** Setting `enabled: true` on a module that doesn't apply to the repo's tier is silently ignored (e.g., `wiki_sync: enabled: true` on a Tier 1 private repo). Setting `enabled: false` always disables the module regardless of tier.

## Wiki Sync Settings

```yaml
wiki_sync:
  orphan_handling: "warn"   # warn | delete | archive
  doc_sources:
    - "docs/"
    - "README.md"
  exclude_patterns:
    - "docs/internal/"
  auto_generate:
    - "functions"           # Auto-generate from code analysis
    - "cli"
    - "config"
```

## Security Settings

```yaml
security:
  audit_branch_protection: true
  required_branch_protections:
    - require_pull_request_reviews
    - require_status_checks
    - enforce_admins
```

## Release Health Settings

```yaml
release_health:
  changelog_files:
    - CHANGELOG.md
    - CHANGES.md
    - HISTORY.md
  cadence_warning_multiplier: 2.0   # Warn at 2x average release interval
```

## Notification Filtering

```yaml
notifications:
  priority_filter: "high"   # all | low | medium | high | critical
```

## Deferred Items

```yaml
settings:
  deferred_items:
    persist: true            # Create/update tracking issue for deferrals
    pin_issue: true          # Pin the tracking issue
    auto_resolve: true       # Move items to Resolved when addressed
```

## Report Format

```yaml
settings:
  report_format: "markdown"  # markdown | json
  verbose: true
```

## Owner Expertise Level

Set in the portfolio config (`~/.config/github-repo-manager/portfolio.yml`):

```yaml
owner:
  expertise: beginner        # beginner | intermediate | advanced
```

Controls how much explanation the plugin provides. See the design doc Section 7.6 for details on each level.
