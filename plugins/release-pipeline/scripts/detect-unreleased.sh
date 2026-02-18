#!/usr/bin/env bash
set -euo pipefail

# detect-unreleased.sh — List plugins with unreleased changes.
#
# Usage: detect-unreleased.sh <repo-path>
# Output: TSV lines: plugin-name  current-version  commit-count  last-tag
# Exit:   0 = at least one plugin found, 1 = not a monorepo or error

# ---------- Argument handling ----------

if [[ $# -lt 1 ]]; then
  echo "Usage: detect-unreleased.sh <repo-path>" >&2
  exit 1
fi

REPO="$1"

# Verify directory exists, then resolve to absolute path.
if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

# ---------- Monorepo detection ----------

MARKETPLACE="$REPO/.claude-plugin/marketplace.json"

if [[ ! -f "$MARKETPLACE" ]]; then
  echo "Error: no marketplace.json found at $MARKETPLACE" >&2
  exit 1
fi

# Parse plugin names, versions, and source paths from marketplace.json.
# Output: one line per plugin as "name|version|source"
plugin_data=$(python3 -c "
import json, sys
with open('$MARKETPLACE') as f:
    data = json.load(f)
plugins = data.get('plugins', [])
if len(plugins) < 2:
    sys.exit(1)
for p in plugins:
    name = p.get('name', '')
    version = p.get('version', '')
    source = p.get('source', '')
    print(f'{name}|{version}|{source}')
") || {
  echo "Error: not a monorepo (fewer than 2 plugins in marketplace.json)" >&2
  exit 1
}

# ---------- Scan each plugin for unreleased commits ----------

found=0

while IFS='|' read -r name version source; do
  [[ -z "$name" ]] && continue

  # Resolve plugin directory from source path (strip leading ./).
  plugin_dir="${source#./}"

  # Find latest tag matching plugin-name/v*
  last_tag=""
  last_tag=$(git -C "$REPO" tag -l "${name}/v*" --sort=-v:refname | head -1) || true

  # Count commits since tag (or all commits) touching the plugin directory.
  if [[ -n "$last_tag" ]]; then
    commit_count=$(git -C "$REPO" log --oneline "${last_tag}..HEAD" -- "$plugin_dir/" | wc -l)
  else
    commit_count=$(git -C "$REPO" log --oneline -- "$plugin_dir/" | wc -l)
    last_tag="(none)"
  fi

  # Trim whitespace from wc -l output.
  commit_count="${commit_count// /}"

  # Only output plugins with unreleased changes.
  if [[ "$commit_count" -gt 0 ]]; then
    printf '%s\t%s\t%s\t%s\n' "$name" "$version" "$commit_count" "$last_tag"
    found=$((found + 1))
  fi
done <<< "$plugin_data"

if [[ "$found" -eq 0 ]]; then
  echo "No plugins with unreleased changes." >&2
  exit 0
fi

exit 0
