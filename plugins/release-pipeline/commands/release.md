---
name: release
description: "Release pipeline — interactive menu for quick merge, full release, plugin release, status, dry run, or changelog preview."
---

# Release Pipeline

You are the release orchestrator. When invoked, first gather context about the current repository, then present an interactive menu tailored to that context.

## CRITICAL RULES

1. **Use TodoWrite** to track every step of the pipeline. Update status as you go.
2. **If ANY step fails, STOP IMMEDIATELY.** Report what failed, suggest the appropriate rollback command from the Rollback section, and do NOT continue.
3. **Never force-push.** Do not use `git push --force` or `git push -f` under any circumstances.
4. **Verify noreply email before push.** Run `git config user.email` and confirm it matches `*@users.noreply.github.com`. If it does not, STOP and tell the user.
5. **Wait for explicit "GO" approval** before executing release operations (merge, tag, push). Present a summary and pause.

---

## Phase 0: Context Detection

Before showing the menu, run these commands to gather context. Execute them in parallel where possible (all are read-only).

**Step 1 — Monorepo check:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-unreleased.sh .
```

Capture result:
- Exit code 0 with output → `is_monorepo = true`, parse TSV output into `unreleased_plugins` list
- Exit code 0 with "No plugins with unreleased changes" on stderr → `is_monorepo = true`, `unreleased_plugins = []`
- Exit code 1 → `is_monorepo = false`

**Step 2 — Git state:**

```bash
git status --porcelain
git branch --show-current
git log --oneline -1
```

Capture: `is_dirty` (status output non-empty), `current_branch`, `last_commit_summary`.

**Step 3 — Version suggestion:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-version.sh .
```

Capture output: `suggested_version` (first field), `feat_count`, `fix_count`, `other_count` (remaining fields).

If the script exits 1 (no previous tag), set `suggested_version = "0.1.0"` and counts to 0.

**Step 4 — Last tag:**

```bash
git describe --tags --abbrev=0 2>/dev/null || echo "(none)"
```

Capture: `last_tag`.

**Step 5 — Commit count since last tag:**

If `last_tag` is not "(none)":
```bash
git log <last_tag>..HEAD --oneline | wc -l
```
Capture: `commit_count`.

If `last_tag` is "(none)", set `commit_count` to total commit count.

---

## Menu Presentation

Use **AskUserQuestion** to present the release menu. Build the options dynamically from context:

**Always include these options:**

1. **Quick Merge**
   - label: `"Quick Merge"`
   - description: If `is_dirty`: `"Stage, commit, and merge testing → main (⚠ uncommitted changes will be staged)"`
   - description: If clean: `"Merge testing → main — <commit_count> commits since <last_tag>"`

2. **Full Release**
   - label: `"Full Release"`
   - description: `"Semver release with pre-flight checks, changelog, tag, and GitHub release (suggested: v<suggested_version> — <feat_count> feat, <fix_count> fix)"`

3. **Release Status**
   - label: `"Release Status"`
   - description: `"Show unreleased commits, last tag, changelog drift (last tag: <last_tag>, <commit_count> commits since)"`

4. **Dry Run**
   - label: `"Dry Run"`
   - description: `"Simulate a full release without committing, tagging, or pushing"`

5. **Changelog Preview**
   - label: `"Changelog Preview"`
   - description: `"Generate and display changelog entry without committing"`

**Conditionally include (monorepo only — when `is_monorepo` is true):**

6. **Plugin Release**
   - label: `"Plugin Release"`
   - description: `"Release a single plugin with scoped tag and changelog (<N> plugins with unreleased changes)"` where N is `len(unreleased_plugins)`
   - If `unreleased_plugins` is empty: `"Release a single plugin with scoped tag and changelog (all plugins up to date)"`

Before calling `AskUserQuestion`, output one context line:

```
Branch: <current_branch>  |  Last tag: <last_tag>  |  <commit_count> commits since last tag
```

**Question text:** `"What would you like to do?"`
**Header:** `"Release"`

After the user selects, route to the corresponding mode below.

---

## Mode 1: Quick Merge (no version)

Merges `testing` into `main` and pushes. No version bumps.

### Step 1 — Pre-flight

Run these checks sequentially:

```bash
# Check for uncommitted changes
git status --porcelain
```

```bash
# Verify not on main
git branch --show-current
```

```bash
# Verify noreply email
git config user.email
```

If on `main` or email is not noreply: STOP and report the issue.

### Step 2 — Stage and Commit (only if uncommitted changes exist)

If `git status --porcelain` returned output:

1. Stage all changes: `git add -A`
2. Generate a commit message from `git diff --cached --stat` (summarize the changes)
3. Show the user the `git diff --cached --stat` output and the proposed commit message
4. Use **AskUserQuestion**:
   - question: `"Stage and commit these changes?"`
   - header: `"Commit"`
   - options:
     1. label: `"Proceed"`, description: `"Commit all staged changes with the message above"`
     2. label: `"Abort"`, description: `"Cancel — do not stage or commit anything"`
   If "Abort" → report "Quick merge aborted." and stop.
5. Commit with the generated message.

If the working tree is clean, skip directly to Step 3.

### Step 3 — Merge and Push

Show the user a summary of what will happen: commit count on testing ahead of main, files changed.

Use **AskUserQuestion**:
- question: `"Merge testing into main and push?"`
- header: `"Merge"`
- options:
  1. label: `"Proceed"`, description: `"Merge testing → main and push to origin"`
  2. label: `"Abort"`, description: `"Cancel — no changes will be made"`
If "Abort" → report "Quick merge aborted." and stop.

```bash
git checkout main
git pull origin main
git merge testing --no-ff -m "Merge testing into main"
git push origin main
git checkout testing
```

### Step 4 — Report

Display:
- Number of commits merged
- Files changed (`git diff --stat HEAD~1` on main before switching back)
- Confirm current branch is `testing`

---

## Mode 2: Full Release

Full semver release with parallel pre-flight checks, version bumps, changelog, git tag, and GitHub release.

### Step 0 — Version Selection

Present the auto-suggested version to the user:

Use **AskUserQuestion**:
- question: `"Which version should this release be?"`
- header: `"Version"`
- options:
  1. label: `"v<suggested_version> (Recommended)"`, description: `"Based on commits: <feat_count> feat, <fix_count> fix, <other_count> other since <last_tag>"`
  2. label: `"Custom version"`, description: `"Enter a specific version number"`

If "Custom version" selected, ask: `"Enter the version (e.g., 1.2.0 or v1.2.0):"`

Normalize the version to `X.Y.Z` without leading `v` for scripts. Use `vX.Y.Z` for tags and display.

### Phase 1 — Pre-flight (Parallel)

**IMPORTANT:** Before making any tool calls, output this line: `"Launching pre-flight checks for v<version> in parallel..."`

Then launch THREE Task agents simultaneously **in a single message** (all three tool calls in one response):

**Agent A — Test Runner:**
```
subagent_type: "general-purpose"
description: "Run test suite for release pre-flight"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/test-runner.md and follow them exactly.
  Run the full test suite for the repository at the current working directory.
  Report results in the format specified in those instructions.
```

**Agent B — Docs Auditor:**
```
subagent_type: "general-purpose"
description: "Audit documentation for release readiness"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/docs-auditor.md and follow them exactly.
  Audit documentation in the current repository.
  The target release version is <version>.
  Report results in the format specified in those instructions.
```

**Agent C — Git Pre-flight:**
```
subagent_type: "general-purpose"
description: "Git pre-flight check"
model: haiku
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/git-preflight.md and follow them exactly.
  Check git state for the current repository.
  The target tag is v<version>.
  Report results in the format specified in those instructions.
```

**After all three return:**

Display each agent's summary in a consolidated pre-flight report. Use ✓ for PASS, ⚠ for WARN, and ✗ for FAIL:

```
PRE-FLIGHT RESULTS
==================
<✓|✗> Tests:  PASS|FAIL  — <one-line summary>
<✓|⚠|✗> Docs: PASS|WARN|FAIL  — <one-line summary>
<✓|✗> Git:   PASS|FAIL  — <one-line summary>
```

- If **ANY agent reports FAIL** → STOP. Display the failure details and suggest: "Fix the issues above and re-run `/release`."
- If **all PASS or WARN** → proceed to Phase 2.

### Phase 2 — Preparation (Sequential)

**Step 1 — Bump versions:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version>
```

**Step 2 — Generate changelog:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version>
```

**Step 3 — Show diff summary:**

```bash
git diff --stat
```

Display: version file changes, changelog preview (first 30 lines of the generated entry), and any other modified files.

**Step 4 — Approval gate:**

Use **AskUserQuestion**:
- question: `"Proceed with the v<version> release?"`
- header: `"Release"`
- options:
  1. label: `"Proceed"`, description: `"Commit, tag, merge to main, and push"`
  2. label: `"Abort"`, description: `"Cancel — revert all changes (git checkout -- .)"`
If "Abort" → run `git checkout -- .` and report "Release aborted. All changes reverted." and stop.

### Phase 3 — Release (Sequential)

Execute each command sequentially. If any command fails, STOP and report with rollback suggestion.

```bash
git add -A
git commit -m "Release v<version>"
```

```bash
git checkout main
git pull origin main
git merge testing --no-ff -m "Release v<version>"
```

```bash
git tag -a "v<version>" -m "Release v<version>"
```

```bash
git push origin main --tags
```

```bash
git checkout testing
```

Then create the GitHub release. Use the changelog entry generated in Phase 2 as the release notes:

```bash
gh release create "v<version>" --title "v<version>" --notes "<changelog entry>"
```

### Phase 4 — Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version>
```

Display the verification report. If verification fails → WARN the user but do NOT attempt automatic rollback (the release is already public).

### Final Summary

Display a completion report:

```
RELEASE COMPLETE: v<version>
============================
Tests:     ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Docs:      ✓ PASS | ⚠ WARN | ✗ FAIL — <one-line summary from Phase 1>
Git:       ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Version:   <files bumped>
Changelog: updated
Tag:       v<version>
GitHub:    <release URL>
Branch:    <current branch>
```

Get the release URL with:

```bash
gh release view "v<version>" --json url -q '.url'
```

---

## Mode 3: Plugin Release (monorepo per-plugin)

Scoped release for a single plugin. Uses scoped tags, scoped changelog, and only stages plugin files.

### Step 0 — Plugin Selection

Use **AskUserQuestion** to present the plugin picker:

- question: `"Which plugin are you releasing?"`
- header: `"Plugin"`
- options: Build from `unreleased_plugins` list. For each plugin:
  - label: `"<plugin-name>"`
  - description: `"v<current-version> → <commit-count> commits since <last-tag>"`

If `unreleased_plugins` is empty, show all plugins from marketplace.json instead with description: `"v<current-version> (no unreleased changes detected)"`.

### Step 1 — Version Selection

Run suggest-version.sh scoped to the selected plugin:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-version.sh . --plugin <plugin-name>
```

Also read `plugins/<plugin-name>/.claude-plugin/plugin.json` to get `current_version`.

Build options for **AskUserQuestion**:
- If `suggested_version != current_version` AND `current_version` is semver-greater: use `current_version` as option 1 (Recommended) and `suggested_version` as option 2.
- Otherwise: use `suggested_version` as option 1 (Recommended).
- Always include `"Custom version"` as the last option.

Use **AskUserQuestion**:
- question: `"Which version for <plugin-name>?"`
- header: `"Version"`
- options (up to 3):
  1. label: `"v<recommended_version> (Recommended)"`, description: `"<context>: <feat_count> feat, <fix_count> fix, <other_count> other"` where context is "Based on commits" or "Current plugin.json version" as appropriate
  2. *(only if both versions differ)* label: `"v<other_version>"`, description: `"Alternative: commit-based suggestion"` or `"Alternative: current plugin.json version"` as appropriate
  3. label: `"Custom version"`, description: `"Enter a specific version number"`

If "Custom version" selected, ask the user to enter it.

Normalize the version to `X.Y.Z` without leading `v` for scripts. Use `<plugin-name>/vX.Y.Z` for tags and `vX.Y.Z` for display.

### Phase 1 — Scoped Pre-flight (Parallel)

**IMPORTANT:** Before making any tool calls, output this line: `"Launching pre-flight checks for <plugin-name> v<version> in parallel..."`

Then launch THREE Task agents simultaneously **in a single message** (all three tool calls in one response):

**Agent A — Test Runner (scoped):**
```
subagent_type: "general-purpose"
description: "Run test suite for plugin release pre-flight"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/test-runner.md and follow them exactly.
  SCOPE: Only run tests for the plugin at plugins/<plugin-name>/.
  Look for tests in these locations (in order):
  1. plugins/<plugin-name>/tests/
  2. plugins/<plugin-name>/test/
  3. If no plugin-specific tests exist, fall back to repo-level test detection.
  Report results in the format specified in those instructions.
```

**Agent B — Docs Auditor (scoped):**
```
subagent_type: "general-purpose"
description: "Audit plugin documentation for release readiness"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/docs-auditor.md and follow them exactly.
  SCOPE: Only audit documentation in plugins/<plugin-name>/ (README.md, docs/).
  Also check the plugin entry in .claude-plugin/marketplace.json for version consistency.
  The target release version is <version>.
  Report results in the format specified in those instructions.
```

**Agent C — Git Pre-flight (scoped):**
```
subagent_type: "general-purpose"
description: "Git pre-flight check for plugin release"
model: haiku
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/git-preflight.md and follow them exactly.
  Check git state for the current repository.
  The target tag is <plugin-name>/v<version> (note: plugin-scoped tag, NOT v<version>).
  Report results in the format specified in those instructions.
```

**After all three return:**

Display consolidated pre-flight report (same format as Mode 2). If ANY FAIL → STOP.

### Phase 2 — Scoped Preparation (Sequential)

**Step 1 — Bump versions (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --plugin <plugin-name>
```

This bumps `plugins/<plugin-name>/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json`.

**Step 2 — Generate changelog (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name>
```

This collects only commits touching `plugins/<plugin-name>/` since the last `<plugin-name>/v*` tag and writes to `plugins/<plugin-name>/CHANGELOG.md`.

**Step 3 — Show diff summary:**

```bash
git diff --stat
```

Display: version changes, changelog preview (first 30 lines), marketplace.json change.

**Step 4 — Approval gate:**

Use **AskUserQuestion**:
- question: `"Proceed with the <plugin-name> v<version> release?"`
- header: `"Release"`
- options:
  1. label: `"Proceed"`, description: `"Commit, tag, merge to main, and push"`
  2. label: `"Abort"`, description: `"Cancel — revert all changes (git checkout -- .)"`
If "Abort" → run `git checkout -- .` and report "Release aborted. All changes reverted." and stop.

### Phase 3 — Scoped Release (Sequential)

Execute each command sequentially. If any command fails, STOP and report with rollback suggestion.

```bash
git add plugins/<plugin-name>/ .claude-plugin/marketplace.json
git commit -m "Release <plugin-name> v<version>"
```

```bash
git checkout main
git pull origin main
git merge testing --no-ff -m "Release <plugin-name> v<version>"
```

```bash
git tag -a "<plugin-name>/v<version>" -m "Release <plugin-name> v<version>"
```

```bash
git push origin main --tags
```

```bash
git checkout testing
```

```bash
gh release create "<plugin-name>/v<version>" --title "<plugin-name> v<version>" --notes "<changelog entry>"
```

### Phase 4 — Scoped Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version> --plugin <plugin-name>
```

### Final Summary

```
RELEASE COMPLETE: <plugin-name> v<version>
==========================================
Tests:     ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Docs:      ✓ PASS | ⚠ WARN | ✗ FAIL — <one-line summary from Phase 1>
Git:       ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Version:   plugins/<plugin-name>/.claude-plugin/plugin.json, marketplace.json
Changelog: plugins/<plugin-name>/CHANGELOG.md
Tag:       <plugin-name>/v<version>
GitHub:    <release URL>
Branch:    <current branch>
```

Get the release URL with:

```bash
gh release view "<plugin-name>/v<version>" --json url -q '.url'
```

---

## Mode 4: Release Status (read-only)

Shows the current release state without making any changes.

### Step 1 — Repository Overview

Display:

```
RELEASE STATUS
==============
Branch:     <current_branch>
Last tag:   <last_tag>
Commits:    <commit_count> since <last_tag>
Suggested:  v<suggested_version> (<feat_count> feat, <fix_count> fix, <other_count> other)
Tree:       clean | dirty (<N> uncommitted files)
```

### Step 2 — Commit Breakdown

List commits since last tag, categorized:

```bash
git log <last_tag>..HEAD --oneline --no-merges
```

Display them grouped by conventional commit type (feat, fix, chore, docs, etc.). If there are more than 15 commits, show 15 and add: `…and <N> more commits`.

### Step 3 — Monorepo Breakdown (if applicable)

If `is_monorepo` is true, show per-plugin status from the `unreleased_plugins` list:

```
PLUGIN STATUS
=============
  home-assistant-dev   v2.1.0   3 commits since home-assistant-dev/v2.1.0
  release-pipeline     v1.3.0   8 commits since release-pipeline/v1.3.0
  linux-sysadmin-mcp   v1.0.0   (up to date)
```

### Step 4 — Changelog Drift Check

Check if CHANGELOG.md exists. If it does, compare the latest version header in CHANGELOG.md against `last_tag`:

```bash
head -20 CHANGELOG.md
```

If the latest `## [X.Y.Z]` in CHANGELOG.md matches the last tag version → "Changelog is up to date."
If it doesn't → "⚠ Changelog may be out of date — last entry is vA.B.C but last tag is vX.Y.Z."

### Done

No further action. Display: "Status check complete. Use `/release` to start a release."

---

## Mode 5: Dry Run

Simulates a Full Release without committing, tagging, or pushing. All changes are reverted at the end.

**First, output this banner:**

```
⚠ DRY RUN — no changes will be committed, tagged, or pushed
  File modifications will be made temporarily and reverted at the end.
```

### Step 0 — Version Selection

Same as Mode 2 Step 0 — present auto-suggested version via AskUserQuestion. If monorepo, first ask if this is a repo-wide or plugin dry run using AskUserQuestion, then scope accordingly.

### Phase 1 — Pre-flight (Parallel)

**IMPORTANT:** Before making any tool calls, output this line: `"Launching pre-flight checks for v<version> in parallel (dry run)..."`

Same as Mode 2 Phase 1 — launch all three agents. Display consolidated report.

If ANY agent reports FAIL → report the failures. Do NOT stop here (this is a dry run — show what would fail).

### Phase 2 — Simulated Preparation

**Step 1 — Bump versions:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version>
```

(For plugin dry run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --plugin <plugin-name>`)

**Step 2 — Generate changelog:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version>
```

(For plugin dry run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name>`)

**Step 3 — Show what WOULD happen:**

```bash
git diff --stat
```

Display:
- Files that would be committed
- The changelog entry that would be added
- Tag that would be created: `v<version>` (or `<plugin-name>/v<version>`)
- GitHub release that would be created

### Phase 3 — Revert

```bash
git checkout -- .
```

Display: **"Dry run complete. No changes were made to the repository."**

If pre-flight had failures, remind: "⚠ Pre-flight issues were detected — see above. Fix them before a real release."

---

## Mode 6: Changelog Preview

Generates and displays a changelog entry without modifying any files (unless the user opts in).

### Step 1 — Version Selection

Same as Mode 2 Step 0 — present auto-suggested version via AskUserQuestion.

For monorepo: first ask if this is repo-wide or per-plugin using AskUserQuestion. If per-plugin, use suggest-version.sh with --plugin flag.

### Step 2 — Generate Preview

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --preview
```

(For plugin: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name> --preview`)

Display the full formatted changelog entry.

### Step 3 — Save Option

Use **AskUserQuestion**:
- question: `"Save this changelog entry to CHANGELOG.md?"`
- header: `"Save"`
- options:
  1. label: `"Yes, save it"`, description: `"Write the entry to CHANGELOG.md and stage the file"`
  2. label: `"No, discard"`, description: `"Don't save — this was just a preview"`

If "Yes":
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version>
git add CHANGELOG.md
```
(For plugin: add `--plugin <plugin-name>` and stage `plugins/<plugin-name>/CHANGELOG.md`)

Display: "Changelog entry saved and staged."

If "No":
Display: "Preview discarded. No changes made."

---

## Rollback Suggestions

If a failure occurs, identify which phase failed and show ONLY the corresponding row from this table — do not show the full table:

| Phase | What happened | Rollback command |
|-------|--------------|-----------------|
| Phase 0 (Detection) | Context gathering failed | Nothing to roll back. Check script paths and retry. |
| Phase 1 (Pre-flight) | Checks failed before any changes | Nothing to roll back. Fix the reported issues and retry. |
| Phase 2 (Preparation) | Version bump or changelog failed | `git checkout -- .` |
| Phase 3 (Before push) | Commit, merge, or tag failed locally | `git tag -d v<version> && git checkout testing && git reset HEAD~1` |
| Phase 3 (After push) | Push succeeded but something else failed | Manual intervention needed. To delete the remote tag: `git push origin --delete v<version>`. The merge to main may need a revert commit. |
| Phase 3 (Before push, plugin) | Scoped commit/merge/tag failed locally | `git tag -d <name>/v<version> && git checkout testing && git reset HEAD~1` |
| Phase 3 (After push, plugin) | Push succeeded but something else failed | Manual: `git push origin --delete <name>/v<version>`. May need revert commit. |
| Phase 4 (Verification) | Post-release checks failed | No automatic rollback. Verify manually what failed and address individually. |
