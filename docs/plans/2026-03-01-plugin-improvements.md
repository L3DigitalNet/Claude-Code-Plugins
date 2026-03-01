# Plugin Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix six high/medium-impact issues found across five plugins: close enforcement gaps in plugin-review, fix metadata drift in agent-orchestrator and home-assistant-dev, add --dry-run to autonomous-refactor, annotate qt-suite skills by binding, and make release-pipeline marketplace name configurable.

**Architecture:** Tasks 1-4 are targeted file edits (scripts, plugin.json, README). Task 5 (autonomous-refactor --dry-run) is a command-markdown change that adds a new flag parsed in Phase 0 and an early exit after Phase 2. Task 6 (qt-suite binding annotation) is a README table column addition. Task 7 (release-pipeline env var) is a 2-line script change.

**Tech Stack:** Bash, Python (inline in shell scripts), Markdown command files, JSON manifests.

---

### Task 1: Make validate-agent-frontmatter.sh blocking

**Context:** `plugins/plugin-review/scripts/validate-agent-frontmatter.sh` currently exits 0 even when disallowed tools are found — it only warns. This violates P7 and P9 (read-only analyst boundary). A warn-only hook is insufficient; the write still proceeds.

The fix is to exit 2 (Claude Code's blocking exit code for PreToolUse/PostToolUse hooks) when disallowed tools are detected, and emit a blocking-format message instead of a warning. Also update README Known Issues to remove the caveat that blocking enforcement requires "a manual pre-completion check."

**Files:**
- Modify: `plugins/plugin-review/scripts/validate-agent-frontmatter.sh` (last ~15 lines)
- Modify: `plugins/plugin-review/README.md` (Known Issues, line ~177)
- Modify: `plugins/plugin-review/CHANGELOG.md`

**Step 1: Edit the script exit behavior**

Replace the final block of `validate-agent-frontmatter.sh`. The current block (lines ~70–end) is:

```bash
if [ -n "$DISALLOWED" ]; then
  echo ""
  echo "⚠️ [P9] Agent frontmatter: disallowed tool(s) found in $FILE_PATH"
  echo "  Disallowed: $DISALLOWED"
  echo "  Analyst agents must only have read-only tools: Read, Grep, Glob (+ optional WebFetch, WebSearch, TodoWrite, NotebookRead)."
  echo "  Remove disallowed tools from the 'tools:' line in the frontmatter."
  echo ""
fi

exit 0
```

Replace with:

```bash
if [ -n "$DISALLOWED" ]; then
  echo ""
  echo "🚫 [P9] Blocked: disallowed tool(s) in analyst agent frontmatter: $FILE_PATH"
  echo "  Disallowed: $DISALLOWED"
  echo "  Analyst agents must only have read-only tools: Read, Grep, Glob"
  echo "  (optionally: WebFetch, WebSearch, TodoWrite, NotebookRead)."
  echo "  Remove disallowed tools from the 'tools:' line before proceeding."
  echo ""
  exit 2
fi

exit 0
```

**Step 2: Update README Known Issues**

In `plugins/plugin-review/README.md`, find:

```
- `validate-agent-frontmatter.sh` is warn-only, not blocking. An analyst agent gaining write tools will generate a warning but the write will proceed. Full blocking enforcement requires a manual pre-completion check.
```

Replace with:

```
- `validate-agent-frontmatter.sh` blocks writes (exit 2) when disallowed tools are detected in analyst agent YAML frontmatter. The hook fires PostToolUse, so the write has already occurred; the exit 2 surfaces the violation immediately so it can be reverted before completion.
```

**Step 3: Add CHANGELOG entry**

In `plugins/plugin-review/CHANGELOG.md`, add under a new `## [Unreleased]` section (or the next version):

```markdown
### Fixed

- `validate-agent-frontmatter.sh` now exits 2 (blocking) instead of 0 (warn-only) when disallowed write tools are detected in analyst agent YAML frontmatter — closes the P9 enforcement gap documented in Known Issues
```

**Step 4: Verify the change manually**

```bash
# Check the exit line is now conditional
grep -n "exit" plugins/plugin-review/scripts/validate-agent-frontmatter.sh
# Expected output: lines with "exit 2" (in the if block) and "exit 0" (at end for clean path)
```

**Step 5: Commit**

```bash
git add plugins/plugin-review/scripts/validate-agent-frontmatter.sh \
        plugins/plugin-review/README.md \
        plugins/plugin-review/CHANGELOG.md
git commit -m "fix(plugin-review): make validate-agent-frontmatter.sh blocking (exit 2)

Closes P9 enforcement gap: disallowed write tools in analyst agent
frontmatter now block (exit 2) instead of warn-only (exit 0).
PostToolUse fires after the write, so the violation is surfaced
immediately for manual revert — same semantics as doc-write-tracker.sh.
"
```

---

### Task 2: Extend doc-write-tracker.sh to cover hooks.json

**Context:** `plugins/plugin-review/scripts/doc-write-tracker.sh` categorizes files as "implementation" by checking against `impl_dirs`. The current tuple uses `'hooks/scripts/'` but NOT `'hooks/'` broadly — so `hooks/hooks.json` modifications are invisible to the tracker, violating P6 (Documentation Co-mutation).

The fix is to replace `'hooks/scripts/'` with `'hooks/'` in the `impl_dirs` tuple, which is a broader match that catches both `hooks/hooks.json` and `hooks/scripts/*.sh`.

**Files:**
- Modify: `plugins/plugin-review/scripts/doc-write-tracker.sh` (Python block, `impl_dirs` line)
- Modify: `plugins/plugin-review/README.md` (Known Issues, ~line 176)
- Modify: `plugins/plugin-review/CHANGELOG.md`

**Step 1: Edit impl_dirs in the script**

Find the Python block that defines `impl_dirs` (inside the `python3 -c "..."` heredoc). The current line reads:

```python
impl_dirs = ('commands/', 'agents/', 'skills/', 'scripts/', 'hooks/scripts/', 'src/', 'templates/')
```

Replace with:

```python
impl_dirs = ('commands/', 'agents/', 'skills/', 'scripts/', 'hooks/', 'src/', 'templates/')
```

The change: `'hooks/scripts/'` → `'hooks/'`. The substring check `any(d in file_path for d in impl_dirs)` means `'hooks/'` matches both `hooks/hooks.json` and `hooks/scripts/foo.sh`.

**Step 2: Update README Known Issues**

In `plugins/plugin-review/README.md`, find:

```
- The `doc-write-tracker.sh` hook does not track writes to `hooks/hooks.json`. Modifications to hook configuration without documentation updates will not trigger the co-mutation warning.
```

Replace with:

```
- The `doc-write-tracker.sh` hook tracks any file under `hooks/` (including `hooks/hooks.json`) as an implementation file. Hook configuration changes without corresponding documentation updates will trigger the co-mutation warning.
```

**Step 3: Add CHANGELOG entry**

In `plugins/plugin-review/CHANGELOG.md`, add to the same `## [Unreleased]` section as Task 1:

```markdown
- `doc-write-tracker.sh` now treats all `hooks/` files (including `hooks/hooks.json`) as implementation files, triggering the P6 co-mutation warning when hook config changes without documentation updates
```

**Step 4: Verify the change**

```bash
grep -n "impl_dirs" plugins/plugin-review/scripts/doc-write-tracker.sh
# Expected: impl_dirs = ('commands/', 'agents/', 'skills/', 'scripts/', 'hooks/', 'src/', 'templates/')
```

**Step 5: Commit**

```bash
git add plugins/plugin-review/scripts/doc-write-tracker.sh \
        plugins/plugin-review/README.md \
        plugins/plugin-review/CHANGELOG.md
git commit -m "fix(plugin-review): extend doc-write-tracker to cover hooks/hooks.json

Replace 'hooks/scripts/' with 'hooks/' in impl_dirs so modifications
to hooks/hooks.json trigger the P6 co-mutation warning alongside other
implementation file changes.
"
```

---

### Task 3: Fix agent-orchestrator plugin.json author

**Context:** `plugins/agent-orchestrator/.claude-plugin/plugin.json` has `"author": {"name": "Agent Orchestrator"}` — it's missing the `url` field and uses a generic descriptive name instead of the publisher identity. All other plugins use `"L3Digital-Net"` with the GitHub URL. The marketplace.json already has the correct author; only plugin.json needs fixing.

**Files:**
- Modify: `plugins/agent-orchestrator/.claude-plugin/plugin.json`

**Step 1: Edit plugin.json**

Read the current file, then replace the author block:

```json
"author": {
  "name": "Agent Orchestrator"
}
```

With:

```json
"author": {
  "name": "L3Digital-Net",
  "url": "https://github.com/L3Digital-Net"
}
```

**Step 2: Verify**

```bash
python3 -c "import json; d=json.load(open('plugins/agent-orchestrator/.claude-plugin/plugin.json')); print(d['author'])"
# Expected: {'name': 'L3Digital-Net', 'url': 'https://github.com/L3Digital-Net'}
```

**Step 3: Commit**

```bash
git add plugins/agent-orchestrator/.claude-plugin/plugin.json
git commit -m "fix(agent-orchestrator): standardize plugin.json author to L3Digital-Net"
```

---

### Task 4: Fix home-assistant-dev skill count in plugin.json

**Context:** `plugins/home-assistant-dev/.claude-plugin/plugin.json` description says "19 skills" but the actual skills table in the README has 27 entries. The description is shown in marketplace listings — it's user-facing.

**Files:**
- Modify: `plugins/home-assistant-dev/.claude-plugin/plugin.json`

**Step 1: Edit plugin.json description**

Find the description field. It currently reads:

```
"Comprehensive Home Assistant integration development toolkit with 19 skills, MCP server..."
```

Change `19 skills` to `27 skills`.

**Step 2: Verify**

```bash
grep "skills" plugins/home-assistant-dev/.claude-plugin/plugin.json
# Expected: "...with 27 skills..."
```

**Step 3: Commit**

```bash
git add plugins/home-assistant-dev/.claude-plugin/plugin.json
git commit -m "fix(home-assistant-dev): correct skill count from 19 to 27 in plugin.json"
```

---

### Task 5: Add --dry-run flag to autonomous-refactor

**Context:** `plugins/autonomous-refactor/commands/refactor.md` has 4 phases: Phase 1 (Snapshot — baseline test + metrics), Phase 2 (Analyze — rank opportunities), Phase 3 (Refactor Loop — apply changes), Phase 4 (Report). There is no way to preview opportunities without committing to a full session.

Adding `--dry-run` (or `--preview`) means: run Phases 1+2 fully, then display the ranked opportunities list and exit — no worktrees created, no code changes applied.

**Files:**
- Modify: `plugins/autonomous-refactor/commands/refactor.md`
  - Setup section: add `--dry-run` flag parsing
  - Between Phase 2 and Phase 3: add dry-run exit block
- Modify: `plugins/autonomous-refactor/README.md` (Commands table and Usage section)
- Modify: `plugins/autonomous-refactor/CHANGELOG.md`

**Step 1: Read the Setup section of refactor.md**

Open `plugins/autonomous-refactor/commands/refactor.md` and find the "Setup" / "Parse arguments" block. It currently reads:

```
Parse arguments from the invocation:
- `--max-changes=N` → integer, default 10
- Remaining non-flag arguments → target file paths
```

Add the `--dry-run` line:

```
Parse arguments from the invocation:
- `--max-changes=N` → integer, default 10
- `--dry-run` → boolean, default false. When true: run Phases 1 and 2 only, display ranked opportunities, then exit without creating worktrees or applying any changes.
- Remaining non-flag arguments → target file paths
```

Also add to the `python3 -c "..."` state initialisation block:

```python
'dry_run': False,  # set to True when --dry-run flag is present
```

And store the flag after parsing:

```python
# After parsing --max-changes, add:
DRY_RUN=false  # replace with true if --dry-run was in the invocation
```

**Step 2: Add dry-run exit between Phase 2 and Phase 3**

Find the boundary between Phase 2 (Analyze) and Phase 3 (Refactor Loop). Phase 2 ends with a ranked opportunities list being written to state. Immediately before the `## Phase 3` heading, insert:

```markdown
## Dry-Run Exit

**If `--dry-run` was specified**, stop here. Do not proceed to Phase 3.

Display:

```
Dry-run complete. N opportunities identified (max changes: M).

Ranked opportunities:
  1. [HIGH]   <file>:<line> — <opportunity description>
  2. [MEDIUM] <file>:<line> — <opportunity description>
  ...

No changes applied. Run without --dry-run to execute.
```

Exit cleanly after displaying this output.
```

**Step 3: Update README.md**

In `plugins/autonomous-refactor/README.md`, find the Commands table. Add `--dry-run` to the `/refactor` row description:

```
| `/refactor [file] [--max-changes=N] [--dry-run]` | Run autonomous refactoring. `--dry-run` runs Phases 1–2 and shows ranked opportunities without applying changes. |
```

Also add a note in the Usage section (or How It Works) explaining the dry-run workflow.

**Step 4: Add CHANGELOG entry**

```markdown
### Added

- `--dry-run` flag: runs Phases 1 and 2 (baseline snapshot + opportunity analysis) and displays ranked opportunities without creating worktrees or applying any changes
```

**Step 5: Verify by reading the file**

```bash
grep -n "dry.run\|DRY_RUN\|dry_run" plugins/autonomous-refactor/commands/refactor.md
# Expected: at least 3 hits — flag definition, state init, exit block
```

**Step 6: Commit**

```bash
git add plugins/autonomous-refactor/commands/refactor.md \
        plugins/autonomous-refactor/README.md \
        plugins/autonomous-refactor/CHANGELOG.md
git commit -m "feat(autonomous-refactor): add --dry-run flag for opportunity preview

Runs Phases 1 and 2 (baseline + analysis) and displays ranked
opportunities without creating worktrees or applying any changes.
Mirrors the --dry-run pattern in repo-hygiene and release-pipeline.
"
```

---

### Task 6: Annotate qt-suite skills table with Python/C++ applicability

**Context:** `plugins/qt-suite/README.md` skills table has no column indicating whether each skill applies to Python (PySide6/PyQt6), C++/Qt, or both. Known Issues says "C++/Qt skill coverage is partial; primary focus is Python bindings." A C++ developer can't tell which of the 16 skills are relevant.

Add a `Binding` column to the Skills table. Values: `Python`, `C++/Qt`, `Both`.

Applicability map (based on skill content):
- `qt-architecture`: Both
- `qt-signals-slots`: Both
- `qt-layouts`: Both
- `qt-model-view`: Both
- `qt-threading`: Both
- `qt-styling`: Both
- `qt-resources`: Both
- `qt-dialogs`: Both
- `qt-packaging`: Python (PyInstaller, Briefcase)
- `qt-debugging`: Both
- `qt-qml`: Both
- `qt-settings`: Both
- `qt-bindings`: Python (PySide6 vs PyQt6 differences)
- `qtest-patterns`: Both (QTest for C++, pytest-qt for Python)
- `qt-coverage-workflow`: Both (gcov/lcov + coverage.py)
- `qt-pilot-usage`: Python (Qt Pilot MCP server is Python-based)

**Files:**
- Modify: `plugins/qt-suite/README.md` (Skills table)

**Step 1: Replace the Skills table header**

Current:
```markdown
| Skill | Loaded when |
|-------|-------------|
```

Replace with:
```markdown
| Skill | Binding | Loaded when |
|-------|---------|-------------|
```

**Step 2: Add Binding column values to every row**

Replace the entire Skills table (16 rows) with the annotated version:

```markdown
| Skill | Binding | Loaded when |
|-------|---------|-------------|
| `qt-architecture` | Both | Structuring a Qt app, QApplication setup, project layout |
| `qt-signals-slots` | Both | Connecting signals, defining custom signals, cross-thread communication |
| `qt-layouts` | Both | Arranging widgets, resize behavior, QSplitter, layout debugging |
| `qt-model-view` | Both | QAbstractTableModel, QTableView, QSortFilterProxyModel, delegates |
| `qt-threading` | Both | QThread, QRunnable, thread safety, keeping UI responsive |
| `qt-styling` | Both | QSS stylesheets, theming, dark/light mode, QPalette |
| `qt-resources` | Both | .qrc files, pyrcc6, embedding icons and assets |
| `qt-dialogs` | Both | QDialog, QMessageBox, QFileDialog, custom dialogs |
| `qt-packaging` | Python | PyInstaller, Briefcase, platform deployment, CI builds |
| `qt-debugging` | Both | Qt crashes, widget visibility, event loop, threading issues |
| `qt-qml` | Both | QML/Qt Quick, QQmlApplicationEngine, exposing Python to QML |
| `qt-settings` | Both | QSettings, persistent preferences, window geometry, recent files |
| `qt-bindings` | Python | PySide6 vs PyQt6 differences, PyQt5 migration guide |
| `qtest-patterns` | Both | Writing QTest (C++), pytest-qt (Python), or QML TestCase tests |
| `qt-coverage-workflow` | Both | Working with coverage gaps, gcov, lcov, or coverage.py |
| `qt-pilot-usage` | Python | Headless GUI testing, widget interaction, Qt Pilot MCP usage |
```

**Step 3: Verify**

```bash
grep -c "| Both \|| Python \|| C++/Qt " plugins/qt-suite/README.md
# Expected: 16
```

**Step 4: Commit**

```bash
git add plugins/qt-suite/README.md
git commit -m "docs(qt-suite): add Binding column to skills table (Python/Both)

Annotates each of the 16 skills with binding applicability so C++/Qt
developers know which skills apply to their project. 14 skills apply
to both bindings; 2 are Python-only (qt-packaging, qt-bindings,
qt-pilot-usage).
"
```

---

### Task 7: Make release-pipeline marketplace name configurable via env var

**Context:** `plugins/release-pipeline/scripts/sync-local-plugins.sh` hardcodes `MARKETPLACE="l3digitalnet-plugins"` and `CACHE_DIR="$HOME/.claude/plugins/cache/l3digitalnet-plugins"`. This breaks for anyone who forks the repo under a different marketplace name.

The fix is two lines: make both values derive from `RELEASE_PIPELINE_MARKETPLACE` env var with a fallback to `l3digitalnet-plugins`. Also update README Known Issues.

**Files:**
- Modify: `plugins/release-pipeline/scripts/sync-local-plugins.sh` (lines 22–24)
- Modify: `plugins/release-pipeline/README.md` (Known Issues)
- Modify: `plugins/release-pipeline/CHANGELOG.md`

**Step 1: Edit sync-local-plugins.sh**

Find lines 22–24:
```bash
CACHE_DIR="$HOME/.claude/plugins/cache/l3digitalnet-plugins"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
MARKETPLACE="l3digitalnet-plugins"
```

Replace with:
```bash
MARKETPLACE="${RELEASE_PIPELINE_MARKETPLACE:-l3digitalnet-plugins}"
CACHE_DIR="$HOME/.claude/plugins/cache/$MARKETPLACE"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
```

Note the reordering: `MARKETPLACE` must be defined before `CACHE_DIR` uses it.

**Step 2: Update README Known Issues**

Find:
```
- `sync-local-plugins.sh` is hardcoded to the `l3digitalnet-plugins` marketplace. It will not sync plugins from a differently named marketplace without modifying the script.
```

Replace with:
```
- `sync-local-plugins.sh` defaults to the `l3digitalnet-plugins` marketplace. Set `RELEASE_PIPELINE_MARKETPLACE=<name>` in your environment to override for differently named marketplaces.
```

**Step 3: Add CHANGELOG entry**

```markdown
### Fixed

- `sync-local-plugins.sh` marketplace name is now configurable via `RELEASE_PIPELINE_MARKETPLACE` environment variable (default: `l3digitalnet-plugins`)
```

**Step 4: Verify the change**

```bash
grep -n "MARKETPLACE\|CACHE_DIR" plugins/release-pipeline/scripts/sync-local-plugins.sh | head -5
# Expected: MARKETPLACE="${RELEASE_PIPELINE_MARKETPLACE:-l3digitalnet-plugins}"
#           CACHE_DIR="$HOME/.claude/plugins/cache/$MARKETPLACE"
```

**Step 5: Commit**

```bash
git add plugins/release-pipeline/scripts/sync-local-plugins.sh \
        plugins/release-pipeline/README.md \
        plugins/release-pipeline/CHANGELOG.md
git commit -m "feat(release-pipeline): make marketplace name configurable via env var

RELEASE_PIPELINE_MARKETPLACE overrides the hardcoded 'l3digitalnet-plugins'
value in sync-local-plugins.sh. Defaults to the existing value so there
is no behavior change for current users.
"
```
