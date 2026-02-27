---
argument-hint: [title] [group]
description: Rotate a KeePass credential with safe deactivation of the old entry.
allowed-tools: mcp__keepass__create_entry, mcp__keepass__deactivate_entry, mcp__keepass__get_entry, mcp__keepass__list_entries
---

# KeePass Credential Rotation

## 1. Identify Target

If arguments were provided, use them as the title and group.
Otherwise, ask the user:
- Which credential to rotate? (title and group)

## 2. Collect New Values

Ask the user for the new credential values:
- Username (or keep existing)
- Password (new value)
- URL (or keep existing)
- Notes (or keep existing)

## 3. Create New Entry

Call `create_entry` with the new values using the **same title** (the old entry will be renamed).

**CRITICAL**: Confirm `create_entry` succeeded before proceeding. If it fails (e.g., DuplicateEntry because the old one still has the same title), deactivate the old entry first, then retry.

Alternative flow if title collision:
1. Call `deactivate_entry` on the old entry first
2. Call `create_entry` with the original title

## 4. Deactivate Old Entry

If the old entry was not already deactivated in step 3:
Call `deactivate_entry` on the old entry.
Confirm success.

## 5. Report

Report completion:
- New entry is active with the original title
- Old entry has been renamed with `[INACTIVE]` prefix and deactivation timestamp
- Remind the user: "Delete the [INACTIVE] entry manually in KeePassXC when ready."
