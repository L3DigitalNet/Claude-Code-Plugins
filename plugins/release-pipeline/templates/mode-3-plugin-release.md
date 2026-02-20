# Mode 3: Plugin Release

# Loaded by the release command router after the user selects "Plugin Release".
# Context variables from Phase 0 are available: is_monorepo, unreleased_plugins,
# current_branch, last_tag, commit_count.

Scoped release for a single plugin. Uses scoped tags, scoped changelog, and only stages plugin files.

## Step 0 — Plugin Selection

Use **AskUserQuestion** to present the plugin picker:

- question: `"Which plugin are you releasing?"`
- header: `"Plugin"`
- options: Build from `unreleased_plugins` list. For each plugin:
  - label: `"<plugin-name>"`
  - description: `"v<current-version> → <commit-count> commits since <last-tag>"`

If `unreleased_plugins` is empty, show all plugins from marketplace.json instead with description: `"v<current-version> (no unreleased changes detected)"`.

## Step 1 — Version Selection

Run suggest-version.sh scoped to the selected plugin:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-version.sh . --plugin <plugin-name>
```

Also read `plugins/<plugin-name>/.claude-plugin/plugin.json` to get `current_version`.

Build options for **AskUserQuestion**:
- If `suggested_version != current_version` AND `current_version` is semver-greater: use `current_version` as option 1 (Recommended) and `suggested_version` as option 2.
- Otherwise: use `suggested_version` as option 1 (Recommended).
- Always include `"Custom version"` as the last option.

Use **AskUserQuestion**:
- question: `"Which version for <plugin-name>?"`
- header: `"Version"`
- options (up to 3):
  1. If recommended is commit-based: label: `"v<suggested_version> (Recommended)"`, description: `"Commit-based: <feat_count> feat, <fix_count> fix, <other_count> other since <last_tag>"`
     If recommended is plugin.json: label: `"v<current_version> (Recommended)"`, description: `"Current plugin.json — already set to this value"`
  2. *(only if both versions differ)* If other is commit-based: label: `"v<suggested_version>"`, description: `"Commit-based: <feat_count> feat, <fix_count> fix since last tag"`
     If other is plugin.json: label: `"v<current_version>"`, description: `"Current plugin.json version — already set to this value"`
  3. label: `"Custom version"`, description: `"Enter a specific version number"`

If "Custom version" selected:
1. Ask: `"Enter the version (e.g., 1.2.0 or v1.2.0):"`
2. Validate the input matches `X.Y.Z` format (with optional leading `v`, where X/Y/Z are non-negative integers).
3. If invalid, say: `"That doesn't look like a valid version (expected X.Y.Z, e.g. 1.2.3). Please try again:"` and re-ask once.
4. If still invalid, STOP: `"Invalid version format. Please re-run /release and enter a version like 1.2.3."`

Normalize the version to `X.Y.Z` without leading `v` for scripts. Use `<plugin-name>/vX.Y.Z` for tags and `vX.Y.Z` for display.

## Phase 1 — Scoped Pre-flight (Parallel)

**IMPORTANT:** Before making any tool calls, output this line: `"Launching pre-flight checks for <plugin-name> v<version> in parallel..."`

Then launch THREE Task agents simultaneously **in a single message** (all three tool calls in one response):

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

**After all three return:**

Display consolidated pre-flight report (same format as Mode 2).

**Before proceeding, verify each agent's status explicitly:**
- Locate the `TEST RESULTS`, `DOCS AUDIT`, and `GIT PRE-FLIGHT` blocks in each agent's output.
- If any block is missing, incomplete, or ambiguous → treat it as FAIL.
- If **ANY agent reports FAIL** → STOP immediately. Display the failure details and suggest: "Fix the issues above and re-run `/release`." Do NOT proceed to Phase 2.
- If **all PASS or WARN** (and all three blocks are present) → proceed to Phase 2.

## Phase 2 — Scoped Preparation (Sequential)

**Step 1 — Bump versions (plugin-scoped):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --plugin <plugin-name>
```

This bumps `plugins/<plugin-name>/.claude-plugin/plugin.json` and the matching entry in `.claude-plugin/marketplace.json`.

**Step 2 — Preview changelog (plugin-scoped, no write yet):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name> --preview
```

This collects only commits touching `plugins/<plugin-name>/` since the last `<plugin-name>/v*` tag. Capture stdout — it contains the full changelog entry that will be added. Does not write to CHANGELOG.md.

Then show the diff for version files already updated:

```bash
git diff --stat
```

Display both in a single pre-gate summary (matching Mode 2 format):
- "Version files updated:" — from the diff (plugin.json, marketplace.json)
- "Changelog entry that will be added:" — from the preview output, in a fenced block

**Step 3 — Approval gate:**

Use **AskUserQuestion**:
- question: `"Proceed with the <plugin-name> v<version> release?"`
- header: `"Release"`
- options:
  1. label: `"Proceed"`, description: `"Write changelog, commit, tag, merge to main, and push"`
  2. label: `"Abort"`, description: `"Cancel — revert version bumps (git checkout -- .)"`
If "Abort" → run `git checkout -- .` and report "Release aborted. Version bumps reverted." and stop.

**Step 4 — Write changelog (after approval):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name>
```

This writes the entry to `plugins/<plugin-name>/CHANGELOG.md`. No output needed — it was previewed in Step 2.

## Phase 3 — Scoped Release (Sequential)

Execute each command sequentially. If any command fails, STOP and report with rollback suggestion.

```bash
git add plugins/<plugin-name>/ .claude-plugin/marketplace.json
git commit -m "Release <plugin-name> v<version>"
```

```bash
git checkout main
git pull origin main
git merge testing --no-ff -m "Release <plugin-name> v<version>"
```

**Tag reconciliation:**

Run tag reconciliation before creating the local tag:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/reconcile-tags.sh . "<plugin-name>/v<version>"
```

Capture the first line of stdout as `tag_status`. Branch based on value:
- `MISSING` or `LOCAL_ONLY`: proceed to `git tag -a` step normally
- `BOTH` or `REMOTE_ONLY`: skip `git tag -a` entirely — tag already exists on remote; proceed directly to `git push origin main --tags`

```bash
git tag -a "<plugin-name>/v<version>" -m "Release <plugin-name> v<version>"
```

```bash
git push origin main --tags
```

```bash
git checkout testing
```

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/api-retry.sh 3 1000 -- \
  gh release create "<plugin-name>/v<version>" --title "<plugin-name> v<version>" --notes "<changelog entry>"
```

## Phase 4 — Scoped Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version> --plugin <plugin-name>
```

## Final Summary

Use the verification outcome from Phase 4 to determine the header (same rule as Mode 2):
- Exit 0: `RELEASE COMPLETE: <plugin-name> v<version>`
- Exit 1: `RELEASE COMPLETE ⚠: <plugin-name> v<version>` with post-block note

```
RELEASE COMPLETE: <plugin-name> v<version>
==========================================
Tests:     ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Docs:      ✓ PASS | ⚠ WARN | ✗ FAIL — <one-line summary from Phase 1>
Git:       ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Version:   plugins/<plugin-name>/.claude-plugin/plugin.json, marketplace.json
Changelog: plugins/<plugin-name>/CHANGELOG.md
Tag:       <plugin-name>/v<version>
GitHub:    <release URL>
Branch:    <current branch>
```

Get the release URL with:

```bash
gh release view "<plugin-name>/v<version>" --json url -q '.url'
```
