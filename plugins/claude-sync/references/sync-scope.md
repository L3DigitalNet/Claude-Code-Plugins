# Sync Scope

This file defines what Claude Sync captures, applies, excludes, and git-syncs. Commands read this file to understand the full scope of a sync operation.

---

## Capture strategy

The `~/.claude/` directory is captured **wholesale** — the entire directory tree is included in the snapshot archive, minus the explicit exclusions listed below. This approach means the sync stays correct even as Claude Code adds new configuration files over time; no per-file allowlist to maintain.

MCP server configurations require **separate extraction** from `~/.claude.json` because that file also contains OAuth tokens, per-project trust state, and caches that must never leave the machine. Only the `mcpServers` key is read and written as a standalone `mcp-servers.json` file inside the snapshot archive.

---

## Always excluded

These items are never captured regardless of the exclude list:

| Path / item | Reason |
|---|---|
| `~/.claude/projects/` | Session history. Out of scope for v1. |
| `~/.claude/.credentials.json` | Authentication tokens for the Claude Code CLI on Linux. Machine-local, must never leave the machine. |
| `~/.claude/statsig/` | Analytics and feature flag cache. Not environment state. |
| The Claude Sync configuration block in `~/.claude/CLAUDE.md` | Sync path, secret store path, repos root, and exclude list are machine-local configuration, not environment state. When capturing `~/.claude/CLAUDE.md`, read the file, strip the Claude Sync configuration block (everything between the `<!-- claude-sync-config-start -->` and `<!-- claude-sync-config-end -->` markers inclusive), and capture the result. On import, the receiving machine's Claude Sync config block is preserved — the snapshot version of CLAUDE.md is merged around it. |
| OAuth tokens in `~/.claude.json` | Only the `mcpServers` key is extracted. The rest of the file is not read or modified. |

---

## Four logical categories

The capture is organized into four categories for reporting and inventory purposes. Categories 1, 3, and 4 are all part of the wholesale `~/.claude/` scan. Category 2 is extracted separately.

### Category 1 — Claude Code settings

All settings-layer files Claude Code manages inside `~/.claude/`:
- `settings.json`
- `settings.local.json`
- Any other settings files present (the wholesale scan catches them automatically)

### Category 2 — MCP server configurations

Extracted from `~/.claude.json` (not from the `~/.claude/` directory):
1. Read `~/.claude.json`
2. Extract only the `mcpServers` key
3. For each server entry, generate an `install` block by inferring the installation method (see MCP install inference below)
4. Write the result as `mcp-servers.json` inside the snapshot archive

The rest of `~/.claude.json` is never read, stored, or modified.

### Category 3 — Global CLAUDE.md

`~/.claude/CLAUDE.md` only. Project-level CLAUDE.md files outside repos are out of scope. CLAUDE.md files inside repos travel with those repos via git.

When capturing: strip the Claude Sync configuration block before including in the archive.
When applying: merge the snapshot CLAUDE.md around the receiving machine's existing Claude Sync config block.

### Category 4 — Plugins and slash command definitions

Installed plugins and any custom slash commands they define. These live inside `~/.claude/` and are captured by the wholesale scan: the `plugins/` directory, `commands/` directory, and any related state files.

---

## MCP install method inference

On export, for each MCP server entry in `mcpServers`, infer the installation method from the server's `command` field:

| Command pattern | Inferred method | Package identifier |
|---|---|---|
| `npx` | `npm` | First argument after `npx` flags (strip `-y`, `--yes`) |
| `uvx` | `pip` | First argument after `uvx` |
| `pip` | `pip` | Package name from the pip command |
| Absolute filesystem path (starts with `/`) | `binary` | The path itself |
| Anything else | `manual` | Raw command string captured in the `notes` field |

The install block is written per-server in `mcp-servers.json` and used by `/sync-import` to reconstruct missing servers on the receiving machine.

---

## MCP conflict resolution

MCP server entries do not carry per-entry timestamps. Conflict resolution for the `mcpServers` block uses the **mtime of `~/.claude.json` as a whole**:

- On export: record the mtime of `~/.claude.json` in the snapshot manifest.
- On import: compare the snapshot's recorded `~/.claude.json` mtime against the receiving machine's `~/.claude.json` mtime.
  - If the snapshot's mtime is **newer**: replace the entire local `mcpServers` block with the snapshot version.
  - If the local mtime is **newer**: keep the local `mcpServers` block unchanged.

This is file-level last-write-wins. The entire block is replaced or kept as a unit.

---

## Git sync cycle

Both `/sync-export` and `/sync-import` scan the configured repos root path **recursively** for all git repositories and run the same full sync cycle on each. The cycle runs on **every invocation** regardless of whether the repo appears in the snapshot manifest.

### Pre-check: remote detection

Before attempting any git operations on a repo, check whether a remote is configured (`git remote`). If **no remote exists**, skip the entire sync cycle for that repo and flag it in the output as `skipped (no remote)`. Do not attempt commit, push, fetch, or pull.

### Sync steps (when a remote exists)

1. **Commit** — stage and commit any tracked changes that haven't been committed yet. **Untracked files are not staged**; only changes to files already known to git are included. Use `git add -u` to stage tracked changes, then commit.
2. **Push** — push to the configured remote. If the push **fails** (auth error, diverged history, etc.), flag it as a **warning** and continue with fetch and pull. A push failure does not halt the sync.
3. **Fetch** — `git fetch` from the remote to get changes made on other machines.
4. **Pull** — `git pull` to merge fetched changes into the local branch.

### Auto-commit message format

```
chore: claude-sync auto-commit [hostname] [ISO timestamp]
```

Where `[hostname]` is the machine's hostname and `[ISO timestamp]` is the current time in ISO 8601 format. Example:

```
chore: claude-sync auto-commit sys76 2026-04-07T14:30:00Z
```

### Repos on the exclude list

Repos on the per-machine exclude list are skipped entirely — no git operations are attempted and they do not appear in the output.

### All repos are synced on every invocation

Both commands sync **every git repo** found under the repos root path. The snapshot manifest's repo list is informational (it records what was present on the exporting machine) but does not limit which repos are synced on the receiving machine.

---

## Per-machine exclude list

The exclude list is stored in the Claude Sync configuration block in the global `~/.claude/CLAUDE.md`. It applies to **both** file capture and git repository sync:

- **File exclusions**: paths on the exclude list are not captured during export. During import, excluded items on the receiving machine are left untouched even if a conflicting version exists in the snapshot.
- **Repo exclusions**: repos on the exclude list are not synced (no commit, push, fetch, pull) and are not reported in the output.

Entries are added via the "keep and exclude" choice during local-only file review on import (Template 6). Entries can also be added manually by editing the config block.

---

## Local-only file identification

During import, after applying all snapshot items, compare the local `~/.claude/` directory against the snapshot contents. Any file or directory that exists locally but was **not present in the snapshot** is a local-only item.

Exclude from this comparison:
- Items in the always-excluded list (projects/, .credentials.json, statsig/, config block)
- Items on the per-machine exclude list
- The Claude Sync config block in CLAUDE.md

Each local-only item is surfaced to the user for a per-item decision (Template 6): keep, keep and exclude, or remove.
