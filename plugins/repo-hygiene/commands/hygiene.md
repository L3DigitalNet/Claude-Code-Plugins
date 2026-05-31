---
description: Autonomous maintenance sweep: validates .gitignore patterns, manifest paths, plugin state consistency, stale uncommitted changes. Dispatches hygiene-semantic-auditor (Haiku) for README freshness and docs/ accuracy.
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, Agent
---

# /hygiene [--dry-run]

Autonomous maintenance sweep for any git repository.

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

Detect the repository type to determine which checks apply:
```bash
test -f "$REPO_ROOT/.claude-plugin/marketplace.json" && echo "true" || echo "false"
```
Store the output as `IS_CLAUDE_PLUGIN_REPO`. When `true`, the repo is a Claude Code plugin marketplace — run all checks including Steps 2a–2c. When `false`, skip Step 2 entirely and run only the universal checks (gitignore, stale-commits, orphans, manifests Source B).

## Step 1: Run Mechanical Scans (parallel)

Run all seven scripts using the Bash tool. Execute them in parallel (make all seven Bash tool calls in a single response turn):

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
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-readme-structure.sh
```
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-readme-placeholders.sh
```
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-readme-refs.sh
```

Parse each result as JSON. If any script exits non-zero, surface the error immediately and stop — do not attempt to continue with partial results.

Collect all `findings` arrays. Tag each finding with its `check` field value.

After collecting, emit: `Step 1 complete: N finding(s) from 7 scripts.` (where N is the total count across all seven scripts)

## Step 2: Semantic README and Docs Scan (subagent)

**If `IS_CLAUDE_PLUGIN_REPO` is `false`**: skip this step entirely. Collect zero findings for Check 3 and proceed to Step 3. The semantic checks reference `plugins/`, `docs/plugin-readme-template.md`, and `.claude-plugin/marketplace.json` — structures that only exist in Claude Code plugin marketplace repos.

**If `IS_CLAUDE_PLUGIN_REPO` is `true`**: dispatch the `hygiene-semantic-auditor` subagent (Haiku). The agent performs the full leaf-to-root scan (plugin READMEs → root README → docs/) and returns a JSON findings array in the same schema as the Step 1 scripts.

Use the `Agent` tool with `subagent_type: hygiene-semantic-auditor` and a prompt like:

> Audit the repo at `$REPO_ROOT`. Run steps 2a/2b/2c per your task spec and return the JSON findings array. Read-only — do not Edit any file.

Parse the returned JSON. Extract the `findings` array and merge into the unified findings list from Step 1. If the agent returns an `error` field (e.g. marketplace.json missing), surface it and continue with Step 1 findings only.

Why a subagent: step 2 reads every plugin README (~500 lines each), the root README, and every docs/ file, plus the marketplace.json and template — a read-heavy pass that added ~15K tokens per run to the Opus context. Haiku handles the pattern-matching cleanly and returns only the structured findings. The deterministic README checks (placeholders, structural headings, literal path/link/command refs) stay in the Step 1 scripts; the subagent only does what those scripts cannot.

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
- If N > 4: use a hybrid approach:
  - **`stale-commits` and `orphans` (destructive)**: always show per-item options regardless of N — staging the wrong file or deleting the wrong directory is consequential and irreversible
  - **`readme-freshness` and `docs-accuracy` (review-only)**: collapse to category options: "All README freshness findings — open for review (N items)" / "All docs/ accuracy findings — open for review (N items)"
  - **`gitignore` (edit)**: collapse to "All gitignore stale patterns (N items)" when more than 4
  - Always include "None — defer all" as the last option

**If DRY_RUN is true:** Skip the AskUserQuestion. Display the full grouped findings list (same format as live mode — all items with their check type and detail) but without the approval prompt. Use the same header: `[DRY RUN] Would present N items for approval:` followed by the grouped list.

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

**`gitignore` (stale patterns):** Use the Edit tool to remove the specific line from the .gitignore file. The Step 5 multi-select is the single approval gate — do not ask again here.

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
If any staged files are present, do NOT auto-commit them. Warn the user BEFORE beginning any push or commit operations:
```
⚠ N staged file(s) from stale-commits approvals need a manual commit — commit these with your own message before continuing.
  • <filepath>
```
Then use `AskUserQuestion` to ask whether to continue pushing or stop so the user can commit first. If the user chooses to stop, skip the rest of Step 8.

**Unstaged changes (from auto-fixes and approved gitignore edits):**
If any modified-but-unstaged files exist, stage and commit them:

```bash
git add -A
git commit -m "$(cat <<'EOF'
fix(hygiene): apply auto-fixes from /hygiene sweep

Co-Authored-By: Claude Code <noreply@anthropic.com>
EOF
)"
```

If there were no unstaged changes (only staged stale-commits files), skip the commit — don't create an empty commit.

**Push and deploy:**

Get the current branch and detect the remote default branch:
```bash
git branch --show-current
git remote show origin 2>/dev/null | grep 'HEAD branch' | sed 's/.*: //'
```
Store the outputs as `CURRENT_BRANCH` and `DEFAULT_BRANCH` (fall back to `main` if detection fails or there is no remote).

Push the current branch:
```bash
git push origin <current-branch>
```

If `CURRENT_BRANCH` differs from `DEFAULT_BRANCH`, use **AskUserQuestion** to confirm the deploy step before proceeding:
- question: `"Deploy hygiene changes: merge <current-branch> into <default-branch> and push?"`
- header: `"Deploy"`
- options:
  1. label: `"Yes, deploy"`, description: `"Merge and push to <default-branch>"`
  2. label: `"No, skip deploy"`, description: `"Keep changes on <current-branch> only"`

If `"No, skip deploy"` is chosen, skip the merge and report: `"Changes pushed to <current-branch>. Deploy to <default-branch> skipped."`

If `"Yes, deploy"`, merge to the default branch and push:
```bash
git checkout <default-branch> && git pull origin <default-branch> && git merge <current-branch> --no-ff -m "Deploy: hygiene sweep fixes" && git push origin <default-branch> && git checkout <current-branch>
```

If `CURRENT_BRANCH` equals `DEFAULT_BRANCH` (already on the default branch), skip the merge step — the push above is sufficient.

Report (use the actual detected branch name, not a hardcoded string):
```
🚀 Pushed <current-branch> and merged to <default-branch>.
```
or if already on the default branch:
```
🚀 Pushed <current-branch>.
```

If any git command fails, surface the error and stop — do not continue with the deploy.
