# Mode 5: Dry Run

# Loaded by the release command router after the user selects "Dry Run".
# Context variables from Phase 0 are available: suggested_version, feat_count, fix_count,
# other_count, last_tag, is_monorepo, unreleased_plugins.

Simulates a Full Release without committing, tagging, or pushing. Uses --dry-run and --preview
flags that prevent file writes — no mutations occur and no revert step is needed.

**First, output this banner:**

```
⚠ DRY RUN — no changes will be committed, tagged, or pushed
  Pre-flight failures are non-blocking in this mode — they show what would fail in a real release.
```

## Step 0 — Version Selection

If monorepo (`is_monorepo` is true), first ask the dry-run scope using **AskUserQuestion**:
- question: `"Dry run scope?"`
- header: `"Scope"`
- options:
  1. label: `"Repo-wide"`, description: `"Simulate a full-repository release"`
  2. label: `"Single plugin"`, description: `"Simulate release scoped to one plugin"` → if selected, show the same plugin picker used in Mode 3 Step 0

Then present the auto-suggested version (same as Mode 2 Step 0), scoped to the selection.

## Phase 1 — Pre-flight (Parallel)

**IMPORTANT:** Before making any tool calls, output this line: `"Launching pre-flight checks for v<version> in parallel (dry run)..."`

Same as Mode 2 Phase 1 — launch all three agents. Display consolidated report.

If ANY agent reports FAIL → report the failures. Do NOT stop here (this is a dry run — show what would fail).

## Phase 2 — Simulated Preparation

Both steps use flags that prevent file writes, making Dry Run a true preview without any mutations.

**Step 1 — Preview version bump:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --dry-run
```

(For plugin dry run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/bump-version.sh . <version> --plugin <plugin-name> --dry-run`)

Capture stdout and display it immediately — it contains one `Would update: <file>` line per file plus a `N file(s) would be updated` summary. No files are changed.

**Step 2 — Preview changelog:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --preview
```

(For plugin dry run: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name> --preview`)

Capture stdout — it contains the full changelog entry that would be added. Display it in a fenced block immediately after running. The `--preview` flag skips writing to `CHANGELOG.md`.

**Step 3 — Show complete simulation summary:**

Display:
- Files that would be updated (from Step 1 output)
- The changelog entry that would be added (from Step 2 output, already shown above)
- Tag that would be created: `v<version>` (or `<plugin-name>/v<version>`)
- GitHub release that would be created (title and notes)

## Phase 3 — Done

Display: **"Dry run complete. No file changes were made to the repository."**

If pre-flight had failures, remind: "⚠ Pre-flight issues were detected — see above. Fix them before a real release."
