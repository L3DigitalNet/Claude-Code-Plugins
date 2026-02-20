# Mode 1: Quick Merge

# Loaded by the release command router after the user selects "Quick Merge".
# Context variables from Phase 0 are available: is_dirty, current_branch, last_tag, commit_count.

Merges `testing` into `main` and pushes. No version bumps.

## Step 1 — Pre-flight

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

## Step 2 — Stage and Commit (only if uncommitted changes exist)

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

## Step 3 — Merge and Push

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

## Step 4 — Report

Display:
- Number of commits merged
- Files changed (`git diff --stat HEAD~1` on main before switching back)
- Confirm current branch is `testing`
