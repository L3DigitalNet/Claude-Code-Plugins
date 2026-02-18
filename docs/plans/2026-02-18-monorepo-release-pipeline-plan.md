# Monorepo Release Pipeline Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Extend the release-pipeline plugin (v1.0.0 → v1.1.0) to support per-plugin releases in monorepo marketplaces.

**Architecture:** Add a `--plugin <name>` flag to existing scripts. When `/release` is invoked in a monorepo context without a plugin name, an interactive picker shows unreleased changes. A new `detect-unreleased.sh` script powers the picker. Scoping flows through prompt injection to existing agents — no agent definition changes needed.

**Tech Stack:** Bash (scripts), Markdown (commands/skills), JSON (manifests)

---

### Task 1: Create detect-unreleased.sh

This new script is the foundation of monorepo support. It scans `marketplace.json` for all plugins, finds the latest `plugin-name/v*` tag for each, and counts unreleased commits.

**Files:**
- Create: `plugins/release-pipeline/scripts/detect-unreleased.sh`

**Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

# detect-unreleased.sh — List plugins with unreleased changes.
#
# Usage: detect-unreleased.sh <repo-path>
# Output: TSV lines: plugin-name  current-version  commit-count  last-tag
# Exit:   0 = at least one plugin found, 1 = not a monorepo or error

# ---------- Argument handling ----------

if [[ $# -lt 1 ]]; then
  echo "Usage: detect-unreleased.sh <repo-path>" >&2
  exit 1
fi

REPO="$1"

if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

# ---------- Monorepo detection ----------

MARKETPLACE="$REPO/.claude-plugin/marketplace.json"
if [[ ! -f "$MARKETPLACE" ]]; then
  echo "Error: no marketplace.json found at $MARKETPLACE" >&2
  exit 1
fi

plugin_count=$(python3 -c "
import json, sys
d = json.load(open('$MARKETPLACE'))
plugins = d.get('plugins', [])
print(len(plugins))
")

if [[ "$plugin_count" -lt 2 ]]; then
  echo "Error: not a monorepo (fewer than 2 plugins)" >&2
  exit 1
fi

# ---------- Scan each plugin ----------

found=0

python3 -c "
import json
d = json.load(open('$MARKETPLACE'))
for p in d['plugins']:
    print(p['name'] + '\t' + p.get('version', '0.0.0') + '\t' + p.get('source', ''))
" | while IFS=$'\t' read -r name version source; do
  # Resolve source path (strip leading ./)
  plugin_dir="$REPO/${source#./}"

  if [[ ! -d "$plugin_dir" ]]; then
    continue
  fi

  # Find latest tag matching plugin-name/v*
  last_tag=""
  last_tag=$(git -C "$REPO" tag -l "${name}/v*" --sort=-v:refname | head -1) || true

  # Count commits since that tag touching this plugin's directory
  rel_path="${source#./}"
  if [[ -n "$last_tag" ]]; then
    commit_count=$(git -C "$REPO" log "${last_tag}..HEAD" --oneline -- "$rel_path" | wc -l)
  else
    commit_count=$(git -C "$REPO" log --oneline -- "$rel_path" | wc -l)
    last_tag="(none)"
  fi

  # Only output plugins with unreleased changes
  if [[ "$commit_count" -gt 0 ]]; then
    printf '%s\t%s\t%s\t%s\n' "$name" "$version" "$commit_count" "$last_tag"
    found=$((found + 1))
  fi
done

# Note: 'found' is in a subshell due to the pipe. Re-check by counting output lines.
# The caller checks if stdout is empty to determine if there are unreleased changes.

exit 0
```

**Step 2: Make executable and verify it runs**

Run: `chmod +x plugins/release-pipeline/scripts/detect-unreleased.sh`
Run: `bash plugins/release-pipeline/scripts/detect-unreleased.sh /home/chris/projects/Claude-Code-Plugins`
Expected: TSV output listing plugin(s) with commits since their last `plugin-name/v*` tag (likely `release-pipeline` itself since we're modifying it). If no plugins have unreleased changes, empty output is valid.

**Step 3: Verify error handling**

Run: `bash plugins/release-pipeline/scripts/detect-unreleased.sh /tmp`
Expected: Exit 1 with "no marketplace.json found"

**Step 4: Commit**

```bash
git add plugins/release-pipeline/scripts/detect-unreleased.sh
git commit -m "feat(release-pipeline): add detect-unreleased.sh for monorepo scanning"
```

---

### Task 2: Add --plugin flag to bump-version.sh

Extend the existing `bump-version.sh` to accept `--plugin <name>`. When provided, it bumps `plugins/<name>/.claude-plugin/plugin.json` AND the matching entry in `.claude-plugin/marketplace.json`. Skips all other version files.

**Files:**
- Modify: `plugins/release-pipeline/scripts/bump-version.sh`

**Step 1: Add --plugin argument parsing after line 26 (after `VERSION="$2"`)**

Insert before the "Strip leading v" line:

```bash
# ---------- Optional --plugin flag ----------
PLUGIN=""
if [[ $# -ge 4 && "$3" == "--plugin" ]]; then
  PLUGIN="$4"
fi
```

**Step 2: Add plugin-scoped version bump logic before the summary section**

After the `__init__.py` section (line ~100) and before `# ---------- Summary ----------`, add:

```bash
# ---------- 6. Monorepo plugin mode ----------
if [[ -n "$PLUGIN" ]]; then
  # 6a. Bump plugins/<name>/.claude-plugin/plugin.json
  bump_file "$REPO/plugins/$PLUGIN/.claude-plugin/plugin.json" \
    "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

  # Also try manifest.json (some plugins use this name)
  bump_file "$REPO/plugins/$PLUGIN/.claude-plugin/manifest.json" \
    "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

  # 6b. Bump the matching entry in marketplace.json
  MARKETPLACE="$REPO/.claude-plugin/marketplace.json"
  if [[ -f "$MARKETPLACE" ]]; then
    local_file="$MARKETPLACE"
    before=$(md5sum "$local_file")

    # Use python for precise JSON manipulation (sed is fragile for array entries)
    python3 -c "
import json, sys
with open('$local_file') as f:
    data = json.load(f)
for p in data.get('plugins', []):
    if p['name'] == '$PLUGIN':
        p['version'] = '$VERSION'
        break
with open('$local_file', 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
"

    after=$(md5sum "$local_file")
    if [[ "$before" != "$after" ]]; then
      echo "Updated: $local_file (plugin: $PLUGIN)"
      updated=$((updated + 1))
    fi
  fi
fi
```

**Step 3: Guard the root-level version files in plugin mode**

Wrap sections 1–5 (lines 63–100) in an `if [[ -z "$PLUGIN" ]]; then ... fi` block so they only run in single-repo mode.

The full logical structure becomes:
```
if PLUGIN is empty:
    bump root pyproject.toml, package.json, Cargo.toml, plugin.json, __init__.py
else:
    bump plugins/PLUGIN/plugin.json + marketplace.json
fi
```

**Step 4: Verify plugin mode works**

Run: `bash plugins/release-pipeline/scripts/bump-version.sh /home/chris/projects/Claude-Code-Plugins 99.99.99 --plugin release-pipeline`
Expected: "Updated: .../plugins/release-pipeline/.claude-plugin/plugin.json" and "Updated: .../.claude-plugin/marketplace.json (plugin: release-pipeline)"
Verify: `grep '"version"' plugins/release-pipeline/.claude-plugin/plugin.json` shows `"version": "99.99.99"`

**Step 5: Revert test changes**

Run: `git checkout -- plugins/release-pipeline/.claude-plugin/plugin.json .claude-plugin/marketplace.json`
Verify: versions restored to 1.0.0

**Step 6: Verify single-repo mode still works**

Run: `bash plugins/release-pipeline/scripts/bump-version.sh /home/chris/projects/Claude-Code-Plugins 99.99.99`
Expected: bumps the root `.claude-plugin/plugin.json` (marketplace manifest — this is the existing behavior since there's no root pyproject.toml/package.json)
Revert: `git checkout -- .`

**Step 7: Commit**

```bash
git add plugins/release-pipeline/scripts/bump-version.sh
git commit -m "feat(release-pipeline): add --plugin flag to bump-version.sh"
```

---

### Task 3: Add --plugin flag to generate-changelog.sh

Extend `generate-changelog.sh` to accept `--plugin <name>`. When provided: collect only commits touching `plugins/<name>/**` since the last `plugin-name/v*` tag, and write the changelog to `plugins/<name>/CHANGELOG.md`.

**Files:**
- Modify: `plugins/release-pipeline/scripts/generate-changelog.sh`

**Step 1: Add --plugin argument parsing after line 25 (after `VERSION="$2"`)**

```bash
# ---------- Optional --plugin flag ----------
PLUGIN=""
if [[ $# -ge 4 && "$3" == "--plugin" ]]; then
  PLUGIN="$4"
fi
```

**Step 2: Replace the "Collect commits" section (lines 40-51) with plugin-aware logic**

Replace:
```bash
# ---------- Collect commits ----------

# Find the last tag. If none exists, use all commits.
last_tag=""
if git -C "$REPO" describe --tags --abbrev=0 &>/dev/null; then
  last_tag="$(git -C "$REPO" describe --tags --abbrev=0)"
fi

if [[ -n "$last_tag" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges)"
else
  commits="$(git -C "$REPO" log --oneline --no-merges)"
fi
```

With:
```bash
# ---------- Collect commits ----------

last_tag=""
path_filter=""

if [[ -n "$PLUGIN" ]]; then
  # Plugin mode: find the last plugin-name/v* tag and filter by plugin path
  last_tag=$(git -C "$REPO" tag -l "${PLUGIN}/v*" --sort=-v:refname | head -1) || true
  path_filter="plugins/${PLUGIN}/"
else
  # Single-repo mode: find the last v* tag
  if git -C "$REPO" describe --tags --abbrev=0 &>/dev/null; then
    last_tag="$(git -C "$REPO" describe --tags --abbrev=0)"
  fi
fi

if [[ -n "$last_tag" && -n "$path_filter" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges -- "$path_filter")"
elif [[ -n "$last_tag" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges)"
elif [[ -n "$path_filter" ]]; then
  commits="$(git -C "$REPO" log --oneline --no-merges -- "$path_filter")"
else
  commits="$(git -C "$REPO" log --oneline --no-merges)"
fi
```

**Step 3: Change the changelog output path for plugin mode**

Replace the line (around line 104):
```bash
changelog="$REPO/CHANGELOG.md"
```

With:
```bash
if [[ -n "$PLUGIN" ]]; then
  changelog="$REPO/plugins/$PLUGIN/CHANGELOG.md"
else
  changelog="$REPO/CHANGELOG.md"
fi
```

**Step 4: Verify plugin mode**

Run: `bash plugins/release-pipeline/scripts/generate-changelog.sh /home/chris/projects/Claude-Code-Plugins 2.2.0 --plugin home-assistant-dev`
Expected: changelog entry printed to stdout with commits since `home-assistant-dev/v2.1.0` that touch `plugins/home-assistant-dev/`. File created at `plugins/home-assistant-dev/CHANGELOG.md`.

**Step 5: Clean up test output**

Run: `rm -f plugins/home-assistant-dev/CHANGELOG.md`

**Step 6: Verify single-repo mode unchanged**

Run: `bash plugins/release-pipeline/scripts/generate-changelog.sh /tmp/test-repo 1.0.0` (expect error — just verifying arg parsing doesn't break)

**Step 7: Commit**

```bash
git add plugins/release-pipeline/scripts/generate-changelog.sh
git commit -m "feat(release-pipeline): add --plugin flag to generate-changelog.sh"
```

---

### Task 4: Add --plugin flag to verify-release.sh

Extend `verify-release.sh` to accept `--plugin <name>`. When provided, check for `plugin-name/vX.Y.Z` tag format instead of `vX.Y.Z`.

**Files:**
- Modify: `plugins/release-pipeline/scripts/verify-release.sh`

**Step 1: Add --plugin argument parsing after line 21 (after `VERSION="$2"`)**

```bash
# ---------- Optional --plugin flag ----------
PLUGIN=""
if [[ $# -ge 4 && "$3" == "--plugin" ]]; then
  PLUGIN="$4"
fi
```

**Step 2: Change the TAG construction (line 28-29)**

Replace:
```bash
VERSION="${VERSION#v}"
TAG="v${VERSION}"
```

With:
```bash
VERSION="${VERSION#v}"
if [[ -n "$PLUGIN" ]]; then
  TAG="${PLUGIN}/v${VERSION}"
else
  TAG="v${VERSION}"
fi
```

**Step 3: Verify the script parses correctly**

Run: `bash plugins/release-pipeline/scripts/verify-release.sh /home/chris/projects/Claude-Code-Plugins 2.1.0 --plugin home-assistant-dev`
Expected: checks for tag `home-assistant-dev/v2.1.0` — should show PASS for tag exists, PASS for GitHub release, etc. (these were created earlier in this session)

**Step 4: Verify single-repo mode unchanged**

Run: `bash plugins/release-pipeline/scripts/verify-release.sh /home/chris/projects/Claude-Code-Plugins 999.0.0`
Expected: FAIL for tag `v999.0.0` not existing — confirms old behavior works

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/verify-release.sh
git commit -m "feat(release-pipeline): add --plugin flag to verify-release.sh"
```

---

### Task 5: Add Mode 3 (Plugin Release) to commands/release.md

This is the core command change. Add a third mode that activates in monorepo context with a plugin name.

**Files:**
- Modify: `plugins/release-pipeline/commands/release.md`

**Step 1: Update the frontmatter description**

Change the description to:
```
description: "Release pipeline — no args for quick merge (testing->main), provide version for full release, or provide plugin name + version for monorepo per-plugin release (e.g., /release home-assistant-dev v2.2.0)."
```

**Step 2: Update Argument Parsing section**

Replace the current Argument Parsing section with:

```markdown
## Argument Parsing

1. Extract a version from the arguments matching pattern `v?[0-9]+\.[0-9]+\.[0-9]+`.
2. Extract a plugin name — any non-version word before or after the version.
3. If no plugin name was given, check for monorepo context:
   - Run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-unreleased.sh .`
   - If the script succeeds (monorepo detected) and outputs results, present an interactive picker.
   - If not a monorepo, or user declines to pick a plugin, fall through to existing modes.

**Routing:**

- **No version, no plugin** → Mode 1: Quick Merge
- **Version, no plugin, not monorepo** → Mode 2: Full Release
- **Version + plugin name** → Mode 3: Plugin Release
- **Version, no plugin, IS monorepo** → Interactive picker → Mode 3: Plugin Release
```

**Step 3: Add the interactive picker section after Argument Parsing**

```markdown
## Interactive Plugin Picker (Monorepo)

When a version is provided but no plugin name in a monorepo context:

1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-unreleased.sh .` and capture the output.
2. Present the results to the user:

```
UNRELEASED CHANGES DETECTED
============================
  1. home-assistant-dev  v2.1.0  (3 commits since home-assistant-dev/v2.1.0)
  2. release-pipeline    v1.0.0  (12 commits since release-pipeline/v1.0.0)
  3. linux-sysadmin-mcp  v1.0.0  (0 unreleased — skip)

Which plugin are you releasing? Enter the number or name:
```

3. Wait for user selection. Use the selected plugin name for Mode 3.
4. If no plugins have unreleased changes, report "All plugins are up to date" and stop.
```

**Step 4: Add Mode 3 section after Mode 2**

````markdown
---

## Mode 3: Plugin Release (monorepo per-plugin)

Use this mode when a plugin name is identified (directly or via picker). This runs scoped pre-flight checks, bumps versions in the plugin manifest and marketplace.json, generates a per-plugin changelog, creates a scoped git tag, and creates a GitHub release.

### Phase 1 — Scoped Pre-flight (Parallel)

Launch THREE Task agents simultaneously **in a single message**:

**Agent A — Test Runner (scoped):**
```
subagent_type: "general-purpose"
description: "Run test suite for plugin release pre-flight"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/test-runner.md and follow them exactly.
  SCOPE: Only run tests for the plugin at plugins/<plugin-name>/.
  Look for tests in these locations (in order):
  1. plugins/<plugin-name>/tests/
  2. plugins/<plugin-name>/test/
  3. If no plugin-specific tests exist, fall back to repo-level test detection.
  Report results in the format specified in those instructions.
```

**Agent B — Docs Auditor (scoped):**
```
subagent_type: "general-purpose"
description: "Audit plugin documentation for release readiness"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/docs-auditor.md and follow them exactly.
  SCOPE: Only audit documentation in plugins/<plugin-name>/ (README.md, docs/).
  Also check the plugin entry in .claude-plugin/marketplace.json for version consistency.
  The target release version is <version>.
  Report results in the format specified in those instructions.
```

**Agent C — Git Pre-flight (scoped):**
```
subagent_type: "general-purpose"
description: "Git pre-flight check for plugin release"
model: haiku
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/git-preflight.md and follow them exactly.
  Check git state for the current repository.
  The target tag is <plugin-name>/v<version> (note: plugin-scoped tag, NOT v<version>).
  Report results in the format specified in those instructions.
```

**After all three return:** display consolidated pre-flight report (same format as Mode 2). If any FAIL → STOP.

### Phase 2 — Scoped Preparation (Sequential)

**Step 1 — Bump versions (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --plugin <plugin-name>
```

This bumps:
- `plugins/<plugin-name>/.claude-plugin/plugin.json`
- The matching entry in `.claude-plugin/marketplace.json`

**Step 2 — Generate changelog (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name>
```

This collects only commits touching `plugins/<plugin-name>/` since the last `<plugin-name>/v*` tag and writes to `plugins/<plugin-name>/CHANGELOG.md`.

**Step 3 — Show diff summary:**

```bash
git diff --stat
```

Display: version changes, changelog preview (first 30 lines), marketplace.json change.

**Step 4 — Approval gate:**

Print: **"Review the changes above. Reply GO to proceed with the <plugin-name> v<version> release, or anything else to abort."**

WAIT for user response. If not approval → run `git checkout -- .` and report "Release aborted. All changes reverted." and stop.

### Phase 3 — Scoped Release (Sequential)

Execute each command sequentially. If any command fails, STOP and report with rollback suggestion.

```bash
# Scoped git add — only the plugin directory and marketplace.json
git add plugins/<plugin-name>/ .claude-plugin/marketplace.json
git commit -m "Release <plugin-name> v<version>"
```

```bash
git checkout main
git pull origin main
git merge testing --no-ff -m "Release <plugin-name> v<version>"
```

```bash
git tag -a "<plugin-name>/v<version>" -m "Release <plugin-name> v<version>"
```

```bash
git push origin main --tags
```

```bash
git checkout testing
```

Then create the GitHub release:

```bash
gh release create "<plugin-name>/v<version>" --title "<plugin-name> v<version>" --notes "<changelog entry>"
```

### Phase 4 — Scoped Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version> --plugin <plugin-name>
```

### Final Summary

```
RELEASE COMPLETE: <plugin-name> v<version>
==========================================
Tests:     <result from Phase 1>
Docs:      <result from Phase 1>
Git:       <result from Phase 1>
Version:   plugins/<plugin-name>/.claude-plugin/plugin.json, marketplace.json
Changelog: plugins/<plugin-name>/CHANGELOG.md
Tag:       <plugin-name>/v<version>
GitHub:    <release URL>
Branch:    <current branch>
```
````

**Step 5: Update the Rollback Suggestions table**

Add plugin-scoped rollback entries:

```markdown
| Phase 3 (Before push, plugin) | Scoped commit/merge/tag failed | `git tag -d <name>/v<version> && git checkout testing && git reset HEAD~1` |
| Phase 3 (After push, plugin) | Push succeeded | Manual: `git push origin --delete <name>/v<version>`. May need revert commit. |
```

**Step 6: Verify the markdown renders correctly**

Read the file to confirm no formatting issues.

**Step 7: Commit**

```bash
git add plugins/release-pipeline/commands/release.md
git commit -m "feat(release-pipeline): add Mode 3 (Plugin Release) to release command"
```

---

### Task 6: Update release-detection skill for plugin names

Extend the skill to recognize plugin names in natural language (e.g., "Release home-assistant-dev v2.2.0").

**Files:**
- Modify: `plugins/release-pipeline/skills/release-detection/SKILL.md`

**Step 1: Update the Parse the Request section**

Replace the current content with:

```markdown
## Parse the Request

1. **Look for a version number**: pattern `v?[0-9]+\.[0-9]+\.[0-9]+`
   - Found → Full Release mode (or Plugin Release mode if plugin name also found)
   - Not found → Quick Merge mode

2. **Look for a plugin name**: if the user mentions a specific plugin name (e.g., "release home-assistant-dev v2.2.0", "ship linux-sysadmin-mcp 1.0.1"), extract it. Plugin names are typically hyphenated lowercase words that match entries in `.claude-plugin/marketplace.json`.

3. **Look for a repo name**: if the user mentions a specific repo (e.g., "for HA-Light-Controller"), note it — you may need to `cd` to that repo first.

## Execute

Follow the exact same workflow as the `/release` command defined in `${CLAUDE_PLUGIN_ROOT}/commands/release.md`.

Read that file and follow its instructions with:
- The parsed version (if any)
- The plugin name (if any — this triggers Mode 3)
- The repo context (if any)
```

**Step 2: Update the frontmatter description**

Change the triggers description to include plugin-specific phrases:
```yaml
description: >
  Detect release intent in natural language and route to the /release command.
  Triggers on: "Release vX.Y.Z", "cut a release", "ship it", "merge to main",
  "deploy to production", "push to main", "release for <repo>",
  "release <plugin-name> vX.Y.Z", "ship <plugin-name>".
```

**Step 3: Commit**

```bash
git add plugins/release-pipeline/skills/release-detection/SKILL.md
git commit -m "feat(release-pipeline): update release-detection skill for plugin names"
```

---

### Task 7: Update README.md with monorepo usage

Add monorepo usage examples to the release-pipeline README.

**Files:**
- Modify: `plugins/release-pipeline/README.md`

**Step 1: Add a "Plugin Release (Monorepo)" section after "Full Release"**

```markdown
## Plugin Release (Monorepo)

Release a single plugin from a marketplace monorepo:

```
/release home-assistant-dev v2.2.0
```

Or say: "Release home-assistant-dev v2.2.0", "ship linux-sysadmin-mcp 1.0.1"

If you provide a version without a plugin name in a monorepo, an interactive picker shows plugins with unreleased changes.

**What it does:**

| Phase | Action | Parallel? |
|-------|--------|-----------|
| 1. Pre-flight | Run plugin tests, audit plugin docs, check git state | Yes (3 agents) |
| 2. Preparation | Bump plugin.json + marketplace.json, generate per-plugin changelog | Sequential |
| 3. Release | Scoped commit, merge, tag (`plugin-name/vX.Y.Z`), push, GitHub release | Sequential |
| 4. Verification | Confirm scoped tag, release page, notes | Sequential |

**Tag format:** `plugin-name/vX.Y.Z` (e.g., `home-assistant-dev/v2.1.0`)

**Scoped changes:** Only `plugins/<name>/` and `.claude-plugin/marketplace.json` are staged — other plugins are untouched.
```

**Step 2: Commit**

```bash
git add plugins/release-pipeline/README.md
git commit -m "docs(release-pipeline): add monorepo usage to README"
```

---

### Task 8: Bump plugin version to v1.1.0

Update the release-pipeline plugin version in both manifests.

**Files:**
- Modify: `plugins/release-pipeline/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Step 1: Bump plugin.json**

Change `"version": "1.0.0"` to `"version": "1.1.0"` in `plugins/release-pipeline/.claude-plugin/plugin.json`.

**Step 2: Bump marketplace.json**

Change the release-pipeline entry version from `"1.0.0"` to `"1.1.0"` in `.claude-plugin/marketplace.json`.

**Step 3: Validate marketplace**

Run: `bash /home/chris/projects/Claude-Code-Plugins/scripts/validate-marketplace.sh`
Expected: validation passes

**Step 4: Commit**

```bash
git add plugins/release-pipeline/.claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "chore(release-pipeline): bump version to v1.1.0"
```

---

### Task 9: End-to-end verification

Run the full verification suite to ensure everything works.

**Step 1: Verify detect-unreleased.sh output**

Run: `bash plugins/release-pipeline/scripts/detect-unreleased.sh /home/chris/projects/Claude-Code-Plugins`
Expected: TSV output showing release-pipeline with unreleased commits (the work we just did)

**Step 2: Verify bump-version.sh --plugin mode (dry run)**

Run: `bash plugins/release-pipeline/scripts/bump-version.sh /home/chris/projects/Claude-Code-Plugins 99.99.99 --plugin release-pipeline`
Expected: "Updated" messages for plugin.json and marketplace.json
Revert: `git checkout -- .`

**Step 3: Verify generate-changelog.sh --plugin mode (dry run)**

Run: `bash plugins/release-pipeline/scripts/generate-changelog.sh /home/chris/projects/Claude-Code-Plugins 99.99.99 --plugin release-pipeline`
Expected: changelog entry with recent commits printed to stdout, file created at `plugins/release-pipeline/CHANGELOG.md`
Revert: `rm -f plugins/release-pipeline/CHANGELOG.md`

**Step 4: Verify verify-release.sh --plugin mode**

Run: `bash plugins/release-pipeline/scripts/verify-release.sh /home/chris/projects/Claude-Code-Plugins 2.1.0 --plugin home-assistant-dev`
Expected: PASS for tag exists, GitHub release exists (created earlier)

**Step 5: Verify single-repo mode unchanged**

Run: `bash plugins/release-pipeline/scripts/bump-version.sh /home/chris/projects/Claude-Code-Plugins 99.99.99`
Expected: bumps root plugin.json (existing behavior preserved)
Revert: `git checkout -- .`

**Step 6: Final commit (if any test artifacts remain)**

Clean up any test artifacts: `git checkout -- . && git clean -fd plugins/release-pipeline/CHANGELOG.md 2>/dev/null || true`

---

## Summary

| Task | Files | Type |
|------|-------|------|
| 1 | `scripts/detect-unreleased.sh` | New script |
| 2 | `scripts/bump-version.sh` | Add `--plugin` flag |
| 3 | `scripts/generate-changelog.sh` | Add `--plugin` flag |
| 4 | `scripts/verify-release.sh` | Add `--plugin` flag |
| 5 | `commands/release.md` | Add Mode 3 |
| 6 | `skills/release-detection/SKILL.md` | Recognize plugin names |
| 7 | `README.md` | Monorepo docs |
| 8 | `plugin.json` + `marketplace.json` | Version bump |
| 9 | (all scripts) | End-to-end verification |

**Estimated commits:** 8 (one per task, task 9 is verification only)
