# Monorepo Per-Plugin Release Pipeline

**Date:** 2026-02-18
**Status:** Approved
**Plugin:** release-pipeline v1.0.0 -> v1.1.0

## Problem

The release-pipeline plugin assumes a single-repo release model: one version, one tag
(`vX.Y.Z`), one changelog. This marketplace is a monorepo where each plugin under
`plugins/` is independently versioned. We need per-plugin releases with
`plugin-name/vX.Y.Z` tags and per-plugin changelogs.

## Design Decisions

- **Approach:** Extend existing scripts with `--plugin <name>` flag (Approach A)
- **Plugin selection:** Interactive picker showing unreleased changes
- **Multi-plugin:** One plugin per invocation
- **Quick merge:** Unchanged (whole-repo merge)
- **Changelogs:** Per-plugin `plugins/<name>/CHANGELOG.md`

## Monorepo Detection

```
Monorepo detected if: .claude-plugin/marketplace.json exists AND has 2+ plugins
```

When `/release <version>` is invoked without a plugin name in a monorepo context,
the interactive picker runs.

Direct invocation (`/release home-assistant-dev v2.2.0`) skips the picker.

## New Script: detect-unreleased.sh

```
Usage: detect-unreleased.sh <repo-path>
```

For each plugin in `marketplace.json`:
1. Find the latest tag matching `plugin-name/v*`
2. Count commits since that tag touching `plugins/plugin-name/**`
3. Output: `plugin-name current-version commit-count last-tag`

## Scoped Pre-flight (Phase 1)

Three parallel agents scoped to the selected plugin:
- **Test Runner** — looks for tests in `plugins/<name>/` first, falls back to repo-level
- **Docs Auditor** — scopes to `plugins/<name>/README.md` and plugin docs
- **Git Pre-flight** — checks `plugin-name/vX.Y.Z` tag doesn't exist

Scoping is passed via prompt, not hardcoded in agent definitions.

## Scoped Preparation (Phase 2)

**bump-version.sh --plugin <name>:**
- Bumps `plugins/<name>/.claude-plugin/plugin.json`
- Bumps matching entry in `.claude-plugin/marketplace.json`
- Skips repo-root version files

**generate-changelog.sh --plugin <name>:**
- Collects only commits touching `plugins/<name>/**` since last `plugin-name/v*` tag
- Writes to `plugins/<name>/CHANGELOG.md`

## Scoped Release (Phase 3)

```bash
git add plugins/<name>/ .claude-plugin/marketplace.json
git commit -m "Release <name> v<version>"
git checkout main && git pull origin main
git merge testing --no-ff -m "Release <name> v<version>"
git tag -a "<name>/v<version>" -m "Release <name> v<version>"
git push origin main --tags
git checkout testing
gh release create "<name>/v<version>" --title "<name> v<version>" --notes "<changelog>"
```

Key differences from single-repo:
- Scoped `git add` (not `git add -A`)
- Tag format: `plugin-name/vX.Y.Z`
- Commit message includes plugin name

## Scoped Verification (Phase 4)

**verify-release.sh --plugin <name>:**
- Checks `plugin-name/vX.Y.Z` tag on remote
- Checks GitHub release at that tag
- Same branch check (back on testing)

## Files Changed

| File | Change |
|------|--------|
| `commands/release.md` | Add Mode 3 (Plugin Release) |
| `scripts/detect-unreleased.sh` | New |
| `scripts/bump-version.sh` | Add `--plugin` flag |
| `scripts/generate-changelog.sh` | Add `--plugin` flag |
| `scripts/verify-release.sh` | Add `--plugin` flag |
| `skills/release-detection/SKILL.md` | Recognize plugin name in natural language |
| `README.md` | Add monorepo usage examples |
| `.claude-plugin/plugin.json` | Bump to v1.1.0 |

## Backwards Compatibility

- Quick merge mode: unchanged
- Single-repo full release: unchanged (no `--plugin` = current behavior)
- Agent definitions: unchanged (scoping via prompt)
