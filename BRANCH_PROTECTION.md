# Branch Workflow

This repository uses **direct commits to `main`**. There is no `testing` branch and no merge step.

## The rule

| Workflow | What to do |
| --- | --- |
| Editing plugins, docs, scripts | Commit directly to `main`, push to `origin/main` |
| Releasing a plugin (tag + GitHub release) | Bump `plugin.json` + `marketplace.json`, commit, tag `<name>/vX.Y.Z`, push, `gh release create` (see [Common operations](#common-operations)) |
| Hotfix | Same as any edit — commit to `main`, push, optionally release |

## Why

Single-developer repo. Local pre-commit hooks (noreply email enforcement, marketplace validation) provide the guardrails that branch protection used to provide. Releasing a plugin is a manual version-bump / changelog / tag / GitHub-release ceremony (see [Common operations](#common-operations)); routine edits don't need that ceremony.

## Local guardrails (active)

- **Noreply email pre-commit hook**: rejects commits whose author email doesn't match `^168346341\+chrisdpurcell@users\.noreply\.github\.com$`. Configured globally on the workstation; bypass for tmpdir test repos via `core.hooksPath=/dev/null` in test setup (see `plugins/plugin-test-harness/test/unit/fix/`).
- **Marketplace validation**: run `./scripts/validate-marketplace.sh` before committing changes that touch `.claude-plugin/marketplace.json` or any `plugins/*/.claude-plugin/plugin.json`.

## Versioning

| Layer | Bump rule |
| --- | --- |
| Plugin (`plugins/<name>/.claude-plugin/plugin.json`) | Semantic versioning. Major = breaking, Minor = feature, Patch = fix/docs/chore. |
| Marketplace catalog (`.claude-plugin/marketplace.json` entry) | **Must match the plugin's own `plugin.json` version.** Bump both together in the same commit. |

## Common operations

```bash
# Edit, commit, push
git pull origin main
# (make edits)
git add <specific files>
git commit -m "..."
git push origin main

# Release a plugin (manual)
# 1. Bump the version in plugins/<name>/.claude-plugin/plugin.json
#    and its matching entry in .claude-plugin/marketplace.json (must agree)
# 2. Update plugins/<name>/CHANGELOG.md
./scripts/validate-marketplace.sh
git add plugins/<name> .claude-plugin/marketplace.json
git commit -m "Release <name> vX.Y.Z"
git tag <name>/vX.Y.Z
git push origin main --tags
gh release create <name>/vX.Y.Z --title "<name> vX.Y.Z" --notes "See plugins/<name>/CHANGELOG.md"
```

## What changed (history)

This repo previously used a `testing` branch for development with `git merge testing --no-ff` to deploy to `main`. That convention was retired on 2026-05-07 along with deletion of the `testing` branch (local + remote). All prior tags and releases predate this change and remain valid.

## See also

- [CLAUDE.md](CLAUDE.md) — Claude agent index
- [AGENTS.md](AGENTS.md) — Codex agent index
- [README.md](README.md) — marketplace installation
- `scripts/validate-marketplace.sh` — marketplace validator
