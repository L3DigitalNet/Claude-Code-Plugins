# Unified /release Menu — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the `/release` command as an interactive, context-aware menu that auto-detects repo state and walks the user through the selected release workflow.

**Architecture:** Single command file rewrite (Approach A). The existing `commands/release.md` is replaced with a new version containing: context detection phase → AskUserQuestion menu → six mode workflows. Supporting changes: new `suggest-version.sh` script, `--preview` flag on `generate-changelog.sh`, simplified `release-detection` skill.

**Tech Stack:** Bash scripts, Claude Code plugin command markdown, AskUserQuestion tool

---

### Task 1: Create `suggest-version.sh` script

**Files:**
- Create: `plugins/release-pipeline/scripts/suggest-version.sh`

**Step 1: Write the script**

Create `plugins/release-pipeline/scripts/suggest-version.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# suggest-version.sh — Suggest a semver bump based on conventional commits.
#
# Usage: suggest-version.sh <repo-path> [--plugin <name>]
# Output: <suggested-version> <feat-count> <fix-count> <other-count>
#   e.g., "1.2.0 3 1 2"
# Exit:   0 = suggestion made, 1 = no previous tag or error

# ---------- Argument handling ----------

if [[ $# -lt 1 ]]; then
  echo "Usage: suggest-version.sh <repo-path> [--plugin <name>]" >&2
  exit 1
fi

REPO="$1"

# ---------- Optional --plugin flag ----------
PLUGIN=""
if [[ $# -ge 3 && "$2" == "--plugin" ]]; then
  PLUGIN="$3"
  if [[ "$PLUGIN" =~ [/\\] ]]; then
    echo "Error: plugin name must not contain path separators" >&2
    exit 1
  fi
fi

# Verify directory exists, then resolve to absolute path.
if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

# ---------- Find last tag ----------

last_tag=""
path_filter=""

if [[ -n "$PLUGIN" ]]; then
  last_tag=$(git -C "$REPO" tag -l "${PLUGIN}/v*" --sort=-v:refname | head -1) || true
  path_filter="plugins/${PLUGIN}/"
else
  if git -C "$REPO" describe --tags --abbrev=0 &>/dev/null; then
    last_tag="$(git -C "$REPO" describe --tags --abbrev=0)"
  fi
fi

# ---------- Parse current version from last tag ----------

if [[ -z "$last_tag" ]]; then
  # No previous tag — default to 0.1.0
  current_major=0
  current_minor=1
  current_patch=0
else
  # Extract version digits from tag (strip plugin prefix and 'v')
  tag_version="${last_tag##*/}"   # strip plugin-name/ prefix if present
  tag_version="${tag_version#v}"  # strip leading v
  IFS='.' read -r current_major current_minor current_patch <<< "$tag_version"
fi

# ---------- Collect commits since last tag ----------

if [[ -n "$last_tag" && -n "$path_filter" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges -- "$path_filter")"
elif [[ -n "$last_tag" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges)"
elif [[ -n "$path_filter" ]]; then
  commits="$(git -C "$REPO" log --oneline --no-merges -- "$path_filter")"
else
  commits="$(git -C "$REPO" log --oneline --no-merges)"
fi

if [[ -z "$commits" ]]; then
  echo "No commits since last tag." >&2
  exit 1
fi

# ---------- Categorize commits ----------

feat_count=0
fix_count=0
other_count=0
has_breaking=false

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  msg="${line#* }"

  # Check for breaking changes
  if [[ "$msg" =~ ^[a-z]+(\(.*\))?!: ]] || [[ "$msg" =~ BREAKING\ CHANGE ]]; then
    has_breaking=true
  fi

  if [[ "$msg" =~ ^feat(\(.*\))?\!?:  ]]; then
    feat_count=$((feat_count + 1))
  elif [[ "$msg" =~ ^fix(\(.*\))?\!?: ]]; then
    fix_count=$((fix_count + 1))
  else
    other_count=$((other_count + 1))
  fi
done <<< "$commits"

# ---------- Determine bump type ----------

if [[ "$has_breaking" == true ]]; then
  new_major=$((current_major + 1))
  new_version="${new_major}.0.0"
elif [[ "$feat_count" -gt 0 ]]; then
  new_minor=$((current_minor + 1))
  new_version="${current_major}.${new_minor}.0"
else
  new_patch=$((current_patch + 1))
  new_version="${current_major}.${current_minor}.${new_patch}"
fi

# ---------- Output ----------

printf '%s %s %s %s\n' "$new_version" "$feat_count" "$fix_count" "$other_count"

exit 0
```

**Step 2: Make the script executable and test it**

Run:
```bash
chmod +x plugins/release-pipeline/scripts/suggest-version.sh
bash plugins/release-pipeline/scripts/suggest-version.sh .
```

Expected: outputs something like `1.2.0 5 2 8` (a version and three counts).

Test plugin mode:
```bash
bash plugins/release-pipeline/scripts/suggest-version.sh . --plugin release-pipeline
```

Expected: outputs a version suggestion scoped to release-pipeline commits.

**Step 3: Commit**

```bash
git add plugins/release-pipeline/scripts/suggest-version.sh
git commit -m "feat(release-pipeline): add suggest-version.sh for auto semver suggestion"
```

---

### Task 2: Add `--preview` flag to `generate-changelog.sh`

**Files:**
- Modify: `plugins/release-pipeline/scripts/generate-changelog.sh:17-35` (argument handling)
- Modify: `plugins/release-pipeline/scripts/generate-changelog.sh:120-165` (output section)

**Step 1: Add PREVIEW flag parsing after the PLUGIN block**

In argument handling section (after the `--plugin` block at line 35), add parsing for `--preview`. The flag can appear in position 3 or 5 depending on whether `--plugin` was used.

Add after line 35:
```bash
# ---------- Optional --preview flag ----------
PREVIEW=false
for arg in "$@"; do
  if [[ "$arg" == "--preview" ]]; then
    PREVIEW=true
    break
  fi
done
```

**Step 2: Guard the file-write section with the preview flag**

Replace lines 120-165 (from `# ---------- Output to stdout ----------` through end) with:

```bash
# ---------- Output to stdout ----------

printf '%s' "$entry"

# ---------- Prepend to CHANGELOG.md (skip in preview mode) ----------

if [[ "$PREVIEW" == true ]]; then
  exit 0
fi

if [[ -n "$PLUGIN" ]]; then
  changelog="$REPO/plugins/$PLUGIN/CHANGELOG.md"
else
  changelog="$REPO/CHANGELOG.md"
fi

if [[ -f "$changelog" ]]; then
  # Insert the new entry before the first existing ## line.
  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  inserted=false
  while IFS= read -r cline; do
    if [[ "$inserted" == false && "$cline" =~ ^##\  ]]; then
      # Insert new entry with a trailing blank line before the old entry.
      printf '%s\n\n' "$entry" >> "$tmpfile"
      inserted=true
    fi
    printf '%s\n' "$cline" >> "$tmpfile"
  done < "$changelog"

  # If no ## line was found (unusual), append the entry at the end.
  if [[ "$inserted" == false ]]; then
    printf '\n%s\n' "$entry" >> "$tmpfile"
  fi

  mv "$tmpfile" "$changelog"
  trap - EXIT
else
  # Create a new CHANGELOG.md with a standard header.
  {
    printf '# Changelog\n\n'
    printf 'All notable changes to this project will be documented in this file.\n\n'
    printf 'The format is based on [Keep a Changelog](https://keepachangelog.com/).\n\n'
    printf '%s\n' "$entry"
  } > "$changelog"
fi

echo "CHANGELOG.md updated." >&2

exit 0
```

**Step 3: Test the preview flag**

Run:
```bash
bash plugins/release-pipeline/scripts/generate-changelog.sh . 99.99.99 --preview
```

Expected: outputs changelog entry to stdout, does NOT modify CHANGELOG.md. Verify with `git status` — no file changes.

Run without preview to verify existing behavior preserved:
```bash
# Don't actually run this — just verify the code path exists
# bash plugins/release-pipeline/scripts/generate-changelog.sh . 99.99.99
```

**Step 4: Commit**

```bash
git add plugins/release-pipeline/scripts/generate-changelog.sh
git commit -m "feat(release-pipeline): add --preview flag to generate-changelog.sh"
```

---

### Task 3: Rewrite `commands/release.md` — Context Detection and Menu

This is the main deliverable. Rewrite the entire file with the new structure.

**Files:**
- Rewrite: `plugins/release-pipeline/commands/release.md`

**Step 1: Write the new command file**

Replace the entire contents of `plugins/release-pipeline/commands/release.md` with the new unified menu command. The file structure is:

```
---
name: release
description: "Release pipeline — interactive menu for quick merge, full release, plugin release, status, dry run, or changelog preview."
---

# Release Pipeline

You are the release orchestrator. When invoked, gather context about the repository, then present an interactive menu of release options.

## CRITICAL RULES
[Same 5 rules as current — TodoWrite, fail-fast, no force-push, noreply email, GO approval]

## Phase 0: Context Detection
[Run detection commands, set internal variables]

## Menu Presentation
[AskUserQuestion with context-aware options]

## Mode 1: Quick Merge
[Same as current Mode 1 — unchanged]

## Mode 2: Full Release
[Same as current Mode 2 but version auto-suggested, user confirms or overrides]

## Mode 3: Plugin Release
[Same as current Mode 3 but plugin picker uses AskUserQuestion, version auto-suggested per-plugin]

## Mode 4: Release Status
[NEW — read-only status report]

## Mode 5: Dry Run
[NEW — simulate full release, revert all changes]

## Mode 6: Changelog Preview
[NEW — generate and optionally save changelog]

## Rollback Suggestions
[Same table as current]
```

The full content for this file is detailed below. Write this exact content:

````markdown
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
3. Show the user: file count, change summary, proposed commit message
4. Print: **"Review the changes above. Reply GO to proceed, or anything else to abort."**
5. WAIT for user response. If not "GO" → report "Quick merge aborted." and stop.
6. Commit with the generated message.

If the working tree is clean, skip directly to Step 3.

### Step 3 — Merge and Push

Show the user a summary of what will happen: commit count on testing ahead of main, files changed.

Print: **"Ready to merge testing into main. Reply GO to proceed, or anything else to abort."**

WAIT for user response. If not "GO" → report "Quick merge aborted." and stop.

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

## Mode 2: Full Release (version provided)

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

Launch THREE Task agents simultaneously **in a single message** (all three tool calls in one response):

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

Display each agent's summary in a consolidated pre-flight report:

```
PRE-FLIGHT RESULTS
==================
Tests:    PASS | FAIL  — <one-line summary>
Docs:     PASS | WARN | FAIL  — <one-line summary>
Git:      PASS | FAIL  — <one-line summary>
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

Print: **"Review the changes above. Reply GO to proceed with the release, or anything else to abort."**

WAIT for user response. If not approval → run `git checkout -- .` and report "Release aborted. All changes reverted." and stop.

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
Tests:     <result from Phase 1>
Docs:      <result from Phase 1>
Git:       <result from Phase 1>
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

Use **AskUserQuestion**:
- question: `"Which version for <plugin-name>?"`
- header: `"Version"`
- options:
  1. label: `"v<suggested_version> (Recommended)"`, description: `"Based on commits: <feat_count> feat, <fix_count> fix, <other_count> other"`
  2. label: `"Custom version"`, description: `"Enter a specific version number"`

If "Custom version" selected, ask the user to enter it.

Normalize the version to `X.Y.Z` without leading `v` for scripts. Use `<plugin-name>/vX.Y.Z` for tags and `vX.Y.Z` for display.

### Phase 1 — Scoped Pre-flight (Parallel)

Launch THREE Task agents simultaneously **in a single message** (all three tool calls in one response):

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

**Step 2 — Generate changelog (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name>
```

**Step 3 — Show diff summary:**

```bash
git diff --stat
```

**Step 4 — Approval gate:**

Print: **"Review the changes above. Reply GO to proceed with the <plugin-name> v<version> release, or anything else to abort."**

WAIT for user response. If not approval → run `git checkout -- .` and report "Release aborted. All changes reverted." and stop.

### Phase 3 — Scoped Release (Sequential)

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
Tests:     <result from Phase 1>
Docs:      <result from Phase 1>
Git:       <result from Phase 1>
Version:   plugins/<plugin-name>/.claude-plugin/plugin.json, marketplace.json
Changelog: plugins/<plugin-name>/CHANGELOG.md
Tag:       <plugin-name>/v<version>
GitHub:    <release URL>
Branch:    <current branch>
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

Display them grouped by conventional commit type (feat, fix, chore, docs, etc.).

### Step 3 — Monorepo Breakdown (if applicable)

If `is_monorepo` is true, show per-plugin status from the `unreleased_plugins` list:

```
PLUGIN STATUS
=============
  home-assistant-dev   v2.1.0   3 commits since home-assistant-dev/v2.1.0
  release-pipeline     v1.1.0   8 commits since release-pipeline/v1.1.0
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

No further action. Display: "Status check complete. Run `/release` again to perform a release."

---

## Mode 5: Dry Run

Simulates a Full Release without committing, tagging, or pushing. All changes are reverted at the end.

### Step 0 — Version Selection

Same as Mode 2 Step 0 — present auto-suggested version via AskUserQuestion. If monorepo, first ask if this is a repo-wide or plugin dry run using AskUserQuestion, then scope accordingly.

### Phase 1 — Pre-flight (Parallel)

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

If a failure occurs, suggest the appropriate rollback based on what phase failed:

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
````

**Step 2: Verify the command is valid**

After writing, verify:
- YAML frontmatter has `name` and `description`
- All `${CLAUDE_PLUGIN_ROOT}` references are correct
- All script paths match existing files
- All AskUserQuestion structures are valid

**Step 3: Commit**

```bash
git add plugins/release-pipeline/commands/release.md
git commit -m "feat(release-pipeline): rewrite /release as interactive context-aware menu

Replaces argument-based routing with:
- Phase 0 context detection (monorepo, git state, version suggestion)
- AskUserQuestion menu with 6 options (Quick Merge, Full Release,
  Plugin Release, Release Status, Dry Run, Changelog Preview)
- Auto-suggested versions from conventional commit analysis
- Context annotations on menu descriptions"
```

---

### Task 4: Update release-detection skill

**Files:**
- Modify: `plugins/release-pipeline/skills/release-detection/SKILL.md`

**Step 1: Rewrite the skill to route to menu**

Replace the entire contents of `plugins/release-pipeline/skills/release-detection/SKILL.md` with:

```markdown
---
name: release-detection
description: >
  Detect release intent in natural language and route to the /release command menu.
  Triggers on: "Release vX.Y.Z", "cut a release", "ship it", "merge to main",
  "deploy to production", "push to main", "release for <repo>",
  "release <plugin-name> vX.Y.Z", "ship <plugin-name>".
---

# Release Detection

You detected release intent in the user's message. Route to the `/release` command.

## Action

Invoke the `/release` command. The command will gather context and present an interactive menu — do NOT try to parse arguments or select a mode yourself.

Simply tell the user: "I detected release intent. Let me bring up the release menu." Then invoke `/release`.

If the user mentioned a specific repo (e.g., "for HA-Light-Controller"), `cd` to that repo first before invoking `/release`.
```

**Step 2: Commit**

```bash
git add plugins/release-pipeline/skills/release-detection/SKILL.md
git commit -m "feat(release-pipeline): simplify release-detection skill to route to menu"
```

---

### Task 5: Bump plugin version and update README

**Files:**
- Modify: `plugins/release-pipeline/.claude-plugin/plugin.json:4`
- Modify: `plugins/release-pipeline/README.md`

**Step 1: Bump version in plugin.json**

Change `"version": "1.1.0"` to `"version": "1.2.0"` in `plugins/release-pipeline/.claude-plugin/plugin.json`.

**Step 2: Update marketplace.json**

Find the `release-pipeline` entry in `.claude-plugin/marketplace.json` and update its `version` to `"1.2.0"`.

Also update the `description` field to: `"Interactive release pipeline — context-aware menu for quick merge, full semver release, plugin release, status checks, dry runs, and changelog preview."`.

**Step 3: Rewrite README.md**

Replace `plugins/release-pipeline/README.md` with updated documentation reflecting the new menu-driven UX:

```markdown
# Release Pipeline Plugin

Interactive release pipeline for any repo. One command, six options.

## Usage

```
/release
```

Or say: "ship it", "merge to main", "cut a release", "release v1.2.0"

The command auto-detects your repository state and presents a context-aware menu:

| Option | Description |
|--------|-------------|
| Quick Merge | Commit and merge testing → main (no version bump) |
| Full Release | Semver release with pre-flight, changelog, tag, GitHub release |
| Plugin Release | Release a single plugin from a monorepo (scoped tag + changelog) |
| Release Status | Show unreleased commits, last tag, changelog drift |
| Dry Run | Simulate a full release without any changes |
| Changelog Preview | Generate and display a changelog entry |

## Context-Aware

The menu adapts to your repo:
- **Monorepo?** Plugin Release option appears with unreleased plugin count
- **Dirty tree?** Quick Merge warns about uncommitted changes
- **Version suggestion** auto-calculated from conventional commits (feat → minor, fix → patch, BREAKING → major)

## Full Release Workflow

| Phase | Action | Parallel? |
|-------|--------|-----------|
| 0. Detection | Auto-detect repo state, suggest version | Yes |
| 1. Pre-flight | Run tests, audit docs, check git state | Yes (3 agents) |
| 2. Preparation | Bump versions, generate changelog, show diff | Sequential |
| 3. Release | Commit, merge, tag, push, GitHub release | Sequential |
| 4. Verification | Confirm tag, release page, notes | Sequential |

## Fail-Fast

If anything fails, the pipeline stops immediately and suggests rollback steps. No destructive auto-recovery.

## Supported Test Runners

Auto-detected from project files:

- **Python**: pytest (pyproject.toml, pytest.ini, setup.cfg)
- **Node.js**: npm test (package.json)
- **Rust**: cargo test (Cargo.toml)
- **Go**: go test (go.mod)
- **Make**: make test (Makefile)
- **Fallback**: reads CLAUDE.md for test commands

## Installation

```
/plugin marketplace add L3DigitalNet/Claude-Code-Plugins
/plugin install release-pipeline@l3digitalnet-plugins
```
```

**Step 4: Commit**

```bash
git add plugins/release-pipeline/.claude-plugin/plugin.json \
      plugins/release-pipeline/README.md \
      .claude-plugin/marketplace.json
git commit -m "chore(release-pipeline): bump version to v1.2.0 and update docs

- Updated plugin manifest and marketplace entry
- Rewrote README for menu-driven UX"
```

---

### Task 6: Final verification

**Step 1: Validate marketplace**

```bash
bash scripts/validate-marketplace.sh
```

Expected: all checks pass.

**Step 2: Validate JSON files**

```bash
jq . plugins/release-pipeline/.claude-plugin/plugin.json
jq . .claude-plugin/marketplace.json
```

Expected: both parse without errors.

**Step 3: Test suggest-version.sh in both modes**

```bash
bash plugins/release-pipeline/scripts/suggest-version.sh .
bash plugins/release-pipeline/scripts/suggest-version.sh . --plugin release-pipeline
```

Expected: both output a version suggestion line.

**Step 4: Test generate-changelog.sh --preview**

```bash
bash plugins/release-pipeline/scripts/generate-changelog.sh . 99.99.99 --preview
git status  # should show no changes
```

Expected: changelog printed to stdout, no file modifications.

**Step 5: Verify command file structure**

```bash
head -5 plugins/release-pipeline/commands/release.md
```

Expected: valid YAML frontmatter with `name: release` and updated `description`.

**Step 6: Review all changes**

```bash
git log --oneline -10
```

Verify 5 commits were created in the right order.
