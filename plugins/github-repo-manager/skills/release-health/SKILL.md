---
description: Audit release health — unreleased commits, CHANGELOG drift, release cadence, and draft releases. Use when asked about releases, versioning, changelog, or release status.
---

# Release Health Module — Skill

## Purpose

Assess release readiness — surface unreleased work, changelog drift, draft releases, and release cadence. Helps the owner answer: "Should I cut a release?"

## Applicability

- **Tier 4:** Full assessment (public repos with releases).
- **Tier 3:** Informational — show tag/release info if present, note release process is informal.
- **Tiers 1-2:** Skip entirely.

## Execution Order

Runs as module #2 during full assessments (after Security). Owns CHANGELOG drift assessment — Community Health defers CHANGELOG to this module for Tier 4 repos.

## Helper Commands

```bash
# List recent releases
gh-manager releases list --repo owner/name --limit 10

# Get latest release details
gh-manager releases latest --repo owner/name

# Commits since last release (unreleased work)
gh-manager releases compare --repo owner/name

# Fetch and parse CHANGELOG.md
gh-manager releases changelog --repo owner/name

# Create a draft release (owner approval required)
gh-manager releases draft --repo owner/name --tag v1.3.0 --name "v1.3.0" --body "Release notes..."

# Publish a draft release (owner approval required)
gh-manager releases publish --repo owner/name --release-id 12345
```

---

> **Full assessment mode:** Do not output the 📦 Release Health banner during a full assessment. Collect findings and feed them into the unified 📊 view. Use the per-module banner format only for narrow release checks.

## Assessment Flow

### Step 1: Check for Releases

```bash
gh-manager releases latest --repo owner/name
```

If `exists: false`:
- **Tier 4:** This is unusual — a Tier 4 repo should have releases. Note it.
- **Tier 3:** Informational — the repo may use tags without formal releases.

### Step 2: Unreleased Commits

```bash
gh-manager releases compare --repo owner/name
```

This returns the commit count, file changes, and individual commit summaries since the latest release tag.

Evaluate:
- **0 commits:** Repo is current with its latest release.
- **1-5 commits:** Some unreleased work but may not justify a release.
- **6+ commits:** Significant unreleased work — may be time for a release.

### Step 3: CHANGELOG Drift

```bash
gh-manager releases changelog --repo owner/name
```

Compare the `latest_version` found in the changelog against the latest release tag:

- **Match:** Changelog is current with the latest release.
- **Changelog ahead:** Changelog documents unreleased changes (good practice).
- **Changelog behind:** Changelog hasn't been updated since the last release but unreleased commits exist. This is drift.
- **No changelog:** Note the gap. For Tier 4, suggest creating one.

### Step 4: Draft Releases

```bash
gh-manager releases list --repo owner/name --limit 5
```

Check for `draft: true` entries. An existing draft release might be ready to publish.

### Step 5: Release Cadence

From the releases list, calculate:
- Days since last release
- Average interval between the last 5 releases
- Whether the current gap exceeds `cadence_warning_multiplier` × average (default: 2.0×)

### Step 6: Present Findings

After presenting findings with ≥2 action-relevant details, apply the progressive depth offer once per findings block (Communication Principle #7 in the core skill; skip for advanced owners).

> 📦 Release Health — ha-light-controller
>
> **Last release:** v0.2.2 (Feb 10, 2026 — 7 days ago)
> **Unreleased commits:** 9 commits on main since v0.2.2
> **CHANGELOG.md:** Last entry is for v0.2.2 — not yet updated for unreleased work
> **Draft releases:** None
> **Average release cadence:** ~12 days (based on last 5 releases)
>
> There's a decent amount of unreleased work accumulating. The CHANGELOG hasn't been updated for the new commits yet. Want me to summarize the unreleased commits so you can decide if it's time for a release?

---

## Actions (Owner Approval Required)

### Summarize Unreleased Commits

Analyze the commit messages from `releases compare` and generate a human-readable summary grouped by type:

> **Unreleased changes since v0.2.2:**
> - **Features:** Add color temperature support (#34), Add group control mode (#38)
> - **Fixes:** Fix reconnection timeout (#35), Handle empty state gracefully (#37)
> - **Maintenance:** Update dependencies (#36, #39)
>
> This looks like it could be a minor version bump (v0.3.0) given the new features. Want me to create a draft release?

### Create Draft Release

```bash
gh-manager releases draft --repo owner/name --tag v0.3.0 --name "v0.3.0" --body "## What's Changed
### Features
- Add color temperature support (#34)
- Add group control mode (#38)

### Fixes
- Fix reconnection timeout (#35)
- Handle empty state gracefully (#37)

### Maintenance
- Update dependencies (#36, #39)"
```

### Publish Draft Release

⚠️ **Publishing a release is irreversible.** It immediately becomes publicly visible, triggers notifications to all watchers, fires webhooks (e.g., CI/CD pipelines, Slack bots), and appears in the repo's release feed. There is no "unpublish" — you can only delete a release, which leaves the tag and is also visible.

Use `AskUserQuestion` before publishing:

> Draft release v0.3.0 is ready. Publishing will make it live and trigger notifications to all watchers.

Options:
- **"Publish now"** — make it live immediately
- **"Edit release notes first"** — pause so the owner can review/edit the draft on GitHub before publishing
- **"Cancel"** — leave as draft

Then on confirmation:

```bash
gh-manager releases publish --repo owner/name --release-id 12345
```

### Update CHANGELOG via PR (Tier 4)

If the changelog needs updating, create a PR with the new entry:

```bash
gh-manager branches create --repo owner/name --branch maintenance/changelog-v0.3.0 --from main
gh-manager files get --repo owner/name --path CHANGELOG.md
# (Claude prepends the new version entry to the content)
echo "UPDATED_CONTENT" | gh-manager files put --repo owner/name --path CHANGELOG.md --branch maintenance/changelog-v0.3.0 --message "Update CHANGELOG for v0.3.0"
gh-manager prs create --repo owner/name --head maintenance/changelog-v0.3.0 --base main --title "[Maintenance] Update CHANGELOG for v0.3.0" --label maintenance
```

---

## Cross-Module Interactions

### Owns

- CHANGELOG drift assessment (Community Health defers on Tier 4)
- Release cadence analysis
- Draft release management

### With Community Health

- Community Health checks for CHANGELOG existence but defers drift analysis to this module on Tier 4
- If CHANGELOG is missing entirely, Community Health flags it; Release Health notes the gap

### With Wiki Sync

- Wiki sync can include the latest release version on the wiki Home page
- Release Health provides the version info

### With PR Management

- Unreleased commits may include merged PRs — Release Health can cross-reference

---

## Configurable Policies

| Setting | Default | Description |
|---------|---------|-------------|
| `enabled` | `true` (Tier 4) | Auto-enabled for Tier 4, informational Tier 3 |
| `changelog_files` | `["CHANGELOG.md", "CHANGES.md", "HISTORY.md"]` | Files to search for changelog |
| `cadence_warning_multiplier` | `2.0` | Warn if gap exceeds N× average release interval |

---

## Error Handling

| Error | Response |
|-------|----------|
| 404 on latest release | "No published releases found. This repo may use tags without formal releases." |
| Empty comparison | "The latest release tag matches the default branch head — no unreleased commits." |
| No changelog found | "No changelog file found (checked CHANGELOG.md, CHANGES.md, HISTORY.md)." |
