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
# Sync is one-way (local → cache), skipping .git, node_modules, and runtime
# state dirs. Only plugins that are already installed (cache dir exists) are
# synced — this won't silently create new installs.
#
# Called by: release-pipeline hooks.json → SessionStart

set -euo pipefail

CACHE_DIR="$HOME/.claude/plugins/cache/l3digitalnet-plugins"

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
    [ "$(marketplace_name "$candidate")" = "l3digitalnet-plugins" ] || continue
    echo "$candidate"
    return 0
  done
  return 1
}

repo=$(find_repo) || exit 0

# --- Sync each plugin that is installed in the cache ---

synced=()

for plugin_src in "$repo/plugins"/*/; do
  [ -d "$plugin_src" ] || continue
  plugin_name=$(basename "$plugin_src")
  plugin_cache="$CACHE_DIR/$plugin_name"

  # Only sync plugins that are already installed — don't create new installs
  [ -d "$plugin_cache" ] || continue

  # Capture all rsync output — "cannot delete non-empty directory" warnings from
  # stale cache dirs are harmless but would pollute Claude's context if printed.
  if ! rsync -a --delete \
    --exclude='.git/' \
    --exclude='node_modules/' \
    --exclude='.pth/' \
    --exclude='.claude/' \
    --exclude='*.js.map' \
    --exclude='*.d.ts.map' \
    "$plugin_src" "$plugin_cache/" \
    > /dev/null 2>&1; then
    # rsync not available or failed — fall back to cp (no --delete equivalent).
    # Swallowing cp failure here would silently leave the cache out of date, which
    # is worse than surfacing the warning and letting the session continue.
    if ! cp -r "$plugin_src/." "$plugin_cache/"; then
      printf '[release-pipeline] Warning: failed to sync %s to cache (both rsync and cp failed)\n' "$plugin_name"
    fi
  fi

  synced+=("$plugin_name")
done

if [ ${#synced[@]} -gt 0 ]; then
  printf '[release-pipeline] Synced %d plugin(s) to cache:\n' "${#synced[@]}"
  printf '  - %s\n' "${synced[@]}"
fi

exit 0
