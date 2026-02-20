---
description: Audit dependency health via dependency graph and Dependabot PRs. Use when asked about dependencies, outdated packages, dependency vulnerabilities, or Dependabot PR backlog.
---

# Dependency Audit Module — Skill

## Purpose

Review dependency health beyond just security alerts. Summarize the dependency graph, audit the Dependabot PR backlog, identify outdated dependencies, and recommend batch-merge strategies for low-risk bumps.

## Applicability and Tier Behavior

- **Tier 4 (Public, Releases):** Full assessment with full ceremony. Batch-merge candidates are presented for individual review before merging; each merge triggers CI and is visible to repo watchers. Major version bumps require extra scrutiny — they can break external users.
- **Tier 3 (Public, No Releases):** Same as Tier 4. Public visibility applies to all merges.
- **Tier 2 (Private, Code):** Full assessment. Batch approval acceptable for patch/minor Dependabot PRs with CI passing.
- **Tier 1 (Private, Docs):** Skip dependency audit — docs repos typically don't have meaningful dependency graphs.

## Execution Order

Runs as module #6 during full assessments (after Issue Triage). Defers Dependabot security alerts to the Security module — this module focuses on the broader dependency picture.

## Helper Commands

```bash
# Dependency graph summary (SBOM)
gh-manager deps graph --repo owner/name

# Open Dependabot PRs with age, severity, package info
gh-manager deps dependabot-prs --repo owner/name
```

---

> **Full assessment mode:** Do not output the 🔗 Dependency Audit banner during a full assessment. Collect findings and feed them into the unified 📊 view. Use the per-module banner format only for narrow dependency checks.

## Assessment Flow

### Step 1: Dependency Graph Overview

```bash
gh-manager deps graph --repo owner/name
```

If the dependency graph is not enabled (`enabled: false`), note it:

> Dependency graph is not enabled on this repo. Without it, GitHub can't track dependencies or generate Dependabot alerts. You can enable it in Settings → Security → Dependency graph.

If enabled, summarize:

> 🔗 Dependency Graph — ha-light-controller
> Total packages: 142
> By ecosystem: npm (128), pip (14)

### Step 2: Dependabot PR Backlog

```bash
gh-manager deps dependabot-prs --repo owner/name
```

This is the core of the dependency audit. Evaluate:

**Backlog age:** How old are the oldest unmerged Dependabot PRs? A growing backlog suggests the owner isn't keeping up with updates.

**Security vs. non-security:** Separate security fixes (which the Security module already flagged) from routine version bumps.

**Batch-merge candidates:** Non-security PRs that are mergeable, CI-passing, and have small diffs are candidates for batch merging.

### Step 3: Present Findings

> 🔗 Dependency Audit — ha-light-controller
>
> **Dependabot PR Backlog:** 8 open PRs
> • 2 security fixes (already covered in Security findings)
> • 6 routine version bumps
> • Average age: 12 days, oldest: 28 days
>
> **Batch-merge candidates (4):**
> • PR #68 — Bump @types/node from 18.15.0 to 18.16.0 (1 day old, 2 files)
> • PR #69 — Bump eslint from 8.40.0 to 8.41.0 (3 days old, 2 files)
> • PR #70 — Bump prettier from 2.8.7 to 2.8.8 (5 days old, 2 files)
> • PR #71 — Bump typescript from 5.0.3 to 5.0.4 (7 days old, 2 files)
>
> **Not ready to merge (2):**
> • PR #65 — Bump webpack from 5.80 to 5.82 (CI failing, 14 days old)
> • PR #60 — Bump react from 17 to 18 (major version bump, 28 days old)
>
> The 4 batch-merge candidates are all patch/minor bumps with passing CI. Want me to merge them?

### Step 4: Batch Merge (Owner Approval Required)

⚠️ **Batch merging implications**: Merging multiple PRs in sequence triggers a separate CI run for each. On repos with slow CI, this can queue many builds simultaneously. If one PR's tests fail mid-batch, subsequent merges may inherit the broken state. For Tier 3/4 repos, each merge is also visible to contributors and watcher subscribers.

After presenting the candidates, use `AskUserQuestion`:

- "Merge all N candidates" (recommended if CI passing for all)
- "Let me review each PR first" — skip batch merge, owner handles manually
- "Skip dependency merges for now"

On approval, merge each candidate (squash by default for Dependabot PRs):

```bash
gh-manager prs merge --repo owner/name --pr 68 --method squash
gh-manager prs merge --repo owner/name --pr 69 --method squash
gh-manager prs merge --repo owner/name --pr 70 --method squash
gh-manager prs merge --repo owner/name --pr 71 --method squash
```

**Partial approval:** If the owner specifies a subset (e.g., "merge 68 and 69 but skip 70"), merge only those. List skipped PRs briefly:
```
✅ Merged: PR #68, #69
⏭ Skipped: PR #70 (owner decision), #71 (owner decision)
```

Report results:

> ✅ Merged 4 Dependabot PRs:
> • PR #68 — @types/node 18.15.0 → 18.16.0
> • PR #69 — eslint 8.40.0 → 8.41.0
> • PR #70 — prettier 2.8.7 → 2.8.8
> • PR #71 — typescript 5.0.3 → 5.0.4
>
> 2 PRs remain: webpack (CI failing) and react (major version — needs manual review).

---

## Batch-Merge Criteria

A Dependabot PR is a batch-merge candidate when ALL of these are true:

1. **Not a security fix** (those are handled by Security module with higher urgency)
2. **Patch or minor version bump** (not a major version change)
3. **CI passing** (mergeable + checks passing)
4. **Small diff** (typically ≤ 5 files changed for dependency bumps)
5. **No `do-not-close` or `long-running` label**

Major version bumps are flagged separately:

> ⚠️ PR #60 bumps react from 17 to 18 — that's a major version change that may require code updates. This needs manual review.

---

## Cross-Module Interactions

### With Security

- Security module owns Dependabot vulnerability alerts
- Dependency Audit skips security-flagged Dependabot PRs during full assessment
- During narrow dependency check, include everything

### With PR Management

- Dependabot PRs are also open PRs. During full assessment, they appear here (for non-security bumps) and in Security (for security fixes), not in PR Management
- During narrow PR check, PR Management includes all PRs including Dependabot

---

## Error Handling

| Error | Response |
|-------|----------|
| 404 on SBOM | "Dependency graph isn't enabled. I can still check for Dependabot PRs." |
| 403 on SBOM | "I can't access the dependency graph — PAT may need additional permissions." |
| No Dependabot PRs | "No open Dependabot PRs — dependencies look current." |

---

## Presenting Findings (for Reports)

| Module | Status | Findings | Actions Taken |
|--------|--------|----------|---------------|
| Dependencies | ⚠️ Behind | 4 Dependabot PRs | 2 merged (batch), 2 deferred |
