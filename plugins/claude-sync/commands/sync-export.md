---
name: sync-export
description: "Runs a full git sync cycle on all repos under the configured repos root path, then captures the Claude Code environment (~/.claude/ with exclusions, MCP server configs) into a .tar.gz snapshot written to the sync path."
---

# Sync Export

You are running the Claude Sync export. Your job is to sync all git repos with their remotes, capture the Claude Code environment, and write a snapshot archive to the configured sync path.

## Critical rules

1. **Record the start time when this command begins.** You will need it for the duration field in the final report.
2. **All decisions use the ask-user tool.** Never bury a decision in narration.
3. **Follow the output templates exactly.** Read the ux-templates reference for the precise format.
4. **Excluded items are invisible.** Items on the exclude list are not captured and do not appear in output.

## Procedure

### Step 1 — Load and validate configuration

Read `${CLAUDE_PLUGIN_ROOT}/references/config.md` for the configuration model.

Load the Claude Sync configuration:
```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/config-block.sh read
```

**If `block_found` is false:** This is a first run. Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 0 (first-run setup). Follow the first-run setup procedure in the config reference. Once configuration is saved, continue to Step 2.

**If `block_found` is true:** Use the parsed fields from the JSON output. Validate that the sync path exists and is writable. Validate that the repos root path exists. If validation fails, report the error and exit.

Store the parsed values for use in script calls:
- `$sync_path` — the sync path
- `$repos_root` — the repos root path
- `$exclude_list` — the exclude entries as a newline-separated string

### Step 2 — Git sync cycle

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 1 (export in progress).

Output the Template 1 header with the machine hostname, current ISO timestamp, and target archive path.

Run the git sync script:

```bash
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/git-sync.sh"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/git-sync.sh" "$repos_root" "$(hostname)" "$exclude_list"
```

The script returns JSON with:
- `results[]` — per-repo objects with `name`, `status`, `message`, `committed`, `push_ok`
- `summary` — `synced`, `warnings`, `skipped`, `excluded` counts

Format each repo result using the Template 1 GIT REPOSITORIES format:
- `status: "synced"` or `"up_to_date"` → `✅  {name}    {message}`
- `status: "push_failed"` → `⚠️  {name}    {message}`
- `status: "no_remote"` → `⏭️  {name}    {message}`

Excluded repos are not in the results (the script filters them out).

### Step 3 — Capture environment and write archive

Run the capture script:

```bash
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/capture-env.sh"
bash "${CLAUDE_PLUGIN_ROOT}/scripts/capture-env.sh" "$sync_path" "$(hostname)" "$repos_root" --exclude "$exclude_list"
```

The script handles everything: copies `~/.claude/` with exclusions, strips the config block from CLAUDE.md, extracts MCP servers from `~/.claude.json` with install method inference, scans repos for the manifest, builds the archive, and moves any previous snapshot to backup.

The script returns JSON with:
- `archive_path`, `archive_size` — the written snapshot
- `categories.settings.count`, `categories.mcp_servers.count`, `categories.claude_md.count`, `categories.plugins.count` — per-category item counts
- `previous_snapshot`, `backup_moved_to` — previous snapshot handling (empty strings if first export)

If the JSON contains an `error` field, output the export failure variant of Template 2 and exit.

Format the CAPTURING section of Template 1 using the category counts:
- `categories.settings.count > 0` → `✅  Claude Code settings           ({N} files)`
- `categories.mcp_servers.count > 0` → `✅  MCP server configurations      ({N} servers)`
- `categories.mcp_servers.count == 0` → `⏭️  MCP server configurations      skipped — no MCP servers configured`
- `categories.claude_md.count > 0` → `✅  Global CLAUDE.md              (1 file)`
- `categories.claude_md.count == 0` → `⏭️  Global CLAUDE.md              skipped — no global CLAUDE.md found`
- `categories.plugins.count > 0` → `✅  Plugins & slash command defs   ({N} plugins)`

### Step 4 — Output final report

Read `${CLAUDE_PLUGIN_ROOT}/references/ux-templates.md` for Template 2 (export complete).

Output the Template 2 report using data from both scripts:
- Machine hostname, timestamp, duration (from start time recorded in Step 1)
- Git repositories summary from Step 2 (collapse to one line if `summary.warnings == 0 && summary.skipped == 0`)
- Snapshot file path and size from Step 3
- Captured categories with counts from Step 3
- PREVIOUS SNAPSHOT section: if `previous_snapshot` is non-empty, show it. Omit on first export.
