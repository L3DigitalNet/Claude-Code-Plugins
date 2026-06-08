# Mode 1: Quick Push

# Loaded by the release command router after the user selects "Quick Push"

# Context variables from Phase 0 are available: is_dirty, current_branch, last_tag, commit_count

# Note: filename retained as `mode-1-quick-merge.md` for backward compatibility with the

# router lookup table; mode is now Quick Push under the direct-to-main branch convention

Stage uncommitted changes (if any), commit, and push to `main`. No version bump, no tag, no GitHub release. Use this when you have working-tree edits ready to ship without the full release ceremony.

## Step 1 — Pre-flight

```bash
git status --porcelain
git branch --show-current
git config user.email
```

- If not on `main`: STOP — repo convention is direct commit to `main`; switch to main first.
- If email is not noreply: STOP — fix manually.

## Step 2 — Stage and Commit (only if uncommitted changes exist)

Selecting Quick Push with uncommitted changes implies consent to commit them — no separate confirmation gate is needed here. The push gate in Step 3 is the decision point.

If `git status --porcelain` returned output:

1. Stage all changes: `git add -A`
2. Generate a commit message from `git diff --cached --stat` (summarize the changes).
3. Display the staged changes and proposed message as labelled context before the push gate:
   - `Changes staged:` — output of `git diff --cached --stat`
   - `Proposed commit:` — the generated commit message (The push gate below is where the user can abort — nothing has been pushed yet.)
4. Commit with the generated message.

If the working tree is clean and `git log @{u}..HEAD` is empty, report "Nothing to push." and stop.

## Step 3 — Push gate

Show the user a summary: commit count ahead of `origin/main`, files changed.

Use **AskUserQuestion**:

- question: `"Push to origin/main?"`
- header: `"Push"`
- options:
  1. label: `"Proceed"`, description: `"git pull --rebase origin main, then git push origin main"`
  2. label: `"Abort"`, description: `"Cancel — local commit (if any) stays on main, nothing pushed"` If "Abort" → report "Quick push aborted." and stop.

```bash
git pull --rebase origin main
git push origin main
```

## Step 4 — Report

Display a completion block:

```
PUSH COMPLETE
=============
Commits pushed: <N>
Files changed:  <summary from git diff --stat HEAD~<N>..HEAD>
Branch:         main
```
