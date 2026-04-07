---
name: sync-import
description: "Reads the snapshot from the sync path, writes a backup of the current local state, applies the snapshot with mtime-based merge, surfaces local-only files for user review, then runs a full git sync cycle on all repos."
---

# Sync Import

You are running the Claude Sync import. Your job is to read a snapshot from the sync path, show the user what it contains, get confirmation, back up the local state, apply the snapshot, review local-only files, and sync all git repos.

## Critical rules

1. **Record the start time when this command begins.** You will need it for the duration field in the final report.
2. **All decisions use the ask-user tool.** Never bury a decision in narration.
3. **Follow the output templates exactly.** Read the ux-templates reference for the precise format.
4. **Backup before anything.** Never modify the local environment before the backup archive is successfully written.
5. **The import plan always precedes execution.** Template 4 is never skipped.
6. **Install failures do not halt the import.** Log them and continue.

## Procedure

### Step 1 — Load and validate configuration

Read `${CLAUDE_PLUGIN_ROOT}/references/config.md` for the configuration model.

Read `~/.claude/CLAUDE.md` and look for the Claude Sync configuration block (between `<!-- claude-sync-config-start -->` and `<!-- claude-sync-config-end -->` markers).

**If no configuration block exists:** This is a first run. Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 0 (first-run setup). Follow the first-run setup procedure in the config reference. Once configuration is saved, continue to Step 2.

**If configuration exists:** Parse the sync path, secret store path, repos root path, and exclude list. Store them for use in script calls:
- `$sync_path`, `$repos_root`, `$exclude_list` (newline-separated string)

### Step 2 — Parse snapshot and present preview

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 3 (import preview).

Run the parse script:

```bash
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/parse-snapshot.sh"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/parse-snapshot.sh" "$sync_path" --exclude "$exclude_list"
```

The script finds the snapshot, extracts it, reads the manifest, diffs all files against local state, identifies MCP install requirements, and finds local-only files. It returns all data needed for Templates 3, 4, 6, and 7 in a single JSON response.

**If the JSON contains `"error":"no_snapshot"`:** Output the no-snapshot-found variant of Template 3 and exit.

**Otherwise:** the JSON contains:
- `snapshot` — hostname, exported_at, archive_size, schema_version, claude_json_mtime, archive_path
- `categories` — per-category counts from the manifest
- `diff.additions[]`, `diff.updates[]`, `diff.unchanged[]`, `diff.local_only[]` — file-level diff results
- `mcp.action` (`"replace"` or `"keep_local"`), `mcp.reason` — MCP block merge decision
- `mcp.installs_required[]`, `mcp.manual_installs[]` — servers needing installation

Present the snapshot preview (Template 3) using `snapshot` and `categories` fields.

*[ask-user tool: Proceed with import?]*
- **Yes — review import plan** → continue to Step 3
- **Cancel** → exit without changes

### Step 3 — Present the import plan

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 4 (import plan).

Using the `diff` and `mcp` fields from Step 2's JSON output, format Template 4:
- **CHANGES** summary: count of additions, updates, unchanged
- **ADDITIONS**: list items from `diff.additions[]` with `+` prefix
- **UPDATES**: list items from `diff.updates[]` with `~` prefix (include `age_diff`)
- If `mcp.action == "replace"`: add MCP block to UPDATES with reason
- If `mcp.action == "keep_local"`: note MCP block is unchanged
- **INSTALLS REQUIRED**: items from `mcp.installs_required[]` with method and package
- **MANUAL INSTALLS**: items from `mcp.manual_installs[]` with notes

Omit ADDITIONS, UPDATES, INSTALLS REQUIRED, or MANUAL INSTALLS sections when empty.

*[ask-user tool: Confirm and execute import?]*
- **Confirm — execute import** → continue to Step 4
- **Cancel** → exit without changes

### Step 4 — Write backup

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 5 (import in progress).

Output the Template 5 header and backup section.

Run the capture script in backup mode:

```bash
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/capture-env.sh"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/capture-env.sh" "$sync_path" "$(hostname)" "$repos_root" --backup --exclude "$exclude_list"
```

If the JSON contains an `error` field: output the critical failure variant of Template 7 with the "backup was not written" rollback message. **Halt immediately. Do not proceed.**

Report: `✅  Backup written: {archive_path from JSON}`

### Step 5 — Apply snapshot

Extract the snapshot archive (path from Step 2's `snapshot.archive_path`) to a temp directory and apply each category:

**Category 1 — Claude Code settings:**
- For each file in the snapshot's `claude/` directory that is a root-level settings file (not CLAUDE.md, not inside plugins/ or commands/): compare mtime with the local version.
- If snapshot file is newer or local doesn't exist: copy from extracted archive to `~/.claude/`.
- Report: `✅  Claude Code settings           ({N} files updated)`

**Category 2 — MCP server configurations:**
- Use `mcp.action` from Step 2:
  - If `"replace"`: read local `~/.claude.json`, replace the `mcpServers` key with the snapshot's MCP data (from `mcp-servers.json` in the archive, **stripping install blocks** — only keep command, args, env, and other runtime fields), write back.
  - If `"keep_local"`: no changes to `~/.claude.json`.
- Report appropriately.

**Category 3 — Global CLAUDE.md:**
- Read the local `~/.claude/CLAUDE.md` and extract the Claude Sync configuration block (between the markers, inclusive).
- Read the snapshot's `claude/CLAUDE.md` (which has the config block stripped).
- If the snapshot version is newer (by mtime): write the snapshot's CLAUDE.md content, then re-insert the local config block at the end.
- If local is newer: keep local CLAUDE.md unchanged.
- Report: `✅  Global CLAUDE.md              (updated)` or `(unchanged — local is newer)`

**Category 4 — Plugins and slash command definitions:**
- For each file in the snapshot's `claude/plugins/` and `claude/commands/` directories: compare mtime, copy if snapshot is newer or file is new.
- Report: `✅  Plugins & slash command defs   ({N} plugins applied)`

### Step 6 — Install MCP server dependencies

Using `mcp.installs_required[]` and `mcp.manual_installs[]` from Step 2:

**Automatic installs:**
For each entry in `installs_required`:
- `method: "npm"` → run `npm install -g {package}` or `npx -y {package}` to verify
- `method: "pip"` → run `pip install {package}` or `uvx install {package}`
- `method: "binary"` → verify the binary exists at the package path
- Report each: `✅  {name}   installed successfully` or `❌  {name}   install failed`

**Manual installs:**
For each entry in `manual_installs`:
```
🔧  {name}   MANUAL INSTALL REQUIRED
    {notes}
```
*[ask-user tool: Manual install: {name}]*
- **Installed — continue** → mark as complete
- **Skip this install** → mark as skipped

Install failures do not halt the import.

### Step 7 — Review local-only files

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 6 (local-only file review).

Using `diff.local_only[]` from Step 2's JSON:

**If the array is empty:** Skip this step entirely. Proceed to Step 8.

**If local-only files exist:** Output the Template 6 header.

For each item in the array, present it individually via the ask-user tool:
- **Keep** — leave it in place
- **Keep and exclude** — keep it, add to the exclude list in global CLAUDE.md (read `${CLAUDE_PLUGIN_ROOT}/references/config.md` for how to update the exclude list)
- **Remove** — delete `~/.claude/{path}`

After all items reviewed, output the summary.

### Step 8 — Git sync cycle

Run the git sync script:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/git-sync.sh" "$repos_root" "$(hostname)" "$exclude_list"
```

Format the GIT REPOSITORIES section from the JSON output, same as in sync-export Step 2.

### Step 9 — Output final report

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 7 (import complete).

Determine the verdict:
- **🟢 Complete** — everything applied, no failures or warnings
- **🟡 Complete with warnings** — any failed installs, push failures, or skipped items
- **🔴 Failed** — should have already halted at the backup step

Output the Template 7 report with data collected from all steps:
- Source machine and timestamp from Step 2
- Duration from start time
- Applied categories from Step 5
- Install results from Step 6 (omit section if no installs)
- Local-only file decisions from Step 7 (omit if none)
- Git repositories summary from Step 8 (collapse to one line if all clean)
- Backup location from Step 4
