---
description: Autonomous maintenance sweep — validates .gitignore patterns, manifest paths, plugin state consistency, stale uncommitted changes, README freshness (leaf-to-root with implementation cross-reference), and docs/ accuracy.
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

Establish repo root as working directory for all subsequent bash commands:
```bash
git rev-parse --show-toplevel
```
Store the output as `REPO_ROOT`. All bash commands in subsequent steps must be run from `REPO_ROOT`.

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

## Step 2: Semantic README and Docs Scan (Check 3 — inline)

Perform this scan in **leaf-to-root order**: process plugin READMEs first (2a), then the root README.md (2b), then docs/ files (2c). This ordering ensures child artifacts are verified before the parent documents that reference them.

### Step 2a: Plugin READMEs (leaf level)

For each plugin directory under `plugins/` that has a `README.md`, in alphabetical order, read the README and all implementation files in the plugin directory, then apply the following checks:

1. **Template placeholder detection** — Check for any text that appears to be unmodified from `docs/plugin-readme-template.md`, such as literal strings: `One-sentence description`, `Feature one`, `Feature two`, `Issue title`, `/command-name`, `skill-name`, `agent-name`, `Principle Name`, `Step one`, `Step two`, `Step three`. For each placeholder found:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "plugins/<name>/README.md"`, `detail: "Contains unmodified template placeholder: '<placeholder text>' — replace with actual content (see docs/plugin-readme-template.md)"`, `auto_fix: false`, `fix_cmd: null`

2. **Structural conformance** — Check that all required sections from `docs/plugin-readme-template.md` are present. Required headings (any level): `Summary`, `Principles`, `Requirements`, `Installation`, `How It Works`, `Usage`, `Planned Features`, `Known Issues`, `Links`. For each missing required section, add a finding:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "plugins/<name>/README.md"`, `detail: "Missing required section '<section name>' (see docs/plugin-readme-template.md)"`, `auto_fix: false`, `fix_cmd: null`

3. **Implementation cross-reference** — For each component type declared in the README, verify the corresponding file or directory exists on disk. Extract entries from table rows using backtick-delimited identifiers:

   - **Commands table** (`## Commands` section): for each `` `/command-name` `` entry, strip the leading `/` and check that `plugins/<name>/commands/command-name.md` or `plugins/<name>/commands/command-name/` exists.
   - **Skills table** (`## Skills` section): for each `` `skill-name` `` entry, check that `plugins/<name>/skills/skill-name/SKILL.md` or `plugins/<name>/skills/skill-name.md` exists.
   - **Agents table** (`## Agents` section): for each `` `agent-name` `` entry, check that `plugins/<name>/agents/agent-name.md` or `plugins/<name>/agents/agent-name/` exists.
   - **Hooks table** (`## Hooks` section): for each `` `script-name.sh` `` entry, check that the script exists at `plugins/<name>/hooks/script-name.sh` or `plugins/<name>/scripts/script-name.sh`. Also verify that `plugins/<name>/hooks/hooks.json` exists whenever any hook scripts are listed.
   - **Tools table** (`## Tools` section): presence of a Tools section implies an MCP server — check that `plugins/<name>/.mcp.json` exists.

   For each declared entry whose corresponding file does not exist:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "plugins/<name>/README.md"`, `detail: "README declares <type> '<identifier>' but <expected_path> not found on disk"`, `auto_fix: false`, `fix_cmd: null`

4. **Known Issues staleness** — Extract the `Known Issues` section. For each bullet item, scan the plugin's actual implementation files (scripts, hooks, commands) for evidence the issue has been fixed. If the codebase evidence clearly suggests the issue is no longer present, add a finding:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "plugins/<name>/README.md"`, `detail: "Known Issue '<first 80 chars>' may be stale — implementation evidence suggests it is resolved"`, `auto_fix: false`, `fix_cmd: null`

5. **Principles vs. codebase** — Extract the `Principles` or `Design Principles` section. For each principle, check if it is obviously contradicted by the current codebase (e.g., "no external network calls" but the plugin makes HTTP requests; "single-file command" but there are agents/ and scripts/). Only flag clear contradictions, not minor drift. Add findings with the same format as above.

### Step 2b: Root README.md (root level)

Read `README.md` at the repo root.

1. **Plugin coverage** — For each plugin listed in `.claude-plugin/marketplace.json`, check that the plugin `name` appears somewhere in the root README. For each missing plugin reference:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "README.md"`, `detail: "Root README.md does not mention plugin '<name>' — add it to the plugin list or table"`, `auto_fix: false`, `fix_cmd: null`

2. **Plugin list present** — If the root README contains no plugin list, table, or section that inventories available plugins, add a finding:
   - `check: "readme-freshness"`, `severity: "warn"`, `path: "README.md"`, `detail: "Root README.md has no plugin inventory table or list — add a summary of available plugins"`, `auto_fix: false`, `fix_cmd: null`

### Step 2c: docs/ accuracy check

For each Markdown file in `docs/` (skip `docs/plans/` entirely):

1. Read the file.

2. **Broken path references** — Extract all of the following reference patterns:
   - Fenced code block content that contains repo-relative paths starting with `plugins/`, `scripts/`, `docs/`, or `.claude-plugin/`
   - Inline code spans containing `.sh`, `.md`, `.json`, or `.ts` file references that include a `/`
   - Markdown link targets that are relative paths (not starting with `http`)

   For each extracted path, check whether it exists in the repo relative to `REPO_ROOT`. For each that does not exist:
   - `check: "docs-accuracy"`, `severity: "warn"`, `path: "docs/<filename>"`, `detail: "References '<path>' which does not exist on disk — may be stale or renamed"`, `auto_fix: false`, `fix_cmd: null`

3. **Plugin name references** — Scan for bare plugin directory names that appear to reference plugin directories (e.g., `plugin-test-harness`, `repo-hygiene`, `linux-sysadmin-mcp`). Check that each referenced plugin still exists as a directory under `plugins/`. For any removed plugin references:
   - `check: "docs-accuracy"`, `severity: "warn"`, `path: "docs/<filename>"`, `detail: "References plugin '<name>' which does not exist under plugins/ — may be removed or renamed"`, `auto_fix: false`, `fix_cmd: null`

Add all findings from Steps 2a, 2b, and 2c to the unified findings list.

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

[docs-accuracy]
  6. <path> — <detail>
```

Then use `AskUserQuestion` with multi-select to let the user choose actions:
- If N ≤ 4: show each item as an individual option (label: item number + path truncated to 40 chars)
- If N > 4: show these category options (only include categories that have findings):
  - "All orphaned temp dirs (N items)"
  - "All gitignore stale patterns (N items)"
  - "All stale commit files — stage only (N items)"
  - "All README freshness findings — open for review (N items)"
  - "All docs/ accuracy findings — open for review (N items)"
  - "None — defer all"

**If DRY_RUN is true:** Skip the AskUserQuestion. Display `[DRY RUN] Would present N items for approval`.

## Step 6: Apply Approved Fixes

For each approved item, apply based on check type:

**`orphans` (temp directories):** Extract the full absolute path from the `detail` field (it contains the complete path after "delete: ").

SAFETY CHECK: Verify the path satisfies ALL of:
1. Starts with the user's home directory + `/.claude/plugins/cache/temp_` as a complete prefix (not just a substring)
2. Does not contain `..` (no path traversal)
3. The basename starts with `temp_`

If ALL checks pass:
```bash
rm -rf "<full_path_from_detail>"
```
Report: `🗑 Deleted: <path>`

If ANY check fails: refuse the deletion and report the specific check that failed.

**`stale-commits` (uncommitted files):** Stage the file:
```bash
git add <filepath>
```
Report: `📦 Staged: <filepath>` — remind the user to commit with their own message.

**`readme-freshness` (stale documentation):** Read the flagged section of the README aloud (display it in the response). Do NOT automatically edit the file — present it for the user to review. Report: `📖 Displayed for review: <path>`

**`docs-accuracy` (stale docs/ reference):** Read the surrounding context of the flagged reference from the docs file (display ±5 lines around it). Do NOT automatically edit the file — present it for the user to review. Report: `📖 Displayed for review: <path>`

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

## Step 8: Commit and Push to Remote

**If DRY_RUN is true:** Skip this step entirely.

**If no files were modified or staged during the sweep:** Skip this step — nothing to push.

Otherwise, check git state:

```bash
git status --porcelain
```

**Staged files (from stale-commits approvals):**
If any staged files are present, do NOT auto-commit them. Display:
```
⚠ N staged file(s) from stale-commits approvals — commit these yourself with your own message before or after this push:
  • <filepath>
```

**Unstaged changes (from auto-fixes and approved gitignore edits):**
If any modified-but-unstaged files exist, stage and commit them:

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix(hygiene): apply auto-fixes from /hygiene sweep

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

If there were no unstaged changes (only staged stale-commits files), skip the commit — don't create an empty commit.

**Push and deploy:**

Get the current branch:
```bash
git branch --show-current
```

Push the current branch:
```bash
git push origin <current-branch>
```

Then merge to `main` and push:
```bash
git checkout main && git pull origin main && git merge <current-branch> --no-ff -m "Deploy: hygiene sweep fixes" && git push origin main && git checkout <current-branch>
```

Report:
```
🚀 Pushed <current-branch> and merged to main.
```

If any git command fails, surface the error and stop — do not continue with the deploy.
