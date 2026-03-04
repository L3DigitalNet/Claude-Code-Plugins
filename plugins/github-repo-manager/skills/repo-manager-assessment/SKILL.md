---
description: Full assessment orchestration for GitHub Repo Manager. Use when running a complete multi-module health assessment, presenting unified findings across modules, or generating a maintenance report.
---

# GitHub Repo Manager — Full Assessment Mode
#
# Orchestration layer — coordinates 9 assessment modules and produces the unified findings view.
# Called by repo-manager/SKILL.md Step 7 ("proceed to assessment").
# The unified findings format produced here is the authoritative presentation format — module
# skills produce raw data; this skill owns the consolidated output. If the module execution
# order changes, cross-module deduplication rules (Section 2) MUST be updated to match.
#
# Architectural constraint: modules MUST run in the declared order (Security first) because
# later modules defer duplicates to earlier ones. Reordering breaks deduplication silently.
#
# Session context (established during onboarding, carried through all modules):
#   - tier (1-4): controls ceremony level, mutation strategy, staleness thresholds
#   - owner_type ("User" | "Organization"): controls which org-specific checks run
#     Org repos get: org inheritance resolution (community health), org ruleset audit (security)
#     User repos: org-specific steps are skipped; no behavior change for existing checks

## Module Execution Order

When running a full assessment, execute modules in this order (required for cross-module deduplication):

```
1. Security              [org repos: includes org ruleset audit (Step 6)]
2. Release Health
3. Community Health      [org repos: includes org inheritance resolution (Step 0)]
4. PR Management
5. Issue Triage
6. Dependency Audit
7. Notifications
8. Discussions
9. Wiki Sync
```

**During a full assessment, do NOT present each module's findings separately as it completes.** Run all modules first, collect all findings, then present one consolidated view using the Unified Findings Presentation format below.

**Exceptions — surface immediately without waiting:**
- 🔴 Any open secret scanning alert
- 🔴 Critical Dependabot vulnerability with no fix PR
- 🔴 An error that would prevent the rest of the assessment from running (e.g., rate limit hit)

**Progress indicator:** As each module completes, emit one line so the owner knows the assessment is progressing:
```
✓ Security (1/9)
✓ Release Health (2/9)
✓ Community Health (3/9)
...
```

### Narrow Check Mode

For narrow checks (owner asks about a single topic), run only the relevant module(s) and use the module's own presentation format — no unified rollup needed.

**Session state for narrow checks:** If the owner invokes a narrow check without a prior full session, two pieces of state may be missing:

- **Tier**: Collect via two bounded questions before running the module. First, get the repo name (free text is unavoidable — take it from the owner's message if present). Then use `AskUserQuestion`:

  Question 1: "Is this a public or private repo?"
  - "Public" / "Private"

  Question 2: "Does it have published releases (tags/releases on GitHub)?"
  - "Yes — it has releases" → public + releases = Tier 4; private + releases = Tier 2
  - "No releases yet" → public = Tier 3, private = Tier 1

  Apply tier heuristics based on the combination. Skip the second question if the first answer and context make the tier obvious.

- **Expertise level**: Default to **beginner** unless the owner has indicated otherwise. Do not ask.

---

## Cross-Module Intelligence Framework

### Purpose

Prevent the owner from seeing the same finding repeated across multiple modules. When modules run in sequence during a full assessment, later modules check whether their findings overlap with earlier ones.

### Module Ownership

This order is required for deduplication to work:

```
1. Security          — owns Dependabot alerts, secret scanning, security posture,
                       org rulesets (org repos only)
2. Release Health    — owns CHANGELOG drift, unreleased commits, release cadence
3. Community Health  — owns community files (defers CHANGELOG to Release Health on Tier 4);
                       org repos resolve inherited files before flagging gaps
4. PR Management     — owns open PRs (defers Dependabot PRs to Security)
5. Issue Triage      — owns open issues (cross-references merged PRs from step 4)
6. Dependency Audit  — owns dependency graph (defers Dependabot alerts to Security)
7. Notifications     — owns notification backlog
8. Discussions       — owns discussion threads
9. Wiki Sync         — owns wiki content (runs last — may reference findings from above)
```

### Deduplication Rules

| Overlap | Primary Module | Resolution |
|---------|---------------|------------|
| Dependabot PR is also a security alert | Security | Present once under Security with fix PR note |
| Merged PR links to open issue | Issue Triage | "May be resolved — linked PR was merged" |
| SECURITY.md missing | Community Health | Security references it, doesn't duplicate |
| CHANGELOG stale + unreleased commits | Release Health | Community Health skips CHANGELOG on Tier 4 |
| Copilot PR aligns docs with code | PR Management | Note it addresses community health drift |

### Unified Findings Presentation

**This is the required output format for full assessments.** After all modules complete, present a single consolidated view — do not use per-module banners (📋, 🔀, 📦, etc.) during full assessment mode. Those formats are for narrow checks only.

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
- Group by severity, not by module. A finding from Security and one from PR Management can both appear under 🔴 Critical.
- Include source module attribution (e.g., "Security", "PR #42") so the owner can ask for details.
- ✅ Healthy items are listed briefly — don't expand them unless the owner asks.
- Keep the full view to ≤ 20 bullet points. If more than 20 findings exist, show the top 20 by severity, then use `AskUserQuestion`:

  > N more findings below this threshold. What would you like to do?

  Options:
  - **"Show me all findings"** — present the full list before moving to action proposals
  - **"Continue to action proposals"** — work with the top 20 and defer the rest to the report
  - **"Generate the full report"** — produce the detailed report now

---

## Report Generation

### When to Generate

- **Full assessment:** Always offer a report at session end
- **Narrow check:** Only if significant findings or actions were taken
- **Quick check:** Skip the report offer, give a one-liner summary

### Report Format

Reports are presented inline in conversation. Owner can ask to save as a local markdown file.

**Single-repo report template:**

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

**Cross-repo report template:**

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

### Saving Reports

When the owner asks to save:

```bash
mkdir -p ~/github-repo-manager-reports
# Filename: repo-name-YYYY-MM-DD.md (single-repo)
# Filename: cross-repo-module-YYYY-MM-DD.md (cross-repo)
```

Reports are never committed to the repo — they're local working documents.
