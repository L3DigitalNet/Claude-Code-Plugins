---
description: List all deactivated KeePass entries with their deactivation timestamps.
allowed-tools: mcp__keepass__list_groups, mcp__keepass__list_entries, mcp__keepass__get_entry
---

# KeePass Deactivated Entry Audit

## 1. Gather All Inactive Entries

Call `list_groups` to get accessible groups.

For each group, call `list_entries` with `include_inactive=true`.
Filter to entries whose title starts with `[INACTIVE]`.

## 2. Retrieve Deactivation Details

For each inactive entry, call `get_entry` with `allow_inactive=true` to retrieve the notes field.
Parse the deactivation timestamp from the notes (look for `[DEACTIVATED: <ISO timestamp>]`).

**IMPORTANT**: Do NOT display the password field. Only use get_entry to extract the notes.

## 3. Present Results

Display a table:

| Group | Original Title | Deactivated On |
|-------|---------------|----------------|
| ... | ... (title without [INACTIVE] prefix) | ISO timestamp or "unknown" |

## 4. Guidance

After the table, remind the user:
"To permanently remove these entries, delete them in the KeePassXC GUI. This plugin does not support entry deletion as a safety measure."
