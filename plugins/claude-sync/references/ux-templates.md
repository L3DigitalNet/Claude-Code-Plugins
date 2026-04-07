# UX & Output Templates

This file defines all output templates and UX behavior for Claude Sync. Templates are the contract between the plugin logic and the user — follow them exactly.

---

## Design principles

- **Show intent before acting.** Before any import applies changes, summarize the full plan and require explicit confirmation. The user always sees the diff and install plan before a single file is touched.
- **Progressive output.** Each category is reported as it completes. Output is not buffered until the end.
- **Backup before anything.** The first action of any import is writing the backup archive. If the backup fails, the import halts. The user's environment is never modified before the backup succeeds.
- **Fail loudly, skip cleanly.** Errors get full treatment: what failed, why, and what to do. Categories that can't be captured or applied are skipped with a stated reason, never silently dropped.
- **Consistent visual grammar.** Fixed symbols used throughout so the user can scan output at a glance without reading prose.
- **Decisions use the ask-user tool.** All confirmation points use Claude Code's built-in ask-user tool with labeled selectable options. Plain text narration is used for progress reporting only. These two modes never mix.
- **The plugin identity is always visible.** `CLAUDE SYNC` appears in every output header.

---

## Visual grammar reference

| Symbol | Meaning |
|---|---|
| ✅ | Captured / applied / installed / synced successfully |
| ❌ | Error — action required |
| ⚠️ | Warning — non-blocking, review recommended |
| 🔄 | In progress |
| ⏭️ | Skipped — reason stated |
| 🔧 | Installing dependency |
| 🏷️ | Added to exclude list |
| 🗑️ | Removed |
| 📤 | Export command header |
| 📥 | Import command header |
| 📦 | Snapshot or archive file |
| 🟢 | Final verdict: complete |
| 🟡 | Final verdict: complete with warnings |
| 🔴 | Final verdict: failed or incomplete |

---

## Template 0 — First-run setup

**When:** Either command is run for the first time and no Claude Sync configuration is found in the global CLAUDE.md.

**Purpose:** Establish the three required values before proceeding. Runs once per machine.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔁  CLAUDE SYNC — FIRST-RUN SETUP
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

No configuration found. Three values are needed before proceeding.

SYNC PATH
  Where snapshots are written and read from.
  Must be accessible from all machines that use Claude Sync
  (e.g. an NFS mount, a shared network drive).

SECRET STORE PATH
  Where credentials and API keys are managed.
  Claude Sync does not handle secrets directly — it references
  this path so MCP servers can resolve their credentials on import.

REPOS ROOT PATH
  Root directory to scan for git repositories.
  All git repos found recursively under this path are included
  in the sync cycle unless on the exclude list.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Claude prompts for each value in sequence via plain input. Once all three are provided:

*[ask-user tool: Confirm configuration?]*
- **Confirm — save and continue** — writes all three values to global CLAUDE.md and proceeds with the original command
- **Cancel** — exits without saving

Once confirmed, all three values are written to the global CLAUDE.md and this setup will not run again on this machine. The exclude list is also initialized as an empty entry in the same block.

---

## Template 1 — `/sync-export` in progress

**When:** Export begins after configuration is confirmed.

**Purpose:** Show the git sync cycle running first, then each category being captured in real time.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📤  CLAUDE SYNC — EXPORT IN PROGRESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Machine    {hostname}
Timestamp  {ISO timestamp}
Target     {sync path}/claude-sync-{hostname}-{YYYYMMDD}.tar.gz

GIT REPOSITORIES  ({N} repos found under {repos root path})
  🔄  Syncing all repos with remote...
```

Each repo updates as it completes:

```
GIT REPOSITORIES  ({N} repos found under {repos root path})
  ✅  {repo name}    committed 2 changes · pushed · pulled
  ✅  {repo name}    up to date
  ⚠️  {repo name}    push failed — {reason}  (continuing)
  ✅  {repo name}    up to date
  ⏭️  {repo name}    no remote configured — skipped
  ⏭️  {repo name}    excluded

CAPTURING
  🔄  Claude Code settings
  🔄  MCP server configurations
  🔄  Global CLAUDE.md
  🔄  Plugins & slash command definitions
```

Each capture line updates in place as it completes:

```
CAPTURING
  ✅  Claude Code settings           (3 files)
  ✅  MCP server configurations      (7 servers)
  ✅  Global CLAUDE.md              (1 file)
  🔄  Plugins & slash command defs...
```

**Skipped category format:**

```
⏭️  {Category name}   skipped — {reason, e.g. "no files found"}
```

**Items on the exclude list are not captured and do not appear in the output at all.**

---

## Template 2 — `/sync-export` complete

**When:** All categories captured and archive written successfully.

**Purpose:** Confirm the snapshot was written, what it contains, git sync results, and where the archive lives.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢  CLAUDE SYNC — EXPORT COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Machine    {hostname}
Timestamp  {ISO timestamp}
Duration   {elapsed time}

GIT REPOSITORIES  ({N} synced · {N} warnings · {N} skipped · {N} excluded)
  ✅  {repo name}    committed 2 changes · pushed · pulled
  ✅  {repo name}    up to date
  ⚠️  {repo name}    push failed — {reason}
  ⏭️  {repo name}    no remote configured — skipped
  ⏭️  {repo name}    excluded

SNAPSHOT WRITTEN
  📦  {sync path}/claude-sync-{hostname}-{YYYYMMDD}.tar.gz
      Size: {file size}

CAPTURED
  ✅  Claude Code settings           (3 files)
  ✅  MCP server configurations      (7 servers)
  ✅  Global CLAUDE.md              (1 file)
  ✅  Plugins & slash command defs   (2 plugins)
  ⏭️  {Category name}               skipped — {reason}

PREVIOUS SNAPSHOT
  📦  Prior snapshot moved to backup:
      {sync path}/claude-sync-backup-{hostname}-{prev YYYYMMDD}.tar.gz
      (Previous backup overwritten)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The PREVIOUS SNAPSHOT section is omitted on first export. The GIT REPOSITORIES section collapses to a single summary line if all repos synced cleanly with no warnings.

**Export failure variant** — when the archive cannot be written:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴  CLAUDE SYNC — EXPORT FAILED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FAILURE
  ❌  {Description of what failed, e.g. "Could not write to sync path"}
      Path:    {sync path}
      Reason:  {error detail}

No snapshot was written. No backup was modified.
Git sync results above are unaffected.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Template 3 — `/sync-import` snapshot preview

**When:** `/sync-import` starts and reads the snapshot from the sync path.

**Purpose:** Show the user what's in the snapshot before any changes are made. First confirmation gate.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📥  CLAUDE SYNC — IMPORT PREVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SNAPSHOT FOUND
  Source machine  {hostname from snapshot}
  Exported at     {ISO timestamp from snapshot}
  Snapshot size   {file size}

CONTENTS
  ✅  Claude Code settings           (3 files)
  ✅  MCP server configurations      (7 servers)
  ✅  Global CLAUDE.md              (1 file)
  ✅  Plugins & slash command defs   (2 plugins)
  ⏭️  {Category name}               not included in snapshot

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

*[ask-user tool: Proceed with import?]*
- **Yes — review import plan** — continues to Template 4
- **Cancel** — exits without making any changes

**No snapshot found variant:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📥  CLAUDE SYNC — NO SNAPSHOT FOUND
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ❌  No snapshot found at sync path:
      {sync path}

  Run /sync-export on your source machine first.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Template 4 — `/sync-import` diff and installation plan

**When:** User confirms they want to proceed. Claude Sync diffs the snapshot against the local environment and identifies what needs to be installed.

**Purpose:** Show the complete plan before a single file is touched. This is the primary confirmation gate — nothing is applied until the user approves this summary.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📥  CLAUDE SYNC — IMPORT PLAN
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CHANGES
  {N} items will be added
  {N} items will be updated  (snapshot is newer — last-write-wins)
  {N} items unchanged        (will not be touched)

ADDITIONS
  +  {item description, e.g. "MCP server: github-mcp"}
  +  {item description}

UPDATES
  ~  {item description, e.g. "settings.json — snapshot is 3 days newer"}
  ~  {item description}

INSTALLS REQUIRED  ({N} MCP servers not present on this machine)
  🔧  {server name}    method: {npm / pip / binary / manual}
                       package: {package identifier}
  🔧  {server name}    method: {npm / pip / binary / manual}
                       package: {package identifier}

MANUAL INSTALLS  ({N} items require your action during import)
  🔧  {server name}
      {install notes from snapshot}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

*[ask-user tool: Confirm and execute import?]*
- **Confirm — execute import** — proceeds to Template 5
- **Cancel** — exits without any changes

The INSTALLS REQUIRED and MANUAL INSTALLS sections are omitted when no installations are needed. The ADDITIONS or UPDATES sections are omitted when empty.

---

## Template 5 — `/sync-import` in progress

**When:** User confirms the import plan. Execution begins.

**Purpose:** Show backup creation, each category being applied, dependency installation, and git repo sync — in real time.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📥  CLAUDE SYNC — IMPORT IN PROGRESS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Backing up current environment...
  🔄  Archiving local state...
  ✅  Backup written:
      {sync path}/claude-sync-backup-{hostname}-{YYYYMMDD}.tar.gz

Applying snapshot...

  ✅  Claude Code settings           (3 files updated)
  ✅  MCP server configurations      (7 servers merged)
  🔄  Global CLAUDE.md...
```

As it progresses:

```
  ✅  Global CLAUDE.md              (updated)
  ✅  Plugins & slash command defs   (2 plugins applied)

INSTALLING DEPENDENCIES
  🔧  {server name}   installing via npm...
  ✅  {server name}   installed successfully
  🔧  {server name}   installing via pip...
  ✅  {server name}   installed successfully
```

After local-only file review (Template 6) completes, git sync runs:

```
GIT REPOSITORIES  ({N} repos found under {repos root path})
  🔄  Syncing all repos with remote...
  ✅  {repo name}    committed 1 change · pushed · pulled
  ✅  {repo name}    up to date
  ⚠️  {repo name}    push failed — {reason}  (continuing)
  ⏭️  {repo name}    no remote configured — skipped
  ✅  {repo name}    up to date
```

**Install failure format** (does not halt the import):

```
❌  {server name}   install failed
    Method:   {method}
    Package:  {package identifier}
    Reason:   {error detail}
    Install manually when ready. Notes: {install notes from snapshot}
```

**Manual install step** (pauses for user confirmation):

```
🔧  {server name}   MANUAL INSTALL REQUIRED
    {install notes from snapshot}
```

*[ask-user tool: Manual install: {server name}]*
- **Installed — continue** — marks as complete, proceeds
- **Skip this install** — logs as skipped, proceeds

---

## Template 6 — Local-only file review

**When:** After all snapshot items are applied, before git sync. Triggered only when local-only files exist.

**Purpose:** Surface files that exist on this machine but were not in the snapshot. Let the user decide what to do with each one individually.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📥  CLAUDE SYNC — LOCAL-ONLY FILES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

The following {N} items exist on this machine but were not
in the snapshot. Review each one.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

For each item, Claude presents it individually:

*[ask-user tool: Local-only item: {item name / path} — what should Claude Sync do with this?]*
- **Keep** — leave it in place, no further action
- **Keep and exclude** — keep it, add to this machine's exclude list (will never be picked up by future exports)
- **Remove** — delete it

After all items are reviewed, a summary is printed before git sync begins:

```
LOCAL-ONLY FILE DECISIONS
  ✅  Kept:           {N} items
  🏷️  Keep+excluded:  {N} items  (added to exclude list in global CLAUDE.md)
  🗑️  Removed:        {N} items
```

If no local-only files exist, this template is skipped entirely and execution proceeds directly to the git sync stage in Template 5.

---

## Template 7 — `/sync-import` complete

**When:** All categories applied, local-only file review complete, and git sync complete.

**Purpose:** The definitive import report. Everything the user needs in one screen.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢  CLAUDE SYNC — IMPORT COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Source machine  {hostname from snapshot}
Timestamp       {ISO timestamp}
Duration        {elapsed time}

APPLIED
  ✅  Claude Code settings           (3 files updated)
  ✅  MCP server configurations      (7 servers merged)
  ✅  Global CLAUDE.md              (updated)
  ✅  Plugins & slash command defs   (2 plugins applied)
  ⏭️  {Category name}               skipped — {reason}

INSTALLS
  ✅  {server name}   installed successfully
  ❌  {server name}   failed — install manually
  ⏭️  {server name}   skipped by user

LOCAL-ONLY FILES
  ✅  Kept: {N}   |   🏷️  Excluded: {N}   |   🗑️  Removed: {N}

GIT REPOSITORIES  ({N} synced · {N} warnings · {N} skipped · {N} excluded)
  ✅  {repo name}    committed 1 change · pushed · pulled
  ✅  {repo name}    up to date
  ⚠️  {repo name}    push failed — {reason}
  ⏭️  {repo name}    no remote configured — skipped
  ⏭️  {repo name}    excluded

BACKUP
  📦  Pre-import backup preserved at:
      {sync path}/claude-sync-backup-{hostname}-{YYYYMMDD}.tar.gz

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Variant with warnings** (failed installs, repo push failures, or skipped items): replaces `🟢` with `🟡`. Body is otherwise identical.

**Critical failure variant** (backup failed, or archive could not be applied):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔴  CLAUDE SYNC — IMPORT FAILED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FAILURE
  ❌  {Description of what failed}
      Reason: {error detail}

ROLLBACK
  Your pre-import state is preserved at:
  📦  {sync path}/claude-sync-backup-{hostname}-{YYYYMMDD}.tar.gz
```

If the backup had not yet been written when the failure occurred:

```
ROLLBACK
  ❌  Backup was not written before failure.
      Local environment was not modified.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## UX behavior notes

These are part of the contract. Follow them.

**Git sync runs first on export, last on import.** On `/sync-export`, all repos are synced with their remotes before capture begins — so the snapshot reflects a state where all code is pushed. On `/sync-import`, git sync runs after the snapshot is applied and local-only files are reviewed — so repos are pulled only after the environment is in its final state.

**Repos with no remote are skipped entirely.** Before attempting any git operations on a repo, check whether a remote is configured. If none exists, the entire sync cycle is skipped for that repo and it is flagged as `skipped (no remote)` in the output. This is distinct from a push failure — no remote is a known state, not an error.

**Repo push failures are warnings, not blockers.** If a repo has a remote but the push fails (auth error, diverged history), it is flagged as a warning and the sync cycle continues with fetch and pull. The export or import completes; the user sees the failure clearly in the final report.

**Auto-commits use a consistent message format.** When the git sync cycle commits tracked changes, it uses: `chore: claude-sync auto-commit [hostname] [ISO timestamp]`. Untracked files are not staged — only changes to files already known to git are committed.

**Backup before anything.** The first action of every import is writing the backup archive. If the backup write fails, the import halts immediately and nothing is applied. The user's environment is never touched before the backup succeeds.

**The import plan always precedes execution.** Template 4 is never skipped. There is no fast-path that bypasses the diff and confirmation step.

**Local-only file review happens before git sync on import.** The sequence is: backup → apply snapshot → install dependencies → review local-only files → git sync. This ensures the environment is fully settled before repos are pulled.

**Install failures do not halt the import.** A failed MCP server install is logged and summarized in the final report. All other categories continue. The user can install the failed server manually after the import completes.

**Manual install steps pause for confirmation.** When the install method is `manual`, Claude Sync presents the install notes and waits for the user to confirm they've completed the step before continuing. The user can also skip the step.

**Excluded items are invisible to export.** Items on the machine's exclude list are not captured and do not appear in the export output at all. This includes excluded git repos — they are not synced and not reported.

**Excluded items survive import.** When the snapshot is applied to a machine, items on that machine's local exclude list are left untouched even if a conflicting version exists in the snapshot.

**All decision points use the ask-user tool.** Narration is for progress reporting only. Confirmations and per-item decisions are always presented as selectable options, never buried in prose.

**The INSTALLS, LOCAL-ONLY FILES, and GIT REPOSITORIES sections in the final report collapse or are omitted when empty.** The GIT REPOSITORIES section in Templates 2 and 7 collapses to a single summary line when all repos synced cleanly with no warnings.
