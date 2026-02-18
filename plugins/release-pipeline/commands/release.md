---
name: release
description: "Release pipeline — no args for quick merge (testing->main), provide version for full release, or provide plugin name + version for monorepo per-plugin release (e.g., /release home-assistant-dev v2.2.0)."
---

# Release Pipeline

You are the release orchestrator. Parse the user's arguments and execute the appropriate mode.

## Argument Parsing

1. Extract a version from the arguments matching pattern `v?[0-9]+\.[0-9]+\.[0-9]+`.
2. Extract a plugin name — any non-version word before or after the version.
3. If no plugin name was given, check for monorepo context:
   - Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-unreleased.sh .`
   - If the script succeeds (monorepo detected) and outputs results, present an interactive picker.
   - If not a monorepo, or user declines to pick a plugin, fall through to existing modes.

**Routing:**

- **No version, no plugin** → Mode 1: Quick Merge
- **Version, no plugin, not monorepo** → Mode 2: Full Release
- **Version + plugin name** → Mode 3: Plugin Release
- **Version, no plugin, IS monorepo** → Interactive picker → Mode 3: Plugin Release

Normalize the version to `X.Y.Z` without leading `v` for scripts. Use `vX.Y.Z` for tags and display. For Mode 3, use `plugin-name/vX.Y.Z` for tags.

## Interactive Plugin Picker (Monorepo)

When a version is provided but no plugin name in a monorepo context:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-unreleased.sh .` and capture the output.
2. Present the results to the user:

```
UNRELEASED CHANGES DETECTED
============================
  1. home-assistant-dev  v2.1.0  (3 commits since home-assistant-dev/v2.1.0)
  2. release-pipeline    v1.0.0  (12 commits since release-pipeline/v1.0.0)

Which plugin are you releasing? Enter the number or name:
```

3. Wait for user selection. Use the selected plugin name for Mode 3.
4. If no plugins have unreleased changes, report "All plugins are up to date — nothing to release." and stop.
5. If the detect-unreleased.sh script fails (not a monorepo), fall through to Mode 2.

## CRITICAL RULES

1. **Use TodoWrite** to track every step of the pipeline. Update status as you go.
2. **If ANY step fails, STOP IMMEDIATELY.** Report what failed, suggest the appropriate rollback command from the Rollback section, and do NOT continue.
3. **Never force-push.** Do not use `git push --force` or `git push -f` under any circumstances.
4. **Verify noreply email before push.** Run `git config user.email` and confirm it matches `*@users.noreply.github.com`. If it does not, STOP and tell the user.
5. **Wait for explicit "GO" approval** before executing release operations (merge, tag, push). Present a summary and pause.

---

## Mode 1: Quick Merge (no version)

Use this mode when the user runs `/release` with no version argument. This merges `testing` into `main` and pushes.

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

If the working tree is dirty, on `main`, or email is not noreply: STOP and report the issue.

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

Use this mode when the user provides a version (e.g., `/release v1.2.0`). This runs parallel pre-flight checks, bumps versions, generates a changelog, creates a git tag, pushes, and creates a GitHub release.

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

- If **ANY agent reports FAIL** → STOP. Display the failure details and suggest: "Fix the issues above and re-run `/release <version>`."
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

Use this mode when a plugin name is identified (directly or via picker). This runs scoped pre-flight checks, bumps versions in the plugin manifest and marketplace.json, generates a per-plugin changelog, creates a scoped git tag, and creates a GitHub release.

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

Display each agent's summary in a consolidated pre-flight report:

```
PRE-FLIGHT RESULTS
==================
Tests:    PASS | FAIL  — <one-line summary>
Docs:     PASS | WARN | FAIL  — <one-line summary>
Git:      PASS | FAIL  — <one-line summary>
```

- If **ANY agent reports FAIL** → STOP. Display the failure details and suggest: "Fix the issues above and re-run `/release <plugin-name> <version>`."
- If **all PASS or WARN** → proceed to Phase 2.

### Phase 2 — Scoped Preparation (Sequential)

**Step 1 — Bump versions (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --plugin <plugin-name>
```

This bumps:
- `plugins/<plugin-name>/.claude-plugin/plugin.json`
- The matching entry in `.claude-plugin/marketplace.json`

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

Print: **"Review the changes above. Reply GO to proceed with the <plugin-name> v<version> release, or anything else to abort."**

WAIT for user response. If not approval → run `git checkout -- .` and report "Release aborted. All changes reverted." and stop.

### Phase 3 — Scoped Release (Sequential)

Execute each command sequentially. If any command fails, STOP and report with rollback suggestion.

```bash
# Scoped git add — only the plugin directory and marketplace.json
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

Then create the GitHub release. Use the changelog entry generated in Phase 2 as the release notes:

```bash
gh release create "<plugin-name>/v<version>" --title "<plugin-name> v<version>" --notes "<changelog entry>"
```

### Phase 4 — Scoped Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version> --plugin <plugin-name>
```

Display the verification report. If verification fails → WARN the user but do NOT attempt automatic rollback (the release is already public).

### Final Summary

Display a completion report:

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

Get the release URL with:

```bash
gh release view "<plugin-name>/v<version>" --json url -q '.url'
```

---

## Rollback Suggestions

If a failure occurs, suggest the appropriate rollback based on what phase failed:

| Phase | What happened | Rollback command |
|-------|--------------|-----------------|
| Phase 1 (Pre-flight) | Checks failed before any changes | Nothing to roll back. Fix the reported issues and retry. |
| Phase 2 (Preparation) | Version bump or changelog failed | `git checkout -- .` |
| Phase 3 (Before push) | Commit, merge, or tag failed locally | `git tag -d v<version> && git checkout testing && git reset HEAD~1` |
| Phase 3 (After push) | Push succeeded but something else failed | Manual intervention needed. To delete the remote tag: `git push origin --delete v<version>`. The merge to main may need a revert commit. |
| Phase 3 (Before push, plugin) | Scoped commit/merge/tag failed locally | `git tag -d <name>/v<version> && git checkout testing && git reset HEAD~1` |
| Phase 3 (After push, plugin) | Push succeeded but something else failed | Manual: `git push origin --delete <name>/v<version>`. May need revert commit. |
| Phase 4 (Verification) | Post-release checks failed | No automatic rollback. Verify manually what failed and address individually. |
