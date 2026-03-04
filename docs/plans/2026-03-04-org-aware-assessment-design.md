# Design: Org-Aware Repo Assessment for github-repo-manager

**Date:** 2026-03-04
**Status:** Approved

## Problem

The community health module uses GitHub's `/repos/{owner}/{repo}/community/profile` API to report a health score and identify missing files. This API only checks files in the repository itself — it does not traverse org-level inheritance from an org's `.github` repository. For org-owned repos that rely on org-wide community health files (a valid and recommended pattern), the API reports them as missing. This produces false positives: a repo with 100% actual coverage gets flagged at 87% because the API can't see the inherited files.

A secondary gap: the plugin applies identical rules regardless of whether a repo is owned by a GitHub user (personal account) or a GitHub organization. Several conventions differ between these contexts — CODEOWNERS team patterns, branch protection reviewer types, and org-level branch rulesets are all org-specific features that should not be flagged or recommended on personal repos.

## Solution

Add `owner_type` (User | Organization) as first-class session context alongside the existing tier (1–4). Use this to apply org-specific rules only where appropriate.

## Changes

### 1. `repo-manager/SKILL.md` — Detect owner_type during onboarding

During Step 4 (tier auto-detection), the `repos classify` command already returns full GitHub repo data including `owner.type`. Extract this and store it as `owner_type` in session context. No new API calls are needed.

Session confirmation line format gains owner type:
```
✓ owner/repo-name — Org · Tier 4 · labels OK
✓ owner/repo-name — User · Tier 3 · labels OK
```

The tier question presented to the owner stays unchanged — `owner_type` is auto-detected, not prompted.

### 2. `community-health/SKILL.md` — 3-phase fix

#### Phase 1: New Step 0 — Org Inheritance Resolution (org repos only)

Before any individual file checks, for org repos:
1. Check whether the org has a `.github` repo: `gh-manager repos list --org {orgname}` → look for repo named `.github`
2. If it exists, enumerate its community health files: check for `SECURITY.md`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md`, `SUPPORT.md` in the `.github` repo
3. Store the result as `inherited_files` — a list of file paths confirmed present at org level

This runs once and is reused across all per-file checks in Step 2.

For user repos, skip this step entirely.

#### Phase 2: API Score Presentation

The community profile API score is unreliable for org repos because it excludes inherited files. Presentation changes:

**User repos:** Present the score as-is (it accurately reflects the repo).

**Org repos:** Present with caveat:
> GitHub API reported: 87% (this figure excludes org-inherited files — see per-file breakdown below for actual coverage)

Do not present the raw percentage as a health score for org repos. The per-file breakdown is the authoritative view.

#### Phase 3: File Resolution Order

Every per-file check now follows this resolution:

1. **Repo directly** — file exists in repo root or `.github/` → ✅ Present
2. **Org inherited** (org repos only) — file is in `inherited_files` → ✅ Inherited (org .github)
3. **Neither** → ❌ Missing

When a file is inherited: report as `✅ Inherited (org .github)` not `❌ Missing`. Do not propose adding the file to the repo unless the owner specifically wants per-repo copies.

#### Bonus: CODEOWNERS Team Pattern Validation

CODEOWNERS team patterns (`@org/team-name`) are only valid in org repos:
- **Org repos:** Accept `@org/team-name` patterns as valid — do not flag them
- **User repos:** Flag `@org/team-name` patterns as likely invalid (teams don't exist on personal accounts); suggest replacing with individual `@username` references

### 3. `security/SKILL.md` — Org ruleset audit + branch protection context

#### New Step 6: Org Ruleset Audit (org repos only)

GitHub organizations can apply branch protection via "Rulesets" — a newer API that operates at the org level rather than per-repo. These can apply to all repos or specific patterns (e.g., all `main` branches).

```bash
gh api /orgs/{org}/rulesets
```

- If org rulesets exist that target the repo's default branch: present them alongside the per-repo branch protection rules. Note how they interact (org rulesets take precedence; per-repo rules are additive).
- If neither org rulesets nor per-repo branch protection are in place on an org repo: this is a more significant gap than on a user repo — note it as such.
- If org rulesets fully cover the repo's default branch: the "no branch protection" finding from Step 5 is not a gap. Suppress it or note it as covered.

Error handling: if the PAT lacks `admin:org` scope, `GET /orgs/{org}/rulesets` returns 403. Handle gracefully: note the check was skipped and what scope would be needed.

#### Branch Protection Section Update

The branch protection recommendation table gains an `Applicability` column:

| Rule | Recommended | Applicability |
|------|-------------|---------------|
| Require PR reviews | Yes (≥1 reviewer) | All repos |
| Require status checks | Yes | All repos |
| Enforce admins | Yes (Tier 4) | All repos |
| Require linear history | Optional | All repos |
| Allow force pushes | No | All repos |
| Require signed commits | Optional | All repos |
| Team reviewers in required reviewers | Recommended | Org repos only |
| Require conversation resolution | Optional | All repos |

For user repos: do not flag the absence of team reviewers as a gap. Individual reviewer requirements are the applicable standard.

### 4. `repo-manager-assessment/SKILL.md` — Thread owner_type through all modules

Update the assessment orchestrator preamble:
- Session context now includes: tier + owner_type
- Security module has an additional step (org ruleset audit) for org repos — note this in the module execution order description
- The unified findings view may show org-specific findings under Security (org ruleset gaps)

No change to module execution order. No change to deduplication rules.

## Modules Not Affected

- PR Management — no org-specific behavior differences
- Issue Triage — org team assignment is cosmetic; no rule changes needed
- Dependency Audit — no org-specific differences
- Release Health — no org-specific differences
- Notifications — no org-specific differences
- Discussions — no org-specific differences
- Wiki Sync — no org-specific differences

## Data Model

`owner_type` is a string enum: `"User"` | `"Organization"`. Derived from GitHub API `repo.owner.type` field. Available from the classify command response at session start — no additional API calls needed to determine it.

## Backward Compatibility

User repos see no behavior change in the common case — the org-specific checks simply don't run. Org repos gain more accurate assessments (fewer false positives, additional org ruleset check).

## Files to Change

1. `plugins/github-repo-manager/skills/repo-manager/SKILL.md`
2. `plugins/github-repo-manager/skills/community-health/SKILL.md`
3. `plugins/github-repo-manager/skills/security/SKILL.md`
4. `plugins/github-repo-manager/skills/repo-manager-assessment/SKILL.md`
