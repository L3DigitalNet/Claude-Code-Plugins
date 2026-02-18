# PR Management Module — Skill

## Purpose

Triage, audit, and surface actionable intelligence on open pull requests. Identify stale PRs, merge conflicts, review gaps, CI failures, and ready-to-merge candidates.

## Execution Order

Runs as module #4 during full assessments (after Security, Release Health, Community Health). Defers Dependabot PRs to the Security module — if a PR is a Dependabot security fix, it should already be surfaced under Security findings.

## Helper Commands

```bash
# List all open PRs
gh-manager prs list --repo owner/name

# List PRs filtered by label
gh-manager prs list --repo owner/name --label maintenance

# Get full PR details (reviews, CI, size)
gh-manager prs get --repo owner/name --pr 42

# Get changed files with diffs
gh-manager prs diff --repo owner/name --pr 42

# Get comments (for dedup marker checking)
gh-manager prs comments --repo owner/name --pr 42

# Actions (all require owner approval)
gh-manager prs label --repo owner/name --pr 42 --add "stale"
gh-manager prs comment --repo owner/name --pr 42 --body "Activity check..."
gh-manager prs request-review --repo owner/name --pr 42 --reviewers "user1,org/team"
gh-manager prs merge --repo owner/name --pr 42 --method squash
gh-manager prs close --repo owner/name --pr 42 --body "Closing: superseded by #55"
```

---

## Assessment Flow

### Step 1: Fetch All Open PRs

```bash
gh-manager prs list --repo owner/name --state open
```

If there are no open PRs, report clean and move on:
> No open PRs — PR management is all clear.

### Step 2: Triage Each PR

For each open PR, fetch full details:

```bash
gh-manager prs get --repo owner/name --pr N
```

Assess each PR on these dimensions:

**Staleness:** Calculate days since `updated_at`. Compare against the tier's staleness threshold (from config or tier defaults in Section 7.3 of the design doc). Skip PRs with `do-not-close` or `long-running` labels (configurable via `ignore_labels`).

**Merge conflicts:** Check `mergeable` and `mergeable_state` fields. If `mergeable: false`, the PR has conflicts.

**Review status:** From `review_summary`:
- `approved` — ready for merge consideration
- `changes_requested` — author needs to address feedback
- `pending` — reviewers assigned but haven't reviewed
- `none` — no reviewers assigned

**CI status:** From `ci_status`:
- `success` — all checks passing
- `failure` — one or more checks failing
- `pending` — checks still running

**Size:** From `size` field (S/M/L/XL based on lines changed).

**Dependabot check:** If the PR author is `dependabot[bot]` or `dependabot`, defer to Security module. Don't duplicate in PR findings during full assessments. During narrow PR checks, include them.

### Step 3: Classify PRs

Sort PRs into categories:

**Ready to merge:** Approved reviews + CI passing + no conflicts + not draft
**Needs attention:** Stale, has conflicts, CI failing, changes requested
**Waiting:** Draft PRs, pending reviews, recently active
**Deferred:** Dependabot PRs (during full assessment), PRs with ignore labels

### Step 4: Present Findings

Present by category, most actionable first:

> 🔀 PR Management — ha-light-controller
>
> **Ready to merge (1):**
> • PR #42 "Add dark mode support" — approved by @reviewer, CI passing, 3 files changed (S)
>
> **Needs attention (2):**
> • PR #57 "Refactor config" — merge conflicts, CI failing, idle 14 days
> • PR #31 "Update deps" — changes requested by @reviewer, idle 7 days
>
> **Waiting (1):**
> • PR #63 "WIP: New feature" — draft, 2 days old
>
> PR #42 looks ready to go. Want me to merge it?

---

## Actions (Owner Approval Required)

### Label Stale PRs

When a PR exceeds the staleness threshold:

```bash
gh-manager prs label --repo owner/name --pr 42 --add "stale"
```

### Post Activity Check Comments

For stale PRs, post a reminder comment. **Always check for existing dedup markers first:**

```bash
gh-manager prs comments --repo owner/name --pr 42
```

Search comment bodies for `<!-- gh-manager:activity-check -->`. If found, don't post another one.

If no marker exists:

```bash
gh-manager prs comment --repo owner/name --pr 42 --body "<!-- gh-manager:activity-check -->
👋 This PR has been idle for 14 days. Is it still in progress, or can it be closed?

If you need more time, add the \`long-running\` label and I won't flag it again.

*Posted by GitHub Repo Manager*"
```

### Label PRs with Conflicts

```bash
gh-manager prs label --repo owner/name --pr 42 --add "needs-rebase"
```

### Label Ready-to-Merge PRs

```bash
gh-manager prs label --repo owner/name --pr 42 --add "ready-to-merge"
```

### Request Reviewers

```bash
gh-manager prs request-review --repo owner/name --pr 42 --reviewers "username"
```

### Merge PRs

⚠️ **Only on explicit owner request.** Never auto-merge.

> PR #42 is approved with passing CI. Want me to merge it?
> Merge method options: merge commit, squash, or rebase.

```bash
gh-manager prs merge --repo owner/name --pr 42 --method squash
```

### Close Stale PRs

⚠️ **Irreversible in practice** (PRs can be reopened but branch may be deleted).

> PR #57 has been idle for 45 days with unresolved conflicts. Want me to close it with a comment explaining why?

```bash
gh-manager prs close --repo owner/name --pr 42 --body "Closing this PR due to extended inactivity (45 days). The branch has merge conflicts that haven't been resolved. Feel free to reopen if you'd like to continue work on this.

*Closed by GitHub Repo Manager*"
```

---

## Cross-Module Interactions

### With Security

- Dependabot PRs that fix security alerts: present once under Security
- During full assessment, skip Dependabot PRs in PR Management
- During narrow PR check, include everything

### With Issue Triage

- If a PR references an issue ("fixes #12", "closes #8"), note the link
- If a merged PR references an open issue, pass that to Issue Triage

### With Community Health

- If a PR updates community health files (CONTRIBUTING.md, etc.), note it addresses community health drift

---

## Configurable Policies

From `pr_management` config section:

| Setting | Default | Description |
|---------|---------|-------------|
| `staleness_threshold_days` | `auto` (tier default) | Days idle before flagging |
| `ignore_labels` | `["do-not-close", "long-running"]` | PRs with these labels skip staleness |
| `size_thresholds.small` | `50` | Lines changed for S classification |
| `size_thresholds.medium` | `200` | Lines changed for M classification |
| `size_thresholds.large` | `500` | Lines changed for L classification |

---

## Error Handling

| Error | Response |
|-------|----------|
| 403 on merge | "I can't merge PRs on this repo. Check that your PAT has Contents write access and the branch isn't protected beyond your permissions." |
| 405 on merge (not mergeable) | "This PR can't be merged in its current state — it may have conflicts or failing required checks." |
| 422 on review request | "That user may not have access to this repo." |
