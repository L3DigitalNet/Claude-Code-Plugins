# Mode 4: Release Status

# Loaded by the release command router after the user selects "Release Status".
# Context variables from Phase 0 are available: current_branch, last_tag, commit_count,
# suggested_version, feat_count, fix_count, other_count, is_dirty, is_monorepo, unreleased_plugins.

Shows the current release state without making any changes.

## Step 1 — Repository Overview

Display:

```
RELEASE STATUS
==============
Branch:     <current_branch>
Last tag:   <last_tag>
Commits:    <commit_count> since <last_tag>
Suggested:  v<suggested_version> (<feat_count> feat, <fix_count> fix, <other_count> other)
Tree:       clean | dirty (<N> uncommitted files)
```

## Step 2 — Commit Breakdown

List commits since last tag, categorized:

```bash
git log <last_tag>..HEAD --oneline --no-merges
```

Display them grouped by conventional commit type (feat, fix, chore, docs, etc.). If there are more than 15 commits, show 15 and add: `…and <N> more commits`.

## Step 3 — Monorepo Breakdown (if applicable)

If `is_monorepo` is true, show per-plugin status from the `unreleased_plugins` list:

```
PLUGIN STATUS
=============
  home-assistant-dev   v2.1.0   3 commits since home-assistant-dev/v2.1.0
  release-pipeline     v1.3.0   8 commits since release-pipeline/v1.3.0
  linux-sysadmin-mcp   v1.0.0   (up to date)
```

## Step 4 — Changelog Drift Check

Check if CHANGELOG.md exists. If it does, compare the latest version header in CHANGELOG.md against `last_tag`:

```bash
head -20 CHANGELOG.md
```

If the latest `## [X.Y.Z]` in CHANGELOG.md matches the last tag version → "Changelog is up to date."
If it doesn't → "⚠ Changelog may be out of date — last entry is vA.B.C but last tag is vX.Y.Z."

## Done

Use **AskUserQuestion** to offer a follow-up action rather than forcing the user to re-type `/release`:

- question: `"What would you like to do next?"`
- header: `"Next step"`
- Build options dynamically:
  - Always include:
    1. label: `"Full Release"`, description: `"Semver release with pre-flight, changelog, tag, and GitHub release"`
    2. label: `"Dry Run"`, description: `"Simulate a release without any changes"`
    3. label: `"Done"`, description: `"Exit — no further action needed"`
  - If `is_monorepo`: insert after Full Release: label: `"Plugin Release"`, description: `"Release a single plugin with scoped tag"`

If "Done" → display: "Status check complete." and stop.
Otherwise → load the corresponding mode template from `${CLAUDE_PLUGIN_ROOT}/templates/` and follow it.
