# Mode 2: Full Release

# Loaded by the release command router after the user selects "Full Release".
# Context variables from Phase 0 are available: suggested_version, feat_count, fix_count,
# other_count, last_tag, commit_count, current_branch.

Full semver release with parallel pre-flight checks, version bumps, changelog, git tag, and GitHub release.

## Step 0 — Version Selection

Present the auto-suggested version to the user:

Use **AskUserQuestion**:
- question: `"Which version should this release be?"`
- header: `"Version"`
- options:
  1. label: `"v<suggested_version> (Recommended)"`, description: `"Based on commits: <feat_count> feat, <fix_count> fix, <other_count> other since <last_tag>"`
  2. label: `"Custom version"`, description: `"Enter a specific version number"`

If "Custom version" selected:
1. Ask: `"Enter the version (e.g., 1.2.0 or v1.2.0):"`
2. Validate the input matches `X.Y.Z` format (with optional leading `v`, where X/Y/Z are non-negative integers).
3. If invalid, say: `"That doesn't look like a valid version (expected X.Y.Z, e.g. 1.2.3). Please try again:"` and re-ask once.
4. If still invalid, STOP: `"Invalid version format. Please re-run /release and enter a version like 1.2.3."`

Normalize the version to `X.Y.Z` without leading `v` for scripts. Use `vX.Y.Z` for tags and display.

## Phase 1 — Pre-flight (Parallel)

**IMPORTANT:** Before making any tool calls, output this line: `"Launching pre-flight checks for v<version> in parallel..."`

Then launch THREE Task agents simultaneously **in a single message** (all three tool calls in one response):

**Agent A — Test Runner:**
```
subagent_type: "general-purpose"
description: "Run test suite for release pre-flight"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/test-runner.md and follow them exactly.
  Run the full test suite for the repository at the current working directory.
  Report results in the format specified in those instructions.
```

**Agent B — Docs Auditor:**
```
subagent_type: "general-purpose"
description: "Audit documentation for release readiness"
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/docs-auditor.md and follow them exactly.
  Audit documentation in the current repository.
  The target release version is <version>.
  Report results in the format specified in those instructions.
```

**Agent C — Git Pre-flight:**
```
subagent_type: "general-purpose"
description: "Git pre-flight check"
model: haiku
prompt: |
  Read the instructions at ${CLAUDE_PLUGIN_ROOT}/agents/git-preflight.md and follow them exactly.
  Check git state for the current repository.
  The target tag is v<version>.
  Report results in the format specified in those instructions.
```

**After all three return:**

Display each agent's summary in a consolidated pre-flight report. Use ✓ for PASS, ⚠ for WARN, and ✗ for FAIL:

```
PRE-FLIGHT RESULTS
==================
<✓|✗> Tests:  PASS|FAIL  — <one-line summary>
<✓|⚠|✗> Docs: PASS|WARN|FAIL  — <one-line summary>
<✓|✗> Git:   PASS|FAIL  — <one-line summary>
```

**Before proceeding, verify each agent's status explicitly:**
- Locate the `TEST RESULTS`, `DOCS AUDIT`, and `GIT PRE-FLIGHT` blocks in each agent's output.
- If any block is missing, incomplete, or ambiguous → treat it as FAIL.
- If **ANY agent reports FAIL** → STOP immediately. Display the failure details and suggest: "Fix the issues above and re-run `/release`." Do NOT proceed to Phase 2.
- If **all PASS or WARN** (and all three blocks are present) → proceed to Phase 2.

## Phase 2 — Preparation (Sequential)

**Step 1 — Bump versions:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version>
```

If this exits 1, STOP — no version strings found means the release is malformed.

**Step 2 — Preview changes (no writes yet):**

Run changelog preview (does not write CHANGELOG.md):

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --preview
```

Then show the diff for files already updated (version bumps only):

```bash
git diff --stat
```

Display both in a single pre-gate summary:
- "Version files updated:" — from the diff
- "Changelog entry that will be added:" — from the preview output, in a fenced block

**Step 3 — Approval gate:**

Use **AskUserQuestion**:
- question: `"Proceed with the v<version> release?"`
- header: `"Release"`
- options:
  1. label: `"Proceed"`, description: `"Write changelog, commit, tag, merge to main, and push"`
  2. label: `"Abort"`, description: `"Cancel — revert version bumps (git checkout -- .)"`
If "Abort" → run `git checkout -- .` and report "Release aborted. Version bumps reverted." and stop.

**Step 4 — Write changelog (after approval):**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version>
```

This writes the entry to CHANGELOG.md. No output needed — it was previewed in Step 2.

## Phase 3 — Release (Sequential)

Execute each command sequentially. If any command fails, STOP and report with rollback suggestion.

```bash
git add -A
git commit -m "Release v<version>"
```

```bash
git checkout main
git pull origin main
git merge testing --no-ff -m "Release v<version>"
```

```bash
git tag -a "v<version>" -m "Release v<version>"
```

```bash
git push origin main --tags
```

```bash
git checkout testing
```

Then create the GitHub release. Use the changelog entry generated in Phase 2 as the release notes:

```bash
gh release create "v<version>" --title "v<version>" --notes "<changelog entry>"
```

## Phase 4 — Verification

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/verify-release.sh . <version>
```

Display the verification report. If verification fails → WARN the user but do NOT attempt automatic rollback (the release is already public).

## Final Summary

Display a completion report. Use the verification outcome from Phase 4 to determine the header:
- If verification passed (exit 0): use `RELEASE COMPLETE: v<version>`
- If verification had failures (exit 1): use `RELEASE COMPLETE ⚠: v<version>` and append a note after the block: "⚠ Some post-release verification checks failed — see Phase 4 output above. Verify manually."

```
RELEASE COMPLETE: v<version>
============================
Tests:     ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Docs:      ✓ PASS | ⚠ WARN | ✗ FAIL — <one-line summary from Phase 1>
Git:       ✓ PASS | ✗ FAIL — <one-line summary from Phase 1>
Version:   <files bumped>
Changelog: updated
Tag:       v<version>
GitHub:    <release URL>
Branch:    <current branch>
```

Get the release URL with:

```bash
gh release view "v<version>" --json url -q '.url'
```
