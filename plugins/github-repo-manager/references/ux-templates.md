# UX & Output Templates

All output templates for GitHub Repo Manager. Templates are the contract between the plugin logic and the user — consistent formatting across every session.

## Design Principles

- **Lead with findings, not intent.** No preamble before results.
- **Fail transparently, succeed quietly.** Anomalies get full treatment. Clean passes get one line.
- **Decisions use AskUserQuestion.** All decision points use interactive options. Plain text for progress. These never mix.
- **Evidence accompanies action proposals.** Show what was found before proposing what to do about it.

## Visual Grammar

| Symbol | Meaning |
|--------|---------|
| ✓ | Step passed, check complete |
| 🔴 | Critical finding, action required |
| ⚠️ | Needs attention, non-critical |
| ✅ | Healthy, no issues |
| ⏭ | Deferred by owner |
| 📊 | Full assessment unified findings |
| 📋 | Cross-repo report |
| 🔀 | PR Management (narrow check) |
| 🔒 | Security (narrow check) |
| 📦 | Release Health (narrow check) |
| 🏥 | Community Health (narrow check) |
| 🐛 | Issue Triage (narrow check) |
| 📚 | Dependency Audit (narrow check) |
| 🔔 | Notifications (narrow check) |
| 💬 | Discussions (narrow check) |
| 📖 | Wiki Sync (narrow check) |

---

## Template 1 — Session Header

**When:** After onboarding completes (session.md Step 7).

**All checks passed silently:**
```
✓ owner/repo-name — Org · Tier 4 · labels OK · running assessment...
✓ owner/repo-name — User · Tier 3 · labels OK · running assessment...
```

**Some steps needed interaction:**
```
✓ owner/repo-name — Org · Tier 4 confirmed · 4 labels created · running assessment...
```

A fully configured repo produces zero multi-line onboarding output.

---

## Template 2 — Assessment Progress

**When:** As each module completes during a full assessment (assessment.md Step 3).

```
✓ Security (1/9)
✓ Release Health (2/9)
✓ Community Health (3/9)
✓ PR Management (4/9)
✓ Issue Triage (5/9)
✓ Dependency Audit (6/9)
✓ Notifications (7/9)
✓ Discussions (8/9)
✓ Wiki Sync (9/9)
```

One line per module, emitted as it completes. No buffering.

---

## Template 3 — Unified Findings View

**When:** After all 9 modules complete during a full assessment. This is the required output format for full assessments. Do not use per-module banners during full assessment mode.

```
📊 Repository Health — repo-name (Tier N)

🔴 Critical (N)
• [finding] — [source module] [action available?]
• ...

⚠️ Needs Attention (N)
• [finding] — [source module]
• ...

✅ Healthy
• Security posture: no alerts
• [other passing items]

Errors / Skipped
• Code scanning: not enabled (404)
• ...

[1-2 sentence recommendation for where to start]
```

**Rules:**
- Group by severity, not by module.
- Include source module attribution so the owner can ask for details.
- Healthy items listed briefly; don't expand unless asked.
- Cap at 20 bullet points. If more exist, show top 20, then use `AskUserQuestion`:

  > N more findings below this threshold. What would you like to do?

  Options:
  - **"Show me all findings"** — present full list before action proposals
  - **"Continue to action proposals"** — work with top 20, defer rest to report
  - **"Generate the full report"** — produce detailed report now

---

## Template 4 — Narrow Check Findings

**When:** Running a single module outside of a full assessment. Each module has its own banner icon (see Visual Grammar). Example for PR Management:

```
🔀 PR Management — ha-light-controller

**Ready to merge (1):**
• PR #42 "Add dark mode support" — approved by @reviewer, CI passing, 3 files changed (S)

**Needs attention (2):**
• PR #57 "Refactor config" — merge conflicts, CI failing, idle 14 days
• PR #31 "Update deps" — changes requested by @reviewer, idle 7 days

**Waiting (1):**
• PR #63 "WIP: New feature" — draft, 2 days old

PR #42 looks ready to go.
```

Follow with `AskUserQuestion` proposing the most actionable item.

---

## Template 5 — Cross-Repo Report

**When:** After running a module across multiple repos (cross-repo.md).

```
📋 Community Health — Cross-Repo Report

Missing SECURITY.md (5 repos):
  ha-light-controller (Tier 4)
  DFBU-Dotfiles-Backup-Utility (Tier 4)
  Markdown-Keeper (Tier 3)
  ...

Skipped: 2 forks, 1 archived
  (forks: integration_blueprint, brands · archived: old-project)

Recommendation: SECURITY.md is highest priority. I can generate
a template and apply it to all 5 repos — PRs for Tier 4, direct
commits for Tier 3.

Want me to fix them all, or work through one at a time?
```

---

## Template 6 — Batch Mutation Progress

**When:** During cross-repo batch execution, after each repo is processed.

```
  ✓ owner/repo-name — committed to main
  ✓ owner/repo-name — PR #N created
```

**Summary after batch completes:**

```
Done. Here's what I did:
  Tier 4 (PRs created):
    ha-light-controller — PR #6
    DFBU — PR #12
  Tier 3 (committed directly):
    Markdown-Keeper — committed to main
```

---

## Template 7 — Session Wrap-Up

**When:** Owner indicates they're done (session.md Session Wrap-Up).

**With deferred items:**
```
Deferred:
  ⏭ PR #42 merge — deferred by owner
  ⏭ Branch protection update — skipped (403 on branch-rules)
  ⏭ 3 stale issues — owner will triage manually

Actions taken: created 2 PRs, labeled 1 issue, pushed wiki updates.
```

Then use `AskUserQuestion`:
- **"Show report inline"** — present markdown report in conversation
- **"Save to file"** — write to `~/github-repo-manager-reports/`
- **"Skip the report"** — done

**Quick session (no significant findings):** One-liner summary, no report offer.

---

## Template 8 — Single-Repo Report

**When:** Owner requests a report after a full assessment or significant narrow check.

```markdown
# Repository Maintenance Report
**Repo:** owner/repo-name
**Tier:** N — Description
**Date:** YYYY-MM-DDTHH:MM:SSZ
**Session Type:** Full Assessment | Narrow Check | Module Name

## Summary
| Module | Status | Findings | Actions Taken |
|--------|--------|----------|---------------|
| Community Health | ✅/⚠️/🔴 | N issues | Description |
| ... | ... | ... | ... |

## Deferred Items
- Item: reason for deferral

## API Usage
- REST calls: N / 5,000
- GraphQL points: N / 5,000

## Detailed Findings
[Per-module details as needed]
```

---

## Template 9 — Cross-Repo Report

**When:** Owner requests a report after a cross-repo session.

```markdown
# Cross-Repo Report: Module Name
**Date:** YYYY-MM-DDTHH:MM:SSZ
**Scope:** N repos scanned (N forks skipped, N archived skipped)

## Findings by Concern
| Concern | Repos Affected | Severity |
|---------|---------------|----------|
| Description | N repos | High/Medium/Low |

## Actions Taken
| Action | Repo | Method | Result |
|--------|------|--------|--------|
| Description | repo-name | PR #N / Direct commit | Created/Done |

## Skipped
- forks: name1, name2
- archived: name3

## API Usage
- REST calls: N / 5,000
- GraphQL points: N / 5,000
```

---

## Template Usage

References should point to this file for output formatting rather than defining templates inline. Use:

> Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template N.
