# Configuration

This file defines the Claude Sync configuration model: where it lives, what fields it contains, how to read it, how to write it, and how to manage the exclude list. Commands read this file to locate and parse configuration.

---

## Configuration location

Claude Sync configuration is stored as a clearly delimited block in the **global** `~/.claude/CLAUDE.md` file. It is not stored in any project-level file, not in a separate config file, and not inside the plugin directory.

The block is delimited by HTML comment markers:

```markdown
<!-- claude-sync-config-start -->
## Claude Sync Configuration

**Sync path:** /mnt/nas/claude-sync
**Secret store path:** /mnt/nas/secrets
**Repos root path:** /home/chris/projects

### Exclude list
- ~/projects/local-only-repo
- ~/.claude/some-local-file.json
<!-- claude-sync-config-end -->
```

### Reading the configuration

1. Read `~/.claude/CLAUDE.md`
2. Find the `<!-- claude-sync-config-start -->` marker
3. Find the `<!-- claude-sync-config-end -->` marker
4. Parse the content between the markers for the three required values and the exclude list

If either marker is missing, no configuration exists — trigger the first-run setup.

### Writing the configuration

When writing or updating the config block:
1. Read the full `~/.claude/CLAUDE.md`
2. If the markers exist, replace everything between them (inclusive of markers)
3. If the markers do not exist, append the block at the end of the file
4. Write the file back

Always preserve the rest of `~/.claude/CLAUDE.md` — never overwrite the entire file.

---

## Configuration fields

### Sync path (required)

Where environment snapshots are written and read from. Must be accessible from all machines that use Claude Sync (NFS mount, shared network drive, Syncthing folder, etc.).

Example: `/mnt/nas/claude-sync`

The snapshot archive, backup archive, and any future sync artifacts are written to this path.

### Secret store path (required)

Where credentials and API keys are managed. Claude Sync does not handle secrets directly — it stores this path so MCP server install notes can reference it, and so the receiving machine knows where to look for credential resolution.

Example: `/mnt/nas/secrets`

### Repos root path (required)

The root directory under which Claude Sync scans for git repositories. All git repos found recursively under this path are included in the sync cycle unless on the exclude list.

Example: `/home/chris/projects`

### Exclude list (initialized empty)

A list of paths that are excluded from both file capture and git repository sync. Each entry is on its own line under the `### Exclude list` heading, formatted as a markdown list item.

Entries can be:
- Absolute paths: `/home/chris/projects/local-only-repo`
- Home-relative paths: `~/projects/local-only-repo`
- Paths within `~/.claude/`: `~/.claude/some-local-file.json`

Both file paths and git repository paths can appear on the exclude list. During export, any item matching an exclude entry is skipped entirely. During import, excluded items on the receiving machine are left untouched.

---

## First-run setup

When either `/claude-sync:sync-export` or `/claude-sync:sync-import` is invoked and no configuration block is found in `~/.claude/CLAUDE.md`, the first-run setup runs before the command proceeds.

### Setup procedure

1. Output Template 0 (first-run setup header) from the ux-templates reference.

2. Prompt for **sync path** using the ask-user tool:
   - Explain: this is where snapshots are written and read from; must be accessible from all machines.
   - Accept a filesystem path. Validate the path exists and is writable. If validation fails, explain why and prompt again.

3. Prompt for **secret store path** using the ask-user tool:
   - Explain: where credentials are managed; Claude Sync references this path but does not handle secrets directly.
   - Accept a filesystem path.

4. Prompt for **repos root path** using the ask-user tool:
   - Explain: root directory scanned for git repos; all repos found recursively are synced.
   - Accept a filesystem path. Validate the path exists. If validation fails, explain why and prompt again.

5. Present all three values for confirmation via ask-user tool:
   - **Confirm — save and continue**: write the config block and proceed with the original command.
   - **Cancel**: exit without saving.

6. On confirmation, write the configuration block to `~/.claude/CLAUDE.md`:
   - Use the HTML comment markers
   - Include all three values
   - Initialize the exclude list as an empty section (the heading with no entries)

The first-run setup runs once per machine. Once the config block exists, it is not shown again.

---

## Adding exclude list entries

When the user chooses "keep and exclude" for a local-only item during import (Template 6):

1. Read the current configuration block from `~/.claude/CLAUDE.md`
2. Add the item's path as a new entry under the `### Exclude list` heading
3. Write the updated block back

Format each new entry as a markdown list item:
```markdown
- /path/to/excluded/item
```

If the exclude list section currently has no entries, the first entry goes directly under the heading. Subsequent entries are appended below existing ones.

---

## Configuration block and snapshots

The Claude Sync configuration block is **never included in snapshots**. On export, the block is stripped from `~/.claude/CLAUDE.md` before the file is added to the archive. On import, the receiving machine's config block is preserved — the snapshot's CLAUDE.md is merged around it.

This ensures each machine retains its own sync path, secret store path, repos root path, and exclude list, which are inherently machine-local values.
