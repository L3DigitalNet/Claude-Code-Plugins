# Unified /release Menu — Design Document

**Date:** 2026-02-18
**Plugin:** release-pipeline
**Version:** v1.1.0 → v1.2.0

## Problem

The current `/release` command uses argument-based routing: no args = quick merge, version arg = full release, plugin+version = plugin release. Users must know the invocation syntax. There's no interactive discovery of available options.

## Solution

Redesign `/release` as a single interactive entry point that:
1. Runs context detection automatically
2. Presents a context-aware menu via `AskUserQuestion`
3. Walks the user through the selected workflow step by step
4. Auto-suggests version numbers based on conventional commit analysis

## Design Decisions

- **Single command file rewrite** — all logic in `commands/release.md` (Approach A)
- **Context-aware menu** — run detection first, tailor options to repo state
- **AskUserQuestion for menu** — clean clickable UI, consistent with Claude Code UX
- **Release-detection skill routes to menu** — natural language still works but always goes through the menu
- **Auto-suggest versions** — analyze commits since last tag for semver bump suggestion

## Menu Options

| # | Option | Always Shown? | Description |
|---|--------|---------------|-------------|
| 1 | Quick Merge | Yes | Commit and merge testing → main (no version bump) |
| 2 | Full Release | Yes | Semver release with pre-flight, changelog, tag, GitHub release |
| 3 | Plugin Release | Monorepo only | Release a single plugin (scoped tag, scoped changelog) |
| 4 | Release Status | Yes | Show unreleased commits, last tag, changelog drift |
| 5 | Dry Run | Yes | Simulate full release without committing, tagging, or pushing |
| 6 | Changelog Preview | Yes | Generate and display changelog entry without committing |

### Context Annotations

Menu descriptions are enriched with live context:
- **Quick Merge:** dirty tree warning or clean tree commit count
- **Full Release:** suggested version with commit breakdown
- **Plugin Release:** count of plugins with unreleased changes
- **Release Status:** last tag and commit count since

## Phase 1: Context Detection

Runs automatically when `/release` is invoked (~2-3 seconds):

1. **Monorepo check:** `bash detect-unreleased.sh <repo-path>`
   - Determines if monorepo (has marketplace.json with plugins)
   - Captures list of plugins with unreleased changes
2. **Git state:** `git status --porcelain` + `git log --oneline -1`
   - Clean/dirty tree, current branch, last commit
3. **Last tag:** `git describe --tags --abbrev=0`
   - Most recent tag for version suggestion
4. **Commit analysis:** `git log <last-tag>..HEAD --oneline`
   - Count and categorize commits (feat/fix/chore/breaking)
   - Auto-suggest next version (major/minor/patch)

### Internal Variables

| Variable | Type | Source |
|----------|------|--------|
| `is_monorepo` | bool | detect-unreleased.sh exit code |
| `unreleased_plugins` | list | detect-unreleased.sh output |
| `is_dirty` | bool | git status |
| `current_branch` | string | git branch |
| `last_tag` | string | git describe |
| `suggested_version` | string | suggest-version.sh |
| `commit_summary` | string | suggest-version.sh |

## Mode Workflows

### Quick Merge (unchanged from Mode 1)

Stage → generate commit message → display for review → GO gate → commit → merge to main → push → return to testing.

### Full Release (refined from Mode 2)

1. **Version prompt:** Show auto-suggested version, let user accept or override
2. **Phase 1 — Pre-flight (PARALLEL):** Three agents (test-runner, docs-auditor, git-preflight) launched simultaneously
3. **Phase 2 — Preparation:** bump-version.sh + generate-changelog.sh → show diff → GO gate
4. **Phase 3 — Release:** commit → merge → tag → push → GitHub release
5. **Phase 4 — Verification:** verify-release.sh

### Plugin Release (refined from Mode 3)

1. **Plugin picker:** `AskUserQuestion` with unreleased plugins (replaces numbered text list)
2. **Version prompt:** Auto-suggested per-plugin based on scoped commits
3. **Phases 1-4:** Same as Full Release but scoped to `plugins/<name>/`

### Release Status (NEW)

Read-only, no approval gates:
1. Show current branch and last tag
2. List commits since last tag (categorized)
3. If monorepo: per-plugin breakdown
4. Show suggested next version
5. Check changelog drift (CHANGELOG.md vs commits)

### Dry Run (NEW)

Mirrors Full Release but skips destructive operations:
1. Run Phase 1 (pre-flight agents) — same parallel checks
2. Run Phase 2 (preparation) — bump version + generate changelog
3. Show full diff of what WOULD be committed
4. Show what tag and GitHub release WOULD be created
5. Revert all changes: `git checkout -- .`
6. Report: "Dry run complete. No changes were made."

### Changelog Preview (NEW)

Lightweight, focused:
1. Determine version (auto-suggest or ask)
2. Run `generate-changelog.sh --preview` (stdout only, no file write)
3. Display formatted changelog entry
4. Ask: "Save this to CHANGELOG.md?" (yes/no)
5. If yes: write and stage. If no: discard.

## File Changes

| File | Change Type | Description |
|------|-------------|-------------|
| `commands/release.md` | **Rewrite** | Context detection + menu + all six modes |
| `skills/release-detection/SKILL.md` | **Update** | Route to /release menu (not direct mode execution) |
| `scripts/suggest-version.sh` | **New** | Analyze commits, output suggested semver bump |
| `scripts/generate-changelog.sh` | **Minor** | Add `--preview` flag (stdout only) |
| `.claude-plugin/plugin.json` | **Bump** | Version 1.1.0 → 1.2.0 |
| `README.md` | **Update** | Document new menu-driven UX |

### Unchanged Files

- `scripts/bump-version.sh`
- `scripts/detect-unreleased.sh`
- `scripts/detect-test-runner.sh`
- `scripts/verify-release.sh`
- `agents/test-runner.md`
- `agents/docs-auditor.md`
- `agents/git-preflight.md`
- `templates/changelog-entry.template`

## New Script: suggest-version.sh

```
Usage: bash suggest-version.sh <repo-path> [--plugin <name>]

Logic:
  1. Find last tag (vX.Y.Z or <plugin>/vX.Y.Z)
  2. Parse commits since tag
  3. BREAKING CHANGE or "!:" → major bump
  4. feat: → minor bump
  5. Otherwise → patch bump
  6. Output: <suggested-version> <feat-count> <fix-count> <other-count>
     e.g., "1.2.0 3 1 2"
```

## Release Detection Skill Change

**Current behavior:** Parses natural language → invokes `/release` with mode-specific arguments
**New behavior:** Parses natural language → invokes `/release` (no args) → menu handles everything

The skill can extract context hints (if user says "release home-assistant-dev v2.0.0", note this), but the menu is always presented.
