---
description: Orchestrate operations across multiple GitHub repositories. Use when asked to check, audit, or fix something across all repos, multiple repos, or a portfolio of repositories.
---

# Cross-Repo Orchestration — Skill

## Purpose

Manage portfolio-level operations: cross-repo checks, batch mutations, scope inference, config management, and session lifecycle. This skill extends the core repo-manager skill with multi-repo capabilities.

## When This Skill Applies

- Owner asks about multiple repos ("check all my repos", "which repos need X")
- Owner asks a question scoped to a concern, not a repo ("any open PRs?", "security posture")
- Owner references portfolio config or repo configuration
- Owner asks to set up or modify configuration

---

## Helper Commands

```bash
# Config management
gh-manager config repo-read --repo owner/name
gh-manager config repo-write --repo owner/name [--branch BRANCH] [--dry-run]
gh-manager config portfolio-read
gh-manager config portfolio-write [--dry-run]
gh-manager config resolve --repo owner/name

# Cross-repo discovery (from Phase 0)
gh-manager repos list [--type TYPE] [--limit N]
gh-manager repos classify --repo owner/name
```

---

## Configuration System

### Per-Repo Config (`.github-repo-manager.yml`)

Lives in the repository root. Read with:

```bash
gh-manager config repo-read --repo owner/name
```

If it exists, the `parsed` field contains the config. If `parse_error` is set, tell the owner and fall back to tier defaults.

### Portfolio Config (`~/.config/github-repo-manager/portfolio.yml`)

Local-only. Read with:

```bash
gh-manager config portfolio-read
```

### Resolved Config

Get the effective merged config for any repo:

```bash
gh-manager config resolve --repo owner/name
```

Returns the fully merged result with source tracking (which setting came from which level).

### Config Precedence (highest to lowest)

1. **Portfolio per-repo overrides** — owner's local config always wins
2. **Per-repo `.github-repo-manager.yml`** — travels with the repo
3. **Portfolio defaults** — baseline for all repos
4. **Built-in tier defaults** — from `config/default.yml`

### Creating/Updating Config

**Private repos (Tiers 1-2):** Offer to create `.github-repo-manager.yml` directly in the repo:

```bash
echo "CONFIG_YAML" | gh-manager config repo-write --repo owner/name
```

**Public repos (Tiers 3-4):** Suggest using the portfolio config to avoid committing a config file to a public repo. If the owner prefers in-repo config, create via PR on Tier 4:

```bash
echo "CONFIG_YAML" | gh-manager config repo-write --repo owner/name --branch maintenance/add-config
gh-manager prs create --repo owner/name --head maintenance/add-config --base main --title "[Maintenance] Add .github-repo-manager.yml" --label maintenance
```

### Config Validation (Skill Layer)

When loading config, validate against `config/schema.yml`:

- **Unknown keys:** Note and ignore. Suggest correction: "Your config has `relase_health` — did you mean `release_health`?"
- **Invalid values:** Report and fall back to tier defaults: "Staleness threshold is -3 days, using Tier 3 default of 21 days."
- **Type mismatches:** Coerce where obvious (e.g., `"true"` → `true`), flag where ambiguous.
- **Never block on config errors.** Report, use fallbacks, continue.

---

## Cross-Repo Checks

### Scope Inference

Infer which repos and modules to check from the owner's request:

| Owner Says | Repos | Modules |
|-----------|-------|---------|
| "Check community health across all my repos" | Public repos | Community Health |
| "Security posture across everything" | All repos | Security |
| "Any open PRs I should deal with?" | All repos with open PRs | PR Management |
| "Which repos need a release?" | Tier 4 repos | Release Health |
| "Wiki status" | Public repos (Tiers 3-4) | Wiki Sync |
| "Dependency alerts" | Repos with code | Security + Dependency Audit |
| "Stale issues" | All repos with open issues | Issue Triage |
| "Any Dependabot PRs?" | All repos | PR Management + Deps |

### Auto-Inference Rules

- Community health → public repos only
- Security posture → all repos
- Wiki status → public repos with wiki enabled (Tiers 3-4)
- Open PRs / notifications → all repos
- Issue triage → all repos with open issues
- Release readiness → Tier 4 primarily; also Tier 3 with releases (informational)
- Discussions → repos with discussions enabled

### Execution Flow

1. **Discover repos:**
   ```bash
   gh-manager repos list --type all
   ```

2. **Load portfolio config** (if exists):
   ```bash
   gh-manager config portfolio-read
   ```

3. **Filter repos:**
   - Remove forks (unless explicitly included in portfolio)
   - Remove archived repos (unless explicitly included as read-only)
   - Remove repos with `skip: true` in portfolio
   - Apply scope inference (e.g., public only for community health)

4. **Classify each repo** (tier detection):
   ```bash
   gh-manager repos classify --repo owner/name
   ```
   Use cached tier from portfolio config if available.

5. **Run target module(s)** against each repo.

6. **Present cross-repo report** (findings grouped by concern, not by repo).

### Cross-Repo Report Format

```
📋 Community Health — Cross-Repo Report

Missing SECURITY.md (5 repos):
  ha-light-controller (Tier 4)
  DFBU-Dotfiles-Backup-Utility (Tier 4)
  Markdown-Keeper (Tier 3)
  ...

Missing CODE_OF_CONDUCT.md (5 repos):
  [same repos]

Skipped:
  forks: integration_blueprint, brands
  archived: old-project

Recommendation: SECURITY.md is highest priority. I can generate
a template and apply it to all 5 repos — PRs for Tier 4, direct
commits for Tier 3.

Want me to fix them all, or work through one at a time?
```

---

## Cross-Repo Batch Mutations

### Mutation Strategy Per Tier

| Tier | Method | Owner Interaction |
|------|--------|-------------------|
| 1 | Direct commit | Batch approval |
| 2 | Direct commit | Batch approval |
| 3 | Direct commit | Batch approval |
| 4 | Pull request | PRs created, owner merges later |

### Batch Execution

When the owner says "fix them all":

1. **Generate content** once (or customize per-repo if needed)
2. **Apply to each repo** using the appropriate tier mutation:

   Tiers 1-3 (direct commit):
   ```bash
   echo "CONTENT" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md"
   ```

   Tier 4 (PR):
   ```bash
   gh-manager branches create --repo owner/name --branch maintenance/add-security-md --from main
   echo "CONTENT" | gh-manager files put --repo owner/name --path SECURITY.md --branch maintenance/add-security-md --message "Add SECURITY.md"
   gh-manager prs create --repo owner/name --head maintenance/add-security-md --base main --title "[Maintenance] Add SECURITY.md" --label maintenance
   ```

3. **Report results** grouped by mutation method:
   ```
   Done. Here's what I did:
     Tier 4 (PRs created):
       ha-light-controller — PR #6
       DFBU — PR #12
     Tier 3 (committed directly):
       Markdown-Keeper — committed to main
   ```

### Rate Limit Awareness

Before starting a batch operation, check remaining API budget:

```bash
gh-manager auth rate-limit
```

A cross-repo check against 20 repos can easily use 200+ API calls. If the budget is low:

> I have ~150 API calls remaining (resets in 45 minutes). Scanning 20 repos for community health will use roughly 100 calls. Want to proceed, or wait for the rate limit to reset?

---

## Fork and Archive Handling

**Forks:** Skipped by default. Forks have upstream conventions the plugin shouldn't override.

**Archived repos:** Skipped by default. All mutations return 403 on archived repos.

Both are listed in cross-repo reports as skipped. Owner can include either via portfolio config:

```yaml
repos:
  integration_blueprint:
    skip: false    # Include this fork
    tier: 3
  old-project:
    skip: false
    read_only: true  # Archived — assessment only, no mutations
```

If the owner explicitly targets an archived repo:

> ha-legacy-tool is archived, so it's read-only — I can't create PRs, push to wiki, or modify files. I can still assess its current state if you want a health snapshot.

---

## Session Lifecycle

### Session Start

When `/repo-manager` is invoked:

1. Check helper is installed (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/ensure-deps.sh`)
2. Verify PAT (`gh-manager auth verify`)
3. Infer scope from owner's request
4. Load config (portfolio + per-repo)
5. Proceed to assessment

### Session Wrap-Up

When the owner is done:

1. **Deferred items:** Note anything assessed but not acted on
2. **Report offer:** Offer to generate maintenance report (skip for narrow checks)
3. **Summary:** Brief statement of what changed
4. **Exit cleanly:** Return to normal conversation

### Mid-Session Directives

The owner can redirect at any time:
- "Skip the rest, move to wiki sync"
- "Show me the diff before you push"
- "How many API calls have we used?"
- "Generate a partial report"
- "Switch to repo X"

---

## Owner Expertise Level

From portfolio config `owner.expertise`:

| Level | Explanation Style |
|-------|------------------|
| **beginner** (default) | Full explanations, jargon translation, teaching moments |
| **intermediate** | Uncommon concepts only, assumes PR/branch familiarity |
| **advanced** | Terse, peer-level. Only irreversibility warnings remain |

The owner can change mid-session:
> "You don't need to explain what PRs are anymore"
> → "Got it — I'll dial back the explanations. You can set this permanently in your portfolio config."

---

## Error Handling for Cross-Repo Operations

| Situation | Response |
|-----------|----------|
| Repo fails mid-batch | Continue with remaining repos, report failure |
| Rate limit hit mid-batch | Report progress so far, offer partial report |
| PAT lacks scope for some repos | Skip affected repos, note which and why |
| Config parse error | Report, use defaults, continue |
