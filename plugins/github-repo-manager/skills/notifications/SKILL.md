# Notifications Module — Skill

## Purpose

Process and triage repository notifications for the authenticated user. Surface actionable items, summarize the backlog, and offer to mark notifications as read.

## Execution Order

Runs as module #7 during full assessments (after Dependency Audit). Notifications are often downstream effects of issues already surfaced by other modules, so running late avoids redundancy.

## Helper Commands

```bash
# List unread notifications for a repo, categorized
gh-manager notifications list --repo owner/name

# Include read notifications too
gh-manager notifications list --repo owner/name --all

# Mark a single thread as read
gh-manager notifications mark-read --repo owner/name --thread-id 12345

# Mark all repo notifications as read
gh-manager notifications mark-read --repo owner/name
```

---

## Assessment Flow

### Step 1: Fetch Notifications

```bash
gh-manager notifications list --repo owner/name
```

If no unread notifications, report clean:
> No unread notifications for this repo.

### Step 2: Review Priority Summary

The helper returns notifications pre-categorized by priority and type. Use the `summary_by_priority` field to give a quick overview:

> 🔔 Notifications — ha-light-controller
>
> 7 unread notifications:
> • 🔴 Critical: 1 (security alert)
> • 🟡 High: 2 (review request, direct mention)
> • 🔵 Medium: 3 (PR comments)
> • ⚪ Low: 1 (Dependabot PR)

### Step 3: Present Actionable Items

Walk through notifications by priority, starting with critical:

> **Critical:**
> • Security alert: "lodash CVE-2024-XXXX" — this was already flagged by the Security module. Dependabot PR #67 has a fix.
>
> **High:**
> • You were requested to review PR #42 "Add dark mode support"
> • @contributor mentioned you in Issue #19 asking about the crash fix timeline
>
> **Medium/Low:**
> • 3 comments on PR threads you're subscribed to
> • Dependabot opened PR #68 for a minor update

### Step 4: Cross-Reference with Other Modules

During full assessments, many notifications will overlap with findings from other modules:

- Security alert notification → already covered by Security module
- Review request → already surfaced by PR Management
- Dependabot PR notification → already covered by Security/PR Management

For these, note the overlap briefly instead of repeating the full finding:
> The security alert notification corresponds to the Dependabot finding I already covered above.

### Step 5: Offer to Mark as Read

> Want me to mark the 5 notifications that have been addressed as read? I'd keep the 2 action items (review request and mention) unread.

On approval:

```bash
gh-manager notifications mark-read --repo owner/name --thread-id 11111
gh-manager notifications mark-read --repo owner/name --thread-id 22222
# ... for each addressed notification
```

Or mark all:

```bash
gh-manager notifications mark-read --repo owner/name
```

---

## Priority Classification

| Priority | Criteria | Action |
|----------|----------|--------|
| 🔴 Critical | Security alerts, CI failures on default branch | Surface immediately |
| 🟡 High | Review requests, direct mentions, assigned issues | Present as action items |
| 🔵 Medium | PR activity on watched threads, discussion replies | Summarize |
| ⚪ Low | Dependabot PRs, bot comments, subscription updates | Batch summary |

---

## Cross-Module Interactions

### With Security

- Security alert notifications are already covered by the Security module
- Don't duplicate — just note the notification is addressed

### With PR Management

- Review requests are already surfaced by PR Management
- PR activity notifications on PRs already triaged can be summarized briefly

### With Issue Triage

- Issue assignment notifications overlap with Issue Triage findings
- Mentions in issues that are already in the triage report can be cross-referenced

### General Rule

If a notification corresponds to a finding already surfaced by an earlier module, say:
> This notification is addressed by the [Module] findings above.

Don't repeat the full finding.

---

## Presenting Findings (for Reports)

| Module | Status | Findings | Actions Taken |
|--------|--------|----------|---------------|
| Notifications | ℹ️ Reviewed | 7 notifications | 5 marked read |

---

## Error Handling

| Error | Response |
|-------|----------|
| 403 on notifications | "I can't access notifications. Check that your PAT has the `notifications` scope." |
| Empty list (but expect activity) | "No notifications found — you may have already processed them, or the notification settings for this repo may be configured differently." |
