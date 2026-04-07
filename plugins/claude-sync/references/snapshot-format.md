# Snapshot Format

This file defines the structure, naming, manifest schema, and merge logic for the `.tar.gz` snapshot archive. Commands read this file when building or parsing the archive.

---

## Archive structure

The snapshot is a `.tar.gz` archive containing:

```
claude-sync-{hostname}-{YYYYMMDD}.tar.gz
├── manifest.json              # Metadata, inventory, and repo list
├── claude/                    # Captured ~/.claude/ tree (exclusions applied)
│   ├── settings.json
│   ├── settings.local.json
│   ├── CLAUDE.md              # Global CLAUDE.md with config block stripped
│   ├── plugins/               # Installed plugins
│   ├── commands/              # Custom slash commands
│   └── ...                    # Any other files in ~/.claude/ not excluded
└── mcp-servers.json           # MCP server configs extracted from ~/.claude.json
```

The `claude/` directory mirrors the `~/.claude/` directory tree on the exporting machine with exclusions applied. On import, its contents are written back to `~/.claude/` on the receiving machine.

The `mcp-servers.json` file is a standalone extraction of the `mcpServers` key from `~/.claude.json`, enriched with install blocks.

---

## Snapshot naming

**Live snapshot:** `claude-sync-{hostname}-{YYYYMMDD}.tar.gz`

Where `{hostname}` is the exporting machine's hostname and `{YYYYMMDD}` is the export date. Written to the configured sync path.

**Backup archive:** `claude-sync-backup-{hostname}-{YYYYMMDD}.tar.gz`

Where `{hostname}` is the **importing** machine's hostname and `{YYYYMMDD}` is the import date. Written to the sync path alongside the live snapshot. Only one backup is retained; each import replaces the previous backup.

---

## manifest.json schema

```json
{
  "schema_version": "1.0.0",
  "hostname": "sys76",
  "exported_at": "2026-04-07T14:30:00Z",
  "claude_json_mtime": "2026-04-05T10:15:00Z",
  "categories": {
    "settings": {
      "count": 3,
      "files": ["settings.json", "settings.local.json", "..."]
    },
    "mcp_servers": {
      "count": 7,
      "servers": ["server-name-1", "server-name-2", "..."]
    },
    "claude_md": {
      "count": 1,
      "files": ["CLAUDE.md"]
    },
    "plugins": {
      "count": 2,
      "names": ["plugin-name-1", "plugin-name-2"]
    }
  },
  "repositories": [
    {
      "name": "repo-directory-name",
      "path": "/home/user/projects/repo-directory-name",
      "remote": "git@github.com:User/repo-directory-name.git"
    }
  ]
}
```

### Field definitions

| Field | Type | Description |
|---|---|---|
| `schema_version` | string | Schema version for forward compatibility. Current: `"1.0.0"` |
| `hostname` | string | Hostname of the exporting machine |
| `exported_at` | string | ISO 8601 timestamp of the export |
| `claude_json_mtime` | string | ISO 8601 mtime of `~/.claude.json` at export time. Used for MCP conflict resolution. |
| `categories` | object | Per-category contents inventory |
| `categories.settings.count` | number | Number of settings files captured |
| `categories.settings.files` | string[] | List of settings filenames |
| `categories.mcp_servers.count` | number | Number of MCP server entries |
| `categories.mcp_servers.servers` | string[] | List of MCP server names |
| `categories.claude_md.count` | number | Number of CLAUDE.md files (always 1 or 0) |
| `categories.claude_md.files` | string[] | List of CLAUDE.md filenames |
| `categories.plugins.count` | number | Number of plugins captured |
| `categories.plugins.names` | string[] | List of plugin names |
| `repositories` | array | Git repos present on the exporting machine at export time |
| `repositories[].name` | string | Directory name of the repo |
| `repositories[].path` | string | Absolute path on the exporting machine |
| `repositories[].remote` | string | Configured remote URL (portable identifier) |

---

## mcp-servers.json schema

```json
{
  "servers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@scope/package"],
      "env": { "KEY": "value" },
      "install": {
        "method": "npm",
        "package": "@scope/package",
        "version": "1.2.3",
        "notes": ""
      }
    },
    "another-server": {
      "command": "/usr/local/bin/custom-server",
      "args": ["--port", "3000"],
      "install": {
        "method": "binary",
        "package": "/usr/local/bin/custom-server",
        "notes": "Pre-built binary, ensure it exists at the path"
      }
    },
    "manual-server": {
      "command": "some-custom-launcher",
      "args": ["--config", "/path/to/config"],
      "install": {
        "method": "manual",
        "package": "",
        "notes": "Run: some-custom-launcher --config /path/to/config"
      }
    }
  }
}
```

### MCP install block fields

| Field | Type | Required | Description |
|---|---|---|---|
| `method` | string | yes | One of: `npm`, `pip`, `binary`, `manual` |
| `package` | string | yes | Package identifier (npm package, pip package, binary path, or empty for manual) |
| `version` | string | no | Optional version pin |
| `notes` | string | no | Free-text notes. For `manual` method, contains the raw command string. |

Each server entry preserves all original fields from `~/.claude.json` (`command`, `args`, `env`, etc.) and adds the `install` block.

---

## Merge logic

When `/sync-import` applies the snapshot, merge decisions use **filesystem mtime** as the conflict resolution signal.

### File-level merge (settings, CLAUDE.md, plugins)

For each file in the snapshot's `claude/` directory:
- Compare the snapshot file's mtime (preserved in the archive) against the local file's mtime.
- **Snapshot is newer**: overwrite the local file with the snapshot version.
- **Local is newer**: keep the local file unchanged.
- **File exists only in snapshot**: add it (new file).
- **File exists only locally**: flag as local-only (handled by Template 6).

### MCP merge

MCP conflict resolution operates at the `~/.claude.json` **file level**, not per-server:
1. Read the snapshot's `claude_json_mtime` from `manifest.json`.
2. Read the local `~/.claude.json` mtime.
3. If the snapshot's mtime is newer: read local `~/.claude.json`, replace the entire `mcpServers` block with the snapshot's `mcp-servers.json` content (stripping install blocks — those are metadata, not runtime config), write the file back.
4. If the local mtime is newer: keep the local `mcpServers` block. Still check for MCP servers in the snapshot that are absent locally and flag them for installation.

### CLAUDE.md merge (special case)

Global CLAUDE.md requires special handling because the Claude Sync config block must be preserved on the receiving machine:
1. Read the local `~/.claude/CLAUDE.md` and extract the Claude Sync config block.
2. Apply the snapshot's CLAUDE.md (which has the config block stripped).
3. Re-insert the local Claude Sync config block at its original position.

---

## Backup archive

The backup archive uses the same `.tar.gz` format as the live snapshot. It captures the receiving machine's current `~/.claude/` state (same exclusions) and MCP server configs before any import changes are applied.

- **Name:** `claude-sync-backup-{hostname}-{YYYYMMDD}.tar.gz`
- **Location:** the configured sync path, alongside the live snapshot
- **Retention:** only one backup per machine is retained. Each import replaces the previous backup.
- **Git repos are not included** in the backup — git's own history serves that purpose.

The backup is the **first action** of every import. If the backup write fails, the import halts immediately and nothing is applied.

---

## Schema version and forward compatibility

The `schema_version` field in `manifest.json` indicates the snapshot format version. When reading a snapshot:
- If `schema_version` matches the plugin's current version (`1.0.0`): proceed normally.
- If `schema_version` is newer than what the plugin understands: warn the user that the snapshot was created by a newer version of Claude Sync and some features may not be applied. Proceed with best-effort parsing.
- If `schema_version` is missing: treat as pre-1.0 format and warn.
