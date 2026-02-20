# Mode 6: Changelog Preview

# Loaded by the release command router after the user selects "Changelog Preview".
# Context variables from Phase 0 are available: suggested_version, feat_count, fix_count,
# other_count, last_tag, is_monorepo, unreleased_plugins.

Generates and displays a changelog entry without modifying any files (unless the user opts in).

## Step 1 — Version Selection

Same as Mode 2 Step 0 — present auto-suggested version via AskUserQuestion.

For monorepo: first ask if this is repo-wide or per-plugin using AskUserQuestion. If per-plugin, use suggest-version.sh with --plugin flag.

## Step 2 — Generate Preview

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --preview
```

(For plugin: `bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version> --plugin <plugin-name> --preview`)

Display the full formatted changelog entry.

## Step 3 — Save Option

Use **AskUserQuestion**:
- question: `"Save this changelog entry to CHANGELOG.md?"`
- header: `"Save"`
- options:
  1. label: `"Yes, save it"`, description: `"Write the entry to CHANGELOG.md and stage the file"`
  2. label: `"No, discard"`, description: `"Don't save — this was just a preview"`

If "Yes":
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/generate-changelog.sh . <version>
git add CHANGELOG.md
```
(For plugin: add `--plugin <plugin-name>` and stage `plugins/<plugin-name>/CHANGELOG.md`)

Display: "Changelog entry saved and staged."

If "No":
Display: "Preview discarded. No changes made."
