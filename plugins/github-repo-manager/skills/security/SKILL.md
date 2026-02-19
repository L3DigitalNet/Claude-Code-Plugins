---
description: Audit repository security posture — Dependabot alerts, code scanning, secret scanning, security advisories, and branch protection rules. Use when asked about security, vulnerabilities, CVEs, or Dependabot alerts.
---

# Security Module — Skill

## Purpose

Audit the repository's security posture and surface actionable findings. Covers Dependabot alerts, code scanning, secret scanning, security advisories, branch protection, and SECURITY.md validation.

## Execution Order

Runs as module #1 during full assessments. Security findings have the highest priority and other modules defer to this module for security-related items (Dependabot PRs, SECURITY.md presence).

## Helper Commands

```bash
# Dependabot vulnerability alerts
gh-manager security dependabot --repo owner/name
gh-manager security dependabot --repo owner/name --severity critical

# Code scanning alerts (CodeQL, third-party)
gh-manager security code-scanning --repo owner/name

# Secret scanning alerts
gh-manager security secret-scanning --repo owner/name

# Repository security advisories
gh-manager security advisories --repo owner/name

# Branch protection audit (read-only)
gh-manager security branch-rules --repo owner/name
gh-manager security branch-rules --repo owner/name --branch main
```

---

> **Full assessment mode:** Do not output the Security Posture Scorecard below during a full assessment. Collect findings and feed them into the unified 📊 view in the core skill. Use the scorecard format only for narrow security checks.

## Assessment Flow

### Step 1: Dependabot Alerts

```bash
gh-manager security dependabot --repo owner/name
```

This is the highest-value security check. Evaluate the response:

- **No alerts:** Report clean.
- **Alerts present:** Group by severity. Critical and high get immediate attention.

For each critical/high alert, check if a fix PR exists:

```bash
gh-manager deps dependabot-prs --repo owner/name
```

Cross-reference alert package names with Dependabot PR package names. If a fix PR exists and is mergeable, surface it as the recommended action:

> 🔴 Critical: lodash CVE-2024-XXXX — a fix PR (#67) is open, CI passing, ready to merge.

### Step 2: Code Scanning

```bash
gh-manager security code-scanning --repo owner/name
```

Handle gracefully:
- **Not enabled:** Note it and suggest enabling if the repo has significant code.
- **Enabled, no alerts:** Report clean.
- **Alerts present:** Summarize by severity. Note the scanning tool (CodeQL, etc.).

### Step 3: Secret Scanning

```bash
gh-manager security secret-scanning --repo owner/name
```

**Any open secret scanning alert is high priority** — it means a secret may be exposed.

> 🔴 Secret scanning found 1 open alert: GitHub Personal Access Token detected in `config/secrets.yml`. This secret may be compromised and should be rotated immediately.

### Step 4: Security Advisories

```bash
gh-manager security advisories --repo owner/name
```

Note any draft advisories that haven't been published, and any published advisories for awareness.

### Step 5: Branch Protection Audit

```bash
gh-manager security branch-rules --repo owner/name
```

Evaluate the rules against best practices:

| Rule | Recommended | Why |
|------|------------|-----|
| Require PR reviews | Yes (≥1 reviewer) | Prevents unreviewed changes |
| Require status checks | Yes | Ensures CI passes |
| Enforce admins | Yes (for Tier 4) | Admins follow same rules |
| Require linear history | Optional | Cleaner git history |
| Allow force pushes | No | Prevents history rewriting |
| Require signed commits | Optional | Verifies commit authorship |
| Require conversation resolution | Optional | Ensures review comments addressed |

**Important:** Branch protection is **recommend-only**. The helper cannot modify protection rules. If changes are needed, direct the owner to Settings → Branches.

If the branch is unprotected:

> ⚠️ Your default branch (main) has no protection rules. For a public repo with releases, I'd recommend at minimum requiring PR reviews and status checks. You can configure this in Settings → Branches → Add branch protection rule.

### Step 6: SECURITY.md Cross-Reference

Check if SECURITY.md exists (this information comes from the Community Health module if it ran first, or check directly):

```bash
gh-manager files exists --repo owner/name --path SECURITY.md
```

If missing, note it as a security policy gap. Don't duplicate the finding if Community Health already flagged it — just reference it:

> Security policy gap: No SECURITY.md found (also noted in community health findings).

---

## Security Posture Scorecard

Present a unified security summary:

> 🔒 Security Posture — ha-light-controller (Tier 4)
>
> **Dependabot:** 🔴 1 critical, ⚠️ 2 medium — fix PR available for critical
> **Code Scanning:** ✅ Enabled, 0 open alerts
> **Secret Scanning:** ✅ No exposed secrets
> **Advisories:** ℹ️ 1 draft advisory (unpublished)
> **Branch Protection:** ⚠️ PR reviews required but admins exempt
> **Security Policy:** ❌ No SECURITY.md
>
> The critical Dependabot alert has a fix PR (#67) ready to merge. Want to start there?

---

## Cross-Module Interactions

### Owns (Primary Module For)

- Dependabot vulnerability alerts
- Code scanning alerts
- Secret scanning alerts
- Security advisories
- Branch protection assessment

### Defers To

- **Community Health:** Owns SECURITY.md file creation. Security notes the gap but doesn't create the file.

### Other Modules Defer To Security

- **PR Management:** Dependabot fix PRs are presented under Security, not duplicated in PR findings.
- **Dependency Audit:** Dependabot alerts are presented under Security. Dependency Audit covers the broader dependency graph and non-security Dependabot PRs.

---

## Error Handling

Many security endpoints require specific PAT scopes or repo features to be enabled. Handle each gracefully:

| Error | Response |
|-------|----------|
| 403 on dependabot | "Dependabot alerts aren't accessible. Your PAT may need the `security_events` scope, or Dependabot isn't enabled on this repo." |
| 404 on code-scanning | "Code scanning isn't enabled on this repo. For repos with significant code, consider enabling CodeQL in Settings → Security." |
| 404 on secret-scanning | "Secret scanning isn't available. It's enabled by default on public repos with GitHub Advanced Security." |
| 403 on branch-rules | "I can't read branch protection rules. This typically requires admin access to the repo." |

**Don't stop the assessment on security errors.** Report what you can access and note what's unavailable. The owner can fix permissions later.

> ⚠️ I couldn't check Dependabot alerts (403 — permission denied) or code scanning (not enabled). Everything else checked out fine. Want me to explain how to enable these?
