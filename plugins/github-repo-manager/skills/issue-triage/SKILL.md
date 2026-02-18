---
description: Triage GitHub issues — label, categorize, detect linked PRs, identify stale issues, and close resolved ones. Use when asked about issues, issue backlog, or issue triage.
---

# Issue Triage Module — Skill

## Purpose

Audit and triage open issues to surface what needs attention. Identify stale, unlabeled, or resolved issues and keep the issue tracker healthy.

## Execution Order

Runs as module #5 during full assessments (after PR Management). Cross-references merged PRs from PR Management to identify issues that may be resolved but not yet closed.

## Helper Commands

```bash
# List open issues (excludes PRs)
gh-manager issues list --repo owner/name

# Get full issue details with linked PRs
gh-manager issues get --repo owner/name --issue 12

# Get comments (for dedup marker checking)
gh-manager issues comments --repo owner/name --issue 12

# Actions (all require owner approval)
gh-manager issues label --repo owner/name --issue 12 --add "bug,priority-high"
gh-manager issues comment --repo owner/name --issue 12 --body "Activity check..."
gh-manager issues close --repo owner/name --issue 12 --body "Resolved by PR #15" --reason completed
gh-manager issues close --repo owner/name --issue 8 --reason not_planned
gh-manager issues assign --repo owner/name --issue 12 --assignees "username"
```

---

## Assessment Flow

### Step 1: Fetch All Open Issues

```bash
gh-manager issues list --repo owner/name --state open
```

If no open issues, report clean:
> No open issues — issue tracker is all clear.

### Step 2: Triage Each Issue

For issues that need deeper inspection (stale, unlabeled, high comment count), fetch full details:

```bash
gh-manager issues get --repo owner/name --issue N
```

Assess each issue on:

**Staleness:** Days since `updated_at`. Compare against tier staleness threshold. Skip issues with `long-term` or `backlog` labels (configurable via `ignore_labels`).

**Labels:** Are any labels applied? If `require_labels` is true (default), flag unlabeled issues. Suggest labels based on issue title and body content analysis.

**Assignees:** Is anyone assigned? Unassigned issues on active repos may need attention.

**Linked PRs:** Does the issue have linked PRs (from `linked_prs` in the get response)? If a linked PR was merged, the issue may be resolved.

**Milestones:** Is the issue assigned to a milestone? Note if milestone is overdue.

### Step 3: Classify Issues

**Likely resolved:** Has a linked PR that's merged — may need closing.
**Stale:** Exceeds staleness threshold, no recent activity.
**Unlabeled:** No labels applied (if `require_labels` is configured).
**Unassigned:** No assignee on an active repo.
**Active:** Recent activity, properly labeled and assigned.

### Step 4: Present Findings

> 📋 Issue Triage — ha-light-controller
>
> **Likely resolved (1):**
> • Issue #12 "Light doesn't turn off" — linked PR #15 was merged 3 days ago
>
> **Stale (2):**
> • Issue #5 "Add color temperature support" — 45 days idle, no assignee
> • Issue #8 "Docs unclear on setup" — 30 days idle, labeled "enhancement"
>
> **Unlabeled (1):**
> • Issue #19 "Crash on startup" — opened 2 days ago, no labels
>   Suggested labels: bug, priority-high (based on title/content)
>
> **Active (3):**
> • Issue #20, #21, #22 — all recently updated, properly triaged
>
> Issue #12 looks resolved — want me to close it with a note linking to PR #15?

---

## Actions (Owner Approval Required)

### Close Resolved Issues

When a linked PR has been merged:

```bash
gh-manager issues close --repo owner/name --issue 12 --body "Resolved by PR #15. Closing this issue.

*Closed by GitHub Repo Manager*" --reason completed
```

### Label Suggestions

When suggesting labels for unlabeled issues, analyze the title and body:
- Keywords like "crash", "error", "broken" → suggest `bug`
- Keywords like "feature", "add", "support" → suggest `enhancement`
- Keywords like "docs", "documentation", "readme" → suggest `documentation`
- Urgency words like "critical", "urgent", "blocking" → suggest a priority label

Present suggestions and let the owner confirm:

> Issue #19 "Crash on startup" — I'd suggest labeling this as `bug` and `priority-high` based on the content. Sound right?

```bash
gh-manager issues label --repo owner/name --issue 19 --add "bug,priority-high"
```

### Post Activity Checks on Stale Issues

Check for existing dedup markers first:

```bash
gh-manager issues comments --repo owner/name --issue 5
```

Search for `<!-- gh-manager:activity-check -->`. If not found:

```bash
gh-manager issues comment --repo owner/name --issue 5 --body "<!-- gh-manager:activity-check -->
👋 This issue has been idle for 45 days. Is it still relevant?

If this is a long-term item, add the \`backlog\` label and I won't flag it again.

*Posted by GitHub Repo Manager*"
```

### Close Stale Issues (Not Planned)

For issues the owner wants to close as stale:

```bash
gh-manager issues close --repo owner/name --issue 8 --body "Closing due to inactivity. Feel free to reopen if this is still relevant.

*Closed by GitHub Repo Manager*" --reason not_planned
```

### Assign Issues

```bash
gh-manager issues assign --repo owner/name --issue 12 --assignees "owner-username"
```

---

## Cross-Module Interactions

### With PR Management

- If PR Management found merged PRs that reference issues ("fixes #12"), pass those to Issue Triage as "likely resolved"
- Avoid surfacing the same PR-issue link in both modules

### With Security

- If Security found Dependabot alerts that have associated issues, note them to avoid duplicate surfacing
- Security-related issues should be flagged with appropriate severity

---

## Configurable Policies

| Setting | Default | Description |
|---------|---------|-------------|
| `staleness_threshold_days` | `auto` (tier default) | Days idle before flagging |
| `require_labels` | `true` | Flag unlabeled issues |
| `ignore_labels` | `["long-term", "backlog"]` | Issues with these labels skip staleness |

---

## Error Handling

| Error | Response |
|-------|----------|
| 403 on label/close | "I can't modify issues on this repo. Check that your PAT has Issues write access." |
| 410 on issue (transferred) | "This issue was transferred to another repo." |
| Timeline API unavailable | "I couldn't check for linked PRs on this issue. The timeline API may require additional permissions." |
