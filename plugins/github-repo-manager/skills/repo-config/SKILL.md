---
description: GitHub Repo Manager configuration system — per-repo and portfolio config files, precedence rules, and validation. Use when reading, writing, or troubleshooting repo-manager configuration.
---

# GitHub Repo Manager — Configuration System

## Helper Commands

```bash
# Config management
gh-manager config repo-read --repo owner/name
gh-manager config repo-write --repo owner/name [--branch BRANCH] [--dry-run]
gh-manager config portfolio-read
gh-manager config portfolio-write [--dry-run]
gh-manager config resolve --repo owner/name
```

---

## Per-Repo Config (`.github-repo-manager.yml`)

Lives in the repository root. Read with:

```bash
gh-manager config repo-read --repo owner/name
```

If it exists, the `parsed` field contains the config. If `parse_error` is set, tell the owner and fall back to tier defaults.

## Portfolio Config (`~/.config/github-repo-manager/portfolio.yml`)

Local-only. Read with:

```bash
gh-manager config portfolio-read
```

## Resolved Config

Get the effective merged config for any repo:

```bash
gh-manager config resolve --repo owner/name
```

Returns the fully merged result with source tracking (which setting came from which level).

## Config Precedence (highest to lowest)

1. **Portfolio per-repo overrides** — owner's local config always wins
2. **Per-repo `.github-repo-manager.yml`** — travels with the repo
3. **Portfolio defaults** — baseline for all repos
4. **Built-in tier defaults** — from `config/default.yml`

## Creating/Updating Config

**Private repos (Tiers 1-2):** Offer to create `.github-repo-manager.yml` directly in the repo:

```bash
echo "CONFIG_YAML" | gh-manager config repo-write --repo owner/name
```

**Public repos (Tiers 3-4):** Suggest using the portfolio config to avoid committing a config file to a public repo. If the owner prefers in-repo config, create via PR on Tier 4:

```bash
echo "CONFIG_YAML" | gh-manager config repo-write --repo owner/name --branch maintenance/add-config
gh-manager prs create --repo owner/name --head maintenance/add-config --base main --title "[Maintenance] Add .github-repo-manager.yml" --label maintenance
```

## Config Validation

When loading config, validate against `config/schema.yml`:

- **Unknown keys:** Note and ignore. Suggest correction: "Your config has `relase_health` — did you mean `release_health`?"
- **Invalid values:** Report and fall back to tier defaults: "Staleness threshold is -3 days, using Tier 3 default of 21 days."
- **Type mismatches:** Coerce where obvious (e.g., `"true"` → `true`), flag where ambiguous.
- **Never block on config errors.** Report, use fallbacks, continue.
