---
name: refresh-plugin-cache
description: This skill should be used when the user asks to "refresh the plugin cache", "update plugin cache", "sync plugin cache", "update installed plugins", "check for plugin updates", "are my plugins up to date", "is the plugin cache fresh", or "verify plugin versions". Scoped to l3digitalnet-plugins only — pulls the latest marketplace index, compares installed plugin versions against current listings, and reports stale plugins and orphaned cache directories.
---

# Refresh Plugin Cache

Pull the latest `l3digitalnet-plugins` marketplace index, compare installed plugin versions against current listings, and surface anything stale or orphaned. The `claude-plugins-official` marketplace is managed by Anthropic and excluded from this workflow.

## Workflow

### Step 1 — Run the refresh script

```bash
bash .claude/skills/refresh-plugin-cache/scripts/refresh-cache.sh
```

Run from the project root (`/home/chris/projects/Claude-Code-Plugins`). The script does not modify installed plugin content — it only updates the marketplace index clones and reports status.

### Step 2 — Interpret the output

**MARKETPLACE INDEX REFRESH** — One line per marketplace git clone:

| Prefix | Meaning |
|--------|---------|
| `OK` | Already at latest `main`; SHA shown for confirmation |
| `UPDATE` | Pulled new commits; `before → after` SHAs shown |
| `ERROR` | `git fetch` failed — likely offline; cached data still usable |
| `SKIP` | Directory exists but is not a git repo |

**INSTALLED PLUGIN VERSION CHECK** — Compares installed version (from `installed_plugins.json`) against the freshly-pulled marketplace listing, for `l3digitalnet-plugins` only. Does **not** reflect what is actually running — see LIVE MCP PROCESS CHECK below.


| Label | Meaning |
|-------|---------|
| `STALE` | Installed version differs from marketplace; reinstall needed |
| `CURRENT` | Installed version matches marketplace |

**LIVE MCP PROCESS CHECK** — Compares the version embedded in the path of each running Node.js MCP process against the version in `installed_plugins.json`:

| Label | Meaning |
|-------|---------|
| `LIVE_OK` | Running process path version matches installed version |
| `LIVE_SKEW` | Running process started from an older path; `installed_plugins.json` was updated mid-session but Claude Code didn't restart the process. **Normal reinstall won't fix this — use the hot-patch procedure below.** |
| `NOT_RUNNING` | Plugin is installed but no live process found (MCP not started, or non-MCP plugin) |

**ORPHANED CACHE DIRS** — Directories under `~/.claude/plugins/cache/l3digitalnet-plugins/<plugin>/` not referenced by any active install path. These include old version snapshots from prior installs and flat-format directories from early cache layouts — all safe to delete.

### Step 3 — Summarize and act

After the script completes, present findings concisely:

- **All current**: confirm the cache is fully fresh.
- **Stale plugins**: list each with `old → new` version. Offer to guide reinstallation.
- **Orphaned directories**: list sizes, offer to delete with `rm -rf`.
- **Fetch errors**: note which marketplaces failed; cache reflects last-known state.

## Reinstalling a Stale Plugin

Plugin content is a snapshot written at install time — the cache does not auto-update when a plugin is republished. To update:

1. Remove the stale entry from `~/.claude/plugins/installed_plugins.json` (the plugin's key under `"plugins"`).
2. Delete the stale cache directory: `rm -rf ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`.
3. Reinstall: `claude plugin install <plugin-name>@<marketplace>`.

Alternatively, if the user wants to bulk-refresh all l3digitalnet plugins, re-adding the marketplace is the fastest path:

```bash
claude plugin remove-marketplace l3digitalnet-plugins
claude plugin add-marketplace <marketplace-url>
# then reinstall each plugin
```

> **Note for MCP server plugins**: Steps 1–3 above update the registry and cache but do **not** update the live process. See "MCP Live Process Skew" below.

## MCP Live Process Skew

**When it occurs:** Claude Code reads `installed_plugins.json` once at IDE startup and caches the MCP server command (path + args). Subsequent changes to `installed_plugins.json` — including a reinstall — are invisible to the running session. The old process keeps running from its original path until the session restarts.

**Symptom:** The LIVE PROCESS CHECK reports `LIVE_SKEW`: `installed_plugins.json` points to the new version path but the running process started from the old version path.

**Why standard reinstall fails mid-session:** Updating `installed_plugins.json` to point to the new path only affects the *next* session start. The current session's MCP command is already locked in.

**Hot-patch fix (mid-session):**

```bash
# 1. Overwrite the running version's dist with the new version's dist
cp ~/.claude/plugins/cache/<marketplace>/<plugin>/<NEW>/dist/index.js \
   ~/.claude/plugins/cache/<marketplace>/<plugin>/<RUNNING>/dist/index.js

# 2. Kill the old process — Claude Code will restart it from the (now-patched) path
kill <pid>
# PID appears in: ps aux | grep <plugin-name>
```

The hot-patch works because Claude Code restarts crashed MCP processes from the same cached command path. After the kill, it restarts from `<RUNNING>/dist/index.js` — which now contains the new code.

**Clean fix (next session):** After the hot-patch, update `installed_plugins.json` to point to `<NEW>` so the next session starts clean. No hot-patch needed at that point.

## Key File Paths

| Path | Purpose |
|------|---------|
| `~/.claude/plugins/marketplaces/<name>/` | Git clone of each marketplace repo |
| `~/.claude/plugins/installed_plugins.json` | Install registry — source of truth for what's loaded |
| `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` | Installed plugin content snapshots |

## Important Constraints

- **Marketplace cache tracks `main`, not `testing`** — the index only reflects published/deployed versions. Commits on `testing` that haven't been merged to `main` will not appear as updates.
- **Version comparison is exact string match** — `0.3.0` vs `v0.3.0` would show as stale even if semantically identical. The marketplace.json and plugin.json should use consistent formatting (no `v` prefix).
- **SHA-versioned plugins** (those from `claude-plugins-official` installed without a semver tag) are skipped because the marketplace may not expose a comparable version string.
