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

Selecting Quick Merge with uncommitted changes implies consent to commit them — no separate confirmation gate is needed here. The merge gate in Step 3 is the decision point.

If `git status --porcelain` returned output:

1. Stage all changes: `git add -A`
2. Generate a commit message from `git diff --cached --stat` (summarize the changes)
3. Display the staged changes and proposed message as labelled context before the merge gate:
   - `Changes staged:` — output of `git diff --cached --stat`
   - `Proposed commit:` — the generated commit message
   (The merge gate below is where the user can abort — nothing has been committed yet.)
4. Commit with the generated message.

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

Display a completion block:

```
MERGE COMPLETE
==============
Commits merged: <N>
Files changed:  <summary from git diff --stat HEAD~1>
Branch:         testing
```

Run `git diff --stat HEAD~1` on main before switching back to get the files-changed summary.
