---
description: Audit and manage GitHub community health files (README, LICENSE, CODE_OF_CONDUCT, CONTRIBUTING, SECURITY, ISSUE_TEMPLATE, PR_TEMPLATE). Use when asked about community profile, missing files, or community health score.
---

# Community Health Module — Skill

## Purpose

Audit and maintain community health files per GitHub's community standards. Check existence, freshness, and accuracy of standard community files. Propose and create missing files from templates with owner approval.

## When This Module Runs

- **Full assessment:** Runs as module #3 in execution order (after Security and Release Health)
- **Narrow check:** Runs alone when owner asks about community health
- **Cross-repo check:** Runs against multiple repos when owner asks "are any repos missing SECURITY.md?" etc.

## Helper Commands Used

```bash
# Check community profile score (quick overview)
gh-manager repo community --repo owner/name

# Check if specific files exist
gh-manager files exists --repo owner/name --path SECURITY.md
gh-manager files exists --repo owner/name --path .github/SECURITY.md
gh-manager files exists --repo owner/name --path CONTRIBUTING.md
gh-manager files exists --repo owner/name --path CODE_OF_CONDUCT.md
gh-manager files exists --repo owner/name --path SUPPORT.md
gh-manager files exists --repo owner/name --path .github/FUNDING.yml
gh-manager files exists --repo owner/name --path CODEOWNERS
gh-manager files exists --repo owner/name --path .github/CODEOWNERS
gh-manager files exists --repo owner/name --path .github/ISSUE_TEMPLATE
gh-manager files exists --repo owner/name --path .github/PULL_REQUEST_TEMPLATE.md
gh-manager files exists --repo owner/name --path .github/DISCUSSION_TEMPLATE

# Read file content for accuracy checks
gh-manager files get --repo owner/name --path CONTRIBUTING.md

# Create/update files
# Tiers 1-3: direct commit to default branch
echo "content" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md"

# Tier 4: commit to maintenance branch → PR
gh-manager branches create --repo owner/name --branch maintenance/community-health-YYYY-MM-DD --from main
echo "content" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md" --branch maintenance/community-health-YYYY-MM-DD
gh-manager prs create --repo owner/name --head maintenance/community-health-YYYY-MM-DD --base main --title "[Maintenance] Community health — SECURITY.md added" --label maintenance

# Label management
gh-manager repo labels list --repo owner/name
gh-manager repo labels create --repo owner/name --name "maintenance" --color "0E8A16" --description "Maintenance task created by repo manager"
```

---

> **Full assessment mode:** Do not output the 🌱 Community Health banner during a full assessment. Collect findings and feed them into the unified 📊 view. Use the per-module banner format only for narrow community health checks.

## Assessment Flow

### Step 0: Org Inheritance Resolution (org repos only)

Before checking any individual files, determine whether inherited community health files exist at the org level. This is only relevant when `owner_type` is `"Organization"`.

**1. Check for org `.github` repo:**

```bash
gh-manager repos list --org {orgname}
```

Scan the result for a repo named `.github`. If absent, skip the rest of Step 0 — no inherited files.

**2. Enumerate community health files in the org `.github` repo:**

```bash
gh-manager files exists --repo {orgname}/.github --path SECURITY.md
gh-manager files exists --repo {orgname}/.github --path CODE_OF_CONDUCT.md
gh-manager files exists --repo {orgname}/.github --path CONTRIBUTING.md
gh-manager files exists --repo {orgname}/.github --path SUPPORT.md
gh-manager files exists --repo {orgname}/.github --path .github/ISSUE_TEMPLATE
gh-manager files exists --repo {orgname}/.github --path .github/PULL_REQUEST_TEMPLATE.md
```

**3. Build `inherited_files`:** Store a list of file paths that are confirmed present at the org level. This list is reused throughout Step 2 — any file present in `inherited_files` counts as covered for all repos in the org.

**For user repos (`owner_type` is `"User"`):** Skip Step 0 entirely. There is no org-level inheritance to check.

---

### Step 1: Community Profile Quick Check

Start with the community profile API for a fast overview:

```bash
gh-manager repo community --repo owner/name
```

This returns `health_percentage` (0-100) and which standard files exist/are missing. Use this as a starting point — it covers README, CODE_OF_CONDUCT, CONTRIBUTING, LICENSE, SECURITY, issue templates, PR template. It does NOT cover: SUPPORT.md, FUNDING.yml, CODEOWNERS, discussion templates.

**API score reliability differs by owner type:**

- **User repos:** The score accurately reflects the repo's actual coverage. Present it as-is.
- **Org repos:** The API does not check files inherited from the org's `.github` repository. The score will underreport coverage for repos that intentionally rely on org-level files. Do not present the raw percentage as a health score for org repos — present it with a caveat:

  > GitHub API reported: N% — this figure doesn't count org-inherited files. Actual coverage is determined by the per-file breakdown below.

  The per-file breakdown (Step 2), which resolves org inheritance, is the authoritative view for org repos.

### Step 2: Detailed File Checks

For files the community profile API doesn't cover, and for accuracy checks beyond existence, check individually.

**File resolution order (apply for every file):**

1. **Repo directly** — check repo root and `.github/`. If found in either location, the file is ✅ Present.
2. **Org inherited** (org repos only) — if the file is in `inherited_files` from Step 0, it is ✅ Inherited (org .github). Do not propose adding it to the repo.
3. **Neither** — only flag the file as ❌ Missing if both steps above come up empty.

**Check order (by priority):**

1. **SECURITY.md** — Highest priority for public repos. Security researchers need to know how to report vulnerabilities.
2. **LICENSE** — Required for legal clarity. If missing, note it but don't generate (license choice is a legal decision the owner must make).
3. **README.md** — Assumed present (repos without READMEs are unusual). Check freshness if it exists.
4. **CONTRIBUTING.md** — Important for repos accepting contributions.
5. **CODE_OF_CONDUCT.md** — Expected on public repos with community interaction.
6. **SUPPORT.md** — Nice to have. Lower priority.
7. **CODEOWNERS** — Useful for repos with multiple contributors.
8. **Issue templates** — Check `.github/ISSUE_TEMPLATE/` directory.
9. **PR template** — Check `.github/PULL_REQUEST_TEMPLATE.md`.
10. **Discussion templates** — Check `.github/DISCUSSION_TEMPLATE/` (only if discussions enabled).

When a file is inherited, present it as: `✅ Inherited from org .github` in the findings summary. This is a valid configuration — not a gap. Only suggest adding the file directly to the repo if the owner asks for per-repo copies.

### Step 3: Content Accuracy Checks

For files that exist, do quick accuracy checks:

**CONTRIBUTING.md:**
- Does it reference the correct default branch name? (Compare against `repo info` → `default_branch`)
- Does it mention the correct repo name?

**SECURITY.md:**
- Does it include a contact method (email address or URL)?
- Is the contact information plausible (not a placeholder like `TODO` or `your-email@example.com`)?

**CODEOWNERS:**
- Do referenced team/user handles look valid? (Simple pattern check — no API validation of teams)
- **Owner type matters for team patterns:**
  - **Org repos:** `@org/team-name` patterns are valid — GitHub supports team ownership in org repos. Do not flag these.
  - **User repos:** `@org/team-name` patterns are not valid — personal accounts have no teams. If found, flag as likely invalid and suggest replacing with individual `@username` references.

**These are heuristic checks, not definitive.** Present findings as observations, not errors:
> Your CONTRIBUTING.md references the "master" branch, but your default branch is "main". Want me to update it?

### Step 4: Freshness Assessment

For existing files, note when they were last updated relative to the repo's overall activity. Don't fetch commit history for every file (expensive). Instead, note if the community profile `updated_at` is significantly older than the repo's `pushed_at`.

---

## Label Bootstrapping

Label bootstrapping is handled during onboarding (Step 6 of the core `repo-manager` skill). Community Health does not duplicate this flow.

If Community Health needs to apply a label that doesn't exist, report it:
> Label `maintenance` not found — run label bootstrapping first (or it may have been skipped during onboarding).

To create labels directly from this module:
```bash
gh-manager repo labels create --repo owner/name --name "maintenance" --color "0E8A16" --description "Maintenance task created by repo manager"
```

**Idempotent:** The create command is a no-op if the label already exists.

---

## Creating Missing Files

### Template System

Templates are in `${CLAUDE_PLUGIN_ROOT}/templates/`. Available:
- `SECURITY.md.tmpl`
- `CODE_OF_CONDUCT.md.tmpl`
- `CONTRIBUTING.md.tmpl`
- `PULL_REQUEST_TEMPLATE.md.tmpl`
- `ISSUE_TEMPLATE/bug_report.md.tmpl`
- `ISSUE_TEMPLATE/feature_request.md.tmpl`

Templates contain `{{PLACEHOLDER}}` variables that you fill in from context:
- `{{REPO_NAME}}` — from repo info
- `{{DEFAULT_BRANCH}}` — from repo info
- `{{OWNER}}` — from repo info
- `{{SECURITY_CONTACT_EMAIL}}` — ask owner if not in portfolio config
- `{{CONTACT_EMAIL}}` — same as security contact or ask owner
- `{{RESPONSE_DAYS}}` — default to 3, or ask
- `{{DEVELOPMENT_SETUP_INSTRUCTIONS}}` — analyze repo and generate, or ask
- `{{CODE_STYLE_NOTES}}` — analyze repo and generate, or ask

### File Creation Workflow

**Always present content to owner before creating:**

> Here's the SECURITY.md I'd create for ha-light-controller:
>
> [show rendered content]
>
> Does this look right? I can adjust the contact email, response timeline, or anything else before saving.

⚠️ **Tiers 3 and 4 (public repos):** Once committed, these files are immediately publicly visible to all visitors. Review the content carefully — especially contact addresses, response timelines, and any org-specific wording — before confirming.

**Tier 1-3: Direct commit**
```bash
echo "<content>" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md"
```

**Tier 4: PR workflow**
```bash
# Get today's date for branch name
DATE=$(date +%Y-%m-%d)

# Create maintenance branch
gh-manager branches create --repo owner/name --branch maintenance/community-health-$DATE --from main

# Commit file to branch
echo "<content>" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md" --branch maintenance/community-health-$DATE

# If multiple files, commit each to the same branch
echo "<content>" | gh-manager files put --repo owner/name --path CODE_OF_CONDUCT.md --message "Add CODE_OF_CONDUCT.md" --branch maintenance/community-health-$DATE

# Open PR
gh-manager prs create --repo owner/name \
  --head maintenance/community-health-$DATE \
  --base main \
  --title "[Maintenance] Community health — SECURITY.md, CODE_OF_CONDUCT.md added" \
  --body "Adds missing community health files:\n- SECURITY.md\n- CODE_OF_CONDUCT.md\n\nGenerated by GitHub Repo Manager." \
  --label maintenance
```

### Existing Maintenance PR Detection

Before creating a new branch for Tier 4, check for existing maintenance PRs:

```bash
gh-manager prs list --repo owner/name --label maintenance
```

Look for PRs whose title starts with `[Maintenance] Community health`. If one exists:
- Update the existing branch with new commits (add files to it)
- Comment on the existing PR noting what changed
- Do NOT create a duplicate PR

---

## Org-Level `.github` Repository

### When to Suggest

During cross-repo community health checks, if the same file is missing from 3+ repos in the same org, suggest the org-level `.github` approach:

> SECURITY.md is missing from 5 of your public repos. Instead of adding it to each one, you could create a .github repository for your organization. Files there automatically apply to all repos that don't have their own version.
>
> One SECURITY.md covers everything. Want me to set that up, or add it to each repo individually?

### Detection

When assessing a repo that belongs to an org:
1. Check if a `.github` repo exists in the org (look for it in `repos list` output)
2. If it exists, check what community health files are in it
3. A repo missing SECURITY.md locally but covered by org-level `.github/SECURITY.md` is NOT flagged as missing

---

## Presenting Findings

### Single-Repo Assessment

Present as a summary with action items:

> 🌱 Community Health — ha-light-controller (Tier 4, User)
>
> GitHub API Score: 57% (accurate — user repo)
>
> ✅ Present: README.md, LICENSE (MIT)
> ❌ Missing: SECURITY.md, CODE_OF_CONDUCT.md
> ❌ Missing: Issue templates, PR template
> ⚠️ Stale: CONTRIBUTING.md references "master" branch (default is "main")
>
> SECURITY.md is the highest priority — it tells security researchers how to report vulnerabilities responsibly. Want me to create one?

**Org repo example (with inherited files):**

> 🌱 Community Health — markdown-keeper (Tier 4, Org)
>
> GitHub API Score: 87% — excludes org-inherited files. See per-file breakdown for actual coverage.
>
> ✅ Present: README.md, LICENSE (MIT), CONTRIBUTING.md
> ✅ Inherited (org .github): SECURITY.md, CODE_OF_CONDUCT.md
> ❌ Missing: Issue templates, PR template
> ⚠️ Stale: CONTRIBUTING.md references "master" branch (default is "main")
>
> All security and conduct files are covered via org-level defaults. Missing: issue templates and PR template.

### Cross-Repo Report

Group findings by concern:

> 🌱 Community Health — Cross-Repo Report
>
> Scanned 15 repos (2 forks skipped, 1 archived skipped)
>
> Missing SECURITY.md (5 repos): ha-light-controller, DFBU, HA-Dev-Template, Markdown-Keeper, Claude-Code-Plugins
> Missing CODE_OF_CONDUCT.md (5 repos): [same]
> Missing issue templates (5 repos): [same]
> Missing PR template (2 repos): DFBU, Markdown-Keeper
>
> SECURITY.md is the most urgent gap. Want me to add it to all 5 repos?

---

## Cross-Module Interactions

### With Security Module

- If SECURITY.md is missing, the Community Health module owns this finding
- The Security module should reference it: "security policy gap noted in community health"
- Don't duplicate the finding in both modules

### With Release Health Module

- CHANGELOG.md freshness: on Tier 4 repos, Release Health owns CHANGELOG assessment
- Community Health skips CHANGELOG freshness checks on Tier 4 repos
- On Tiers 1-3 (where Release Health doesn't run), Community Health can note CHANGELOG staleness if relevant

### With PR Management

- If a Copilot PR exists that updates community health files, note it:
  "PR #5 from Copilot aligns docs — merging it would address some of the community health drift"

---

## Error Handling

| Error | Response |
|-------|----------|
| 404 on community profile | "This repo may not have the community profile feature enabled. I'll check files individually." |
| 403 on file operations | "I don't have permission to create files on this repo. Check that your PAT has Contents write access." |
| 422 on file create (conflict) | "The file was created by someone else since I checked. Let me re-check..." |

Never fail silently. Report errors and offer alternatives.
