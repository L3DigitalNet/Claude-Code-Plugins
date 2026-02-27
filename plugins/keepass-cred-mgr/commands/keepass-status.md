---
description: Show KeePass vault status, accessible groups, and inactive entries pending review.
allowed-tools: mcp__keepass__list_groups, mcp__keepass__list_entries
---

# KeePass Vault Status

Execute these steps in order. Report results inline.

## 1. Check Vault State

Call `list_groups`.
- If it succeeds: the vault is **unlocked**. Report the list of accessible groups.
- If it raises VaultLocked: the vault is **locked**. Report this and stop.

## 2. Inactive Entry Audit

For each accessible group, call `list_entries` with `include_inactive=true`.

Filter to entries whose title starts with `[INACTIVE]`. Collect them into a summary table:

| Group | Title | Status |
|-------|-------|--------|
| ... | ... (without [INACTIVE] prefix) | Pending review |

If no inactive entries exist, report "No inactive entries pending review."

## 3. Summary

Report:
- Vault state (locked/unlocked)
- Number of accessible groups
- Total inactive entries pending review
