# Discussions Module — Skill

## Purpose

Manage GitHub Discussions — surface unanswered questions, stale threads, and discussions needing maintainer attention. Help keep the community discussion space healthy and responsive.

## Execution Order

Runs as module #8 during full assessments (after Notifications, before Wiki Sync). Discussions are often lower priority than issues and PRs, so they run later.

## Helper Commands

```bash
# List discussions with classification
gh-manager discussions list --repo owner/name
gh-manager discussions list --repo owner/name --limit 50

# Post a comment on a discussion
gh-manager discussions comment --repo owner/name --discussion 5 --body "Thanks for the feedback..."

# Close a discussion
gh-manager discussions close --repo owner/name --discussion 5 --reason RESOLVED
```

Close reasons: `RESOLVED`, `OUTDATED`, `DUPLICATE`.

---

## Assessment Flow

### Step 1: Check for Discussions

```bash
gh-manager discussions list --repo owner/name
```

If `enabled: false`:
> Discussions are not enabled on this repo. If you'd like a community Q&A space, you can enable them in Settings → General → Features → Discussions.

If enabled but no discussions:
> Discussions are enabled but empty — nothing to triage.

### Step 2: Triage Discussions

The helper returns discussions pre-classified with `needs_attention`, `is_unanswered`, and `has_no_replies` flags.

**Classify into categories:**

**Unanswered Q&A:** Discussions in answerable categories (typically "Q&A") where no answer has been marked. These are the highest priority — someone asked a question and hasn't gotten a definitive answer.

**No replies:** Discussions with zero comments. The author is waiting for any engagement.

**Stale:** Discussions not updated in the staleness threshold period. May need closing or a follow-up.

**Active:** Recently updated, has replies — healthy.

### Step 3: Present Findings

> 💬 Discussions — ha-light-controller
>
> 12 open discussions across 3 categories:
>
> **Needs attention (3):**
> • 🙋 Q&A #5 "How to configure multi-zone?" — unanswered, 8 days old
> • 🙋 Q&A #9 "Error with firmware 2.4" — unanswered, 3 days old
> • 💡 Ideas #7 "Support for Zigbee devices" — no replies, 15 days old
>
> **By category:**
> • Q&A (6) — 2 unanswered
> • Ideas (4) — 1 with no replies
> • Show and Tell (2) — all healthy
>
> The two unanswered Q&A items should probably get a response. Want me to draft replies, or just flag them for your attention?

### Step 4: Suggest Actions

Based on the triage:

**Unanswered Q&A:** Suggest the owner answer directly. Claude can draft a response if the owner wants, but the owner should review and post it themselves (the helper can post via `discussions comment`).

**Stale discussions with no activity:** Suggest closing with an appropriate reason.

**Resolved discussions still open:** If a discussion has been answered or resolved in the comments but not formally closed, suggest closing.

---

## Actions (Owner Approval Required)

### Post a Comment

```bash
gh-manager discussions comment --repo owner/name --discussion 5 --body "Great question! You can configure multi-zone by...

*Posted via GitHub Repo Manager*"
```

### Close Resolved Discussions

```bash
gh-manager discussions close --repo owner/name --discussion 3 --reason RESOLVED
```

### Close Stale Discussions

```bash
gh-manager discussions close --repo owner/name --discussion 7 --reason OUTDATED
```

For stale closures, consider posting a comment first:

```bash
gh-manager discussions comment --repo owner/name --discussion 7 --body "Closing this as it's been inactive for 30+ days. Feel free to open a new discussion if this is still relevant.

*Posted via GitHub Repo Manager*"
gh-manager discussions close --repo owner/name --discussion 7 --reason OUTDATED
```

---

## Cross-Module Interactions

### With Issue Triage

- If a discussion should be converted to an issue (e.g., a bug report posted in discussions), note it but don't auto-convert — suggest the owner do it manually via GitHub UI.

### With Notifications

- Discussion reply notifications may overlap. The Notifications module handles them with cross-reference.

### With Community Health

- An active, well-maintained discussion space is a sign of community health.
- If discussions are enabled but all stale, it may indicate the feature isn't being used effectively.

---

## Configurable Policies

| Setting | Default | Description |
|---------|---------|-------------|
| `staleness_threshold_days` | `auto` (tier default) | Days idle before flagging |
| `close_stale` | `false` | Auto-close stale discussions (owner still approves) |

---

## Error Handling

| Error | Response |
|-------|----------|
| GraphQL not found | "Discussions aren't enabled on this repo." |
| 403 on mutation | "I can't post comments or close discussions. Check PAT permissions." |
| Category not found | "That discussion category doesn't exist. Available categories: ..." |

---

## Presenting Findings (for Reports)

| Module | Status | Findings | Actions Taken |
|--------|--------|----------|---------------|
| Discussions | ⚠️ Needs attention | 3 unanswered, 2 stale | 1 closed (outdated) |
