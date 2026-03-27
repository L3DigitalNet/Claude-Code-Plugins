# Cross-Repo Orchestration

## When This Applies

- Owner asks about multiple repos ("check all my repos", "which repos need X")
- Owner asks a question scoped to a concern, not a repo ("any open PRs?", "security posture")
- Owner asks to set up or modify configuration for multiple repos

---

## Scope Inference

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

---

## Execution Flow

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

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 5 (Cross-Repo Report). Group findings by concern (not by repo), list skipped forks/archived repos, and end with a recommendation and `AskUserQuestion`.

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

When the owner indicates they want to apply a fix across repos, use `AskUserQuestion` before proceeding:

> I'll apply this to N repos:
> - Tier 4 repos (pull request — changes go into a draft PR for your review before merging): repo-a, repo-b
> - Tier 1–3 repos (direct commit — changes go live immediately to the default branch, no review step): repo-c, repo-d
>
> **This will create commits/PRs on each repo listed above.** Tier 1–3 commits are immediate and cannot be easily reverted if content is wrong. Tier 4 PRs remain as drafts for you to review before merging.

Use `AskUserQuestion` with options:
- **"Go ahead — fix them all"** — proceed with the plan above
- **"Walk through one at a time"** — apply one repo, pause for approval before next
- **"Cancel"** — stop without making changes

Only after approval:

1. **Generate content** once (or customize per-repo if needed)
2. **Apply to each repo** using the appropriate tier mutation, emitting a progress line after each:

   Tiers 1-3 (direct commit):
   ```bash
   echo "CONTENT" | gh-manager files put --repo owner/name --path SECURITY.md --message "Add SECURITY.md"
   ```
   Then emit progress per Template 6 from `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md`.

   Tier 4 (PR):
   ```bash
   gh-manager branches create --repo owner/name --branch maintenance/add-security-md --from main
   echo "CONTENT" | gh-manager files put --repo owner/name --path SECURITY.md --branch maintenance/add-security-md --message "Add SECURITY.md"
   gh-manager prs create --repo owner/name --head maintenance/add-security-md --base main --title "[Maintenance] Add SECURITY.md" --label maintenance
   ```
   Then emit progress per Template 6.

3. **Report results** grouped by mutation method using Template 6 summary format.

### Implication Warnings

Before executing any cross-repo batch mutation, note applicable consequences:

| Mutation type | Implication to surface |
|---------------|------------------------|
| Wiki push | Force-push overwrites any manually-authored content in the wiki that isn't mirrored in your source docs. |
| PR creation | Creates notifications for any watchers or contributors on each Tier 4 repo. |
| Direct commit to main | Immediately visible in commit history and any open PRs referencing that branch. |

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

## Error Handling

| Situation | Response |
|-----------|----------|
| Repo fails mid-batch | Continue with remaining repos, report failure |
| Rate limit hit mid-batch | Report progress so far, offer partial report |
| PAT lacks scope for some repos | Skip affected repos, note which and why |
| Config parse error | Report, use defaults, continue |
