#!/usr/bin/env bash
# sync-local-plugins.sh — SessionStart hook.
#
# Syncs local plugin source from the development repo to the installed Claude
# Code cache so that in-session plugin changes take effect without reinstalling.
#
# Discovery order for the local repo:
#   1. $CLAUDE_PROJECT_DIR — if it contains plugins/ and the right marketplace.json
#   2. $HOME/projects/Claude-Code-Plugins — fallback hardcoded path
#
# Sync is one-way (local → cache), using the installPath from installed_plugins.json
# as the sync destination. This ensures CLAUDE_PLUGIN_ROOT (which Claude Code derives
# from installPath) resolves to a directory that actually contains the plugin files.
#
# Only plugins that are already installed (installPath dir exists) are synced —
# this won't silently create new installs.
#
# Called by: release-pipeline hooks.json → SessionStart

set -euo pipefail

CACHE_DIR="$HOME/.claude/plugins/cache/l3digitalnet-plugins"
INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"
MARKETPLACE="l3digitalnet-plugins"

# Nothing to do if the plugin isn't even installed
[ -d "$CACHE_DIR" ] || exit 0

# --- Find the local development repo ---

marketplace_name() {
  # Reads name field from marketplace.json; returns empty string on failure
  local mf="$1/.claude-plugin/marketplace.json"
  [ -f "$mf" ] || return 0
  python3 -c "
import json, sys
try:
    print(json.load(open('$mf')).get('name', ''))
except Exception:
    print('')
" 2>/dev/null || true
}

find_repo() {
  for candidate in "${CLAUDE_PROJECT_DIR:-}" "$HOME/projects/Claude-Code-Plugins"; do
    [ -n "$candidate" ] || continue
    [ -d "$candidate/plugins" ] || continue
    [ "$(marketplace_name "$candidate")" = "$MARKETPLACE" ] || continue
    echo "$candidate"
    return 0
  done
  return 1
}

# Look up the registered installPath for a plugin from installed_plugins.json.
# Claude Code sets CLAUDE_PLUGIN_ROOT from installPath, so syncing to any other
# directory won't be visible to plugin scripts at runtime.
# Falls back to the flat CACHE_DIR/<name> path if installed_plugins.json is missing
# or the plugin isn't listed (e.g. older Claude Code versions without versioned paths).
plugin_install_path() {
  local plugin_name="$1"
  local key="${plugin_name}@${MARKETPLACE}"

  if [ -f "$INSTALLED_PLUGINS" ]; then
    local path
    path=$(python3 -c "
import json, sys
try:
    d = json.load(open('$INSTALLED_PLUGINS'))
    entry = d.get('plugins', {}).get('$key', [])
    if entry and isinstance(entry, list):
        print(entry[0].get('installPath', ''))
    else:
        print('')
except Exception:
    print('')
" 2>/dev/null || true)
    if [ -n "$path" ]; then
      echo "$path"
      return 0
    fi
  fi

  # Fallback: older Claude Code versions use flat unversioned paths
  echo "$CACHE_DIR/$plugin_name"
}

repo=$(find_repo) || exit 0

# --- Sync each plugin that is installed in the cache ---

synced=()
# Tracks plugins where rsync actually transferred files — used to suppress output
# when all plugins were already up to date (no files changed = no action needed).
changed=()

for plugin_src in "$repo/plugins"/*/; do
  [ -d "$plugin_src" ] || continue
  plugin_name=$(basename "$plugin_src")
  plugin_cache=$(plugin_install_path "$plugin_name")

  # Only sync plugins that are already installed — don't create new installs
  [ -d "$plugin_cache" ] || continue

  # --itemize-changes outputs one line per transferred file; empty = nothing changed.
  # Captures stdout (file change lines) while suppressing stderr (harmless "cannot
  # delete non-empty directory" warnings from stale cache dirs).
  rsync_output=""
  if rsync_output=$(rsync -a --delete --itemize-changes \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='.pth/' \
    --exclude='.claude/' \
    --exclude='*.js.map' \
    --exclude='*.d.ts.map' \
    "$plugin_src" "$plugin_cache/" 2>/dev/null); then
    if [ -n "$rsync_output" ]; then
      changed+=("$plugin_name")
    fi
  else
    # rsync not available or failed — fall back to cp (no --delete equivalent).
    # Swallowing cp failure here would silently leave the cache out of date, which
    # is worse than surfacing the warning and letting the session continue.
    if ! cp -r "$plugin_src/." "$plugin_cache/"; then
      printf '[release-pipeline] Warning: failed to sync %s to cache (both rsync and cp failed)\n' "$plugin_name"
    fi
    # cp doesn't report what changed — assume something did to be safe
    changed+=("$plugin_name")
  fi

  synced+=("$plugin_name")
done

# Only print when files actually changed — suppress routine "nothing changed" noise
if [ ${#changed[@]} -gt 0 ]; then
  printf '[release-pipeline] Synced %d plugin(s) to cache:\n' "${#changed[@]}"
  printf '  - %s\n' "${changed[@]}"
fi

exit 0
