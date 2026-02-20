---
description: Autonomous maintenance sweep — validates .gitignore patterns, manifest paths, README freshness, plugin state consistency, and stale uncommitted changes.
---

# /hygiene [--dry-run]

Autonomous maintenance sweep for the Claude-Code-Plugins monorepo.

## Step 0: Setup

Parse the arguments for `--dry-run`. Store as a boolean `DRY_RUN`.

Get the plugin root:
```bash
echo $CLAUDE_PLUGIN_ROOT
```
Store the output as `PLUGIN_ROOT`.

## Step 1: Run Mechanical Scans (parallel)

Run all four scripts using the Bash tool. Execute them in parallel (make all four Bash tool calls in a single response turn):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-gitignore.sh
```
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-manifests.sh
```
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-orphans.sh
```
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-stale-commits.sh
```

Parse each result as JSON. If any script exits non-zero, surface the error immediately and stop — do not attempt to continue with partial results.

Collect all `findings` arrays. Tag each finding with its `check` field value.

## Step 2: Semantic README Scan (Check 3 — inline)

For each plugin directory under `plugins/` that has a `README.md`:

1. Read the README
2. Extract the `Known Issues` section (heading may be `## Known Issues`, `### Known Issues`, or similar). For each bullet item in that section, scan the plugin's actual implementation files (scripts, hooks, commands) for evidence the issue has been fixed. If the codebase evidence suggests the issue is no longer present, add a finding:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "plugins/<name>/README.md"`, `detail: "Known Issue '<first 80 chars>' may be stale — implementation evidence suggests it is resolved"`, `auto_fix: false`, `fix_cmd: null`
3. Extract the `Principles` or `Design Principles` section. For each principle listed, check if it is obviously contradicted by the current codebase (e.g., "no external network calls" but the plugin makes HTTP requests; "single-file command" but there are agents/ and scripts/). Only flag clear contradictions, not minor drift. Add findings with the same format as above.

Add all readme-freshness findings to the unified findings list.

## Step 3: Classify Findings

Partition the unified findings list:
- `auto_fixable`: findings where `auto_fix == true` and `fix_cmd` is not null
- `needs_approval`: findings where `severity == "warn"` and `auto_fix == false`
- `info_notes`: findings where `severity == "info"` (display as a compact list at the end, no approval needed)

## Step 4: Apply Auto-fixes

**If DRY_RUN is true:**
Display:
```
[DRY RUN] Would auto-fix N items:
  • <path> — <detail>
```
Do not run any commands.

**If DRY_RUN is false:**
For each `auto_fixable` finding, run its `fix_cmd` in a bash subshell:
```bash
bash -c "<fix_cmd>"
```
If a fix command fails, log the error and continue — don't abort the sweep.

After applying, display:
```
✅ Auto-fixed N items:
  • <path> — <detail>
```

## Step 5: Present Needs-Approval Items

If there are no `needs_approval` findings, display:
```
✅ No risky changes found. Sweep complete.
```
Then show the info notes and final summary (Step 7) and stop.

Otherwise, display all needs-approval findings grouped by check type, numbered:

```
⚠ N items need your approval:

[gitignore]
  1. <path> — <detail>

[orphans]
  2. <path> — <detail>
  3. <path> — <detail>

[stale-commits]
  4. <path> — <detail>

[readme-freshness]
  5. <path> — <detail>
```

Then use `AskUserQuestion` with multi-select to let the user choose actions:
- If N ≤ 4: show each item as an individual option (label: item number + path truncated to 40 chars)
- If N > 4: show these category options (only include categories that have findings):
  - "All orphaned temp dirs (N items)"
  - "All gitignore stale patterns (N items)"
  - "All stale commit files — stage only (N items)"
  - "All README freshness findings — open for review (N items)"
  - "None — defer all"

**If DRY_RUN is true:** Skip the AskUserQuestion. Display `[DRY RUN] Would present N items for approval`.

## Step 6: Apply Approved Fixes

For each approved item, apply based on check type:

**`orphans` (temp directories):** SAFETY CHECK FIRST — verify the path begins with the user's home directory and contains `plugins/cache/temp_`. If it passes:
```bash
rm -rf <full_path>
```
Report: `🗑 Deleted: <path>`

**`stale-commits` (uncommitted files):** Stage the file:
```bash
git add <filepath>
```
Report: `📦 Staged: <filepath>` — remind the user to commit with their own message.

**`readme-freshness` (stale documentation):** Read the flagged section of the README aloud (display it in the response). Do NOT automatically edit the file — present it for the user to review. Report: `📖 Displayed for review: <path>`

**`gitignore` (stale patterns):** For patterns flagged as needs-approval (stale, not auto-fixable), ask the user to confirm before removing. Use the Edit tool to remove the specific line from the .gitignore file.

## Step 7: Final Summary

Display:
```
───────────────────────────────────
Hygiene sweep complete.
  Auto-fixed:   N items
  Approved:     N items
  Deferred:     N items
  Info notes:   N items
───────────────────────────────────
```

If DRY_RUN was active, prefix the header with `[DRY RUN]`.
