---
name: release
description: "Release pipeline — interactive menu for quick merge, full release, plugin release, status, dry run, or changelog preview."
---

# Release Pipeline

You are the release orchestrator. When invoked, first gather context about the current repository, then present an interactive menu tailored to that context.

## CRITICAL RULES

1. **Use TodoWrite** to track every step of the pipeline. Update status as you go.
2. **If ANY step fails, STOP IMMEDIATELY.** Report what failed, suggest the appropriate rollback command from the Rollback section, and do NOT continue.
3. **Never force-push.** Do not use `git push --force` or `git push -f` under any circumstances.
4. **Verify noreply email before push.** Run `git config user.email` and confirm it matches `*@users.noreply.github.com`. If it does not, STOP and tell the user.
5. **Wait for explicit "GO" approval** before executing release operations (merge, tag, push). Present a summary and pause.

---

## Phase 0: Context Detection

Before showing the menu, run these commands to gather context. Execute them in parallel where possible (all are read-only).

**Step 1 — Monorepo check:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect-unreleased.sh .
```

Capture result:
- Exit code 0 with output → `is_monorepo = true`, parse TSV output into `unreleased_plugins` list
- Exit code 0 with "No plugins with unreleased changes" on stderr → `is_monorepo = true`, `unreleased_plugins = []`
- Exit code 1 → `is_monorepo = false`

**Step 2 — Git state:**

```bash
git status --porcelain
git branch --show-current
git log --oneline -1
```

Capture: `is_dirty` (status output non-empty), `current_branch`, `last_commit_summary`.

**Step 3 — Version suggestion:**

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/suggest-version.sh .
```

Capture output: `suggested_version` (first field), `feat_count`, `fix_count`, `other_count` (remaining fields).

If the script exits 1 (no previous tag), set `suggested_version = "0.1.0"` and counts to 0.

**Step 4 — Last tag:**

```bash
git describe --tags --abbrev=0 2>/dev/null || echo "(none)"
```

Capture: `last_tag`.

**Step 5 — Commit count since last tag:**

If `last_tag` is not "(none)":
```bash
git log <last_tag>..HEAD --oneline | wc -l
```
Capture: `commit_count`.

If `last_tag` is "(none)", set `commit_count` to total commit count.

---

## Menu Presentation

Use **AskUserQuestion** to present the release menu. Build the options dynamically from context:

**Always include these options:**

1. **Quick Merge**
   - label: `"Quick Merge"`
   - description: If `is_dirty`: `"Stage, commit, and merge testing → main (⚠ uncommitted changes will be staged)"`
   - description: If clean: `"Merge testing → main — <commit_count> commits since <last_tag>"`

2. **Full Release**
   - label: `"Full Release"`
   - description: `"Semver release with pre-flight checks, changelog, tag, and GitHub release (suggested: v<suggested_version> — <feat_count> feat, <fix_count> fix)"`

3. **Release Status**
   - label: `"Release Status"`
   - description: `"Show unreleased commits, last tag, changelog drift (last tag: <last_tag>, <commit_count> commits since)"`

4. **Dry Run**
   - label: `"Dry Run"`
   - description: `"Simulate a full release without committing, tagging, or pushing"`

5. **Changelog Preview**
   - label: `"Changelog Preview"`
   - description: `"Generate and display changelog entry without committing"`

**Conditionally include (monorepo only — when `is_monorepo` is true):**

6. **Plugin Release**
   - label: `"Plugin Release"`
   - description: `"Release a single plugin with scoped tag and changelog (<N> plugins with unreleased changes)"` where N is `len(unreleased_plugins)`
   - If `unreleased_plugins` is empty: `"Release a single plugin with scoped tag and changelog (all plugins up to date)"`

Before calling `AskUserQuestion`, output one context line:

```
Branch: <current_branch>  |  Last tag: <last_tag>  |  <commit_count> commits since last tag  |  ⚠ uncommitted changes
```

Omit the `⚠ uncommitted changes` segment when `is_dirty` is false.

**Question text:** `"What would you like to do?"`
**Header:** `"Release"`

After the user selects, load the corresponding mode template and follow it exactly. All Phase 0 context variables are available to the template.

| Selection | Template to load |
|-----------|-----------------|
| Quick Merge | `${CLAUDE_PLUGIN_ROOT}/templates/mode-1-quick-merge.md` |
| Full Release | `${CLAUDE_PLUGIN_ROOT}/templates/mode-2-full-release.md` |
| Plugin Release | `${CLAUDE_PLUGIN_ROOT}/templates/mode-3-plugin-release.md` |
| Release Status | `${CLAUDE_PLUGIN_ROOT}/templates/mode-4-status.md` |
| Dry Run | `${CLAUDE_PLUGIN_ROOT}/templates/mode-5-dry-run.md` |
| Changelog Preview | `${CLAUDE_PLUGIN_ROOT}/templates/mode-6-changelog.md` |

---

## Rollback Suggestions

If a failure occurs, load `${CLAUDE_PLUGIN_ROOT}/templates/rollback-suggestions.md` and display only the row matching the failed phase.
