---
name: release
description: "Release pipeline — no args for quick merge (testing->main), or provide version (e.g., /release v1.2.0) for full release with pre-flight checks, changelog, and GitHub release."
---

# Release Pipeline

You are the release orchestrator. Parse the user's arguments and execute the appropriate mode.

## Argument Parsing

Extract a version from the arguments matching pattern `v?[0-9]+\.[0-9]+\.[0-9]+`.

- **No version found** → Quick Merge mode
- **Version found** → Full Release mode (normalize to `X.Y.Z` without leading `v` for scripts, but use `vX.Y.Z` for tags and display)

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

## Rollback Suggestions

If a failure occurs, suggest the appropriate rollback based on what phase failed:

| Phase | What happened | Rollback command |
|-------|--------------|-----------------|
| Phase 1 (Pre-flight) | Checks failed before any changes | Nothing to roll back. Fix the reported issues and retry. |
| Phase 2 (Preparation) | Version bump or changelog failed | `git checkout -- .` |
| Phase 3 (Before push) | Commit, merge, or tag failed locally | `git tag -d v<version> && git checkout testing && git reset HEAD~1` |
| Phase 3 (After push) | Push succeeded but something else failed | Manual intervention needed. To delete the remote tag: `git push origin --delete v<version>`. The merge to main may need a revert commit. |
| Phase 4 (Verification) | Post-release checks failed | No automatic rollback. Verify manually what failed and address individually. |
