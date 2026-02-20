#!/usr/bin/env bash
set -euo pipefail

# bump-version.sh — Find and replace version strings across common project files.
#
# Usage: bump-version.sh <repo-path> <new-version> [--plugin <name>] [--dry-run]
# Output: list of files changed (or would-change) on stdout
# Exit:   0 = at least one file updated (or would update), 1 = no version strings found
#
# --dry-run: reports which files would change without writing any of them.
#
# Version targets (single-repo mode, no --plugin):
#   1. pyproject.toml          — version = "X.Y.Z"
#   2. package.json            — "version": "X.Y.Z"
#   3. Cargo.toml              — version = "X.Y.Z" (first occurrence only)
#   4. .claude-plugin/plugin.json — "version": "X.Y.Z"
#   5. __init__.py (recursive) — __version__ = "X.Y.Z"
#
# Version targets (monorepo mode, --plugin <name>):
#   6. plugins/<name>/.claude-plugin/plugin.json
#   7. .claude-plugin/marketplace.json (matching entry)

# ---------- Argument handling ----------

if [[ $# -lt 2 ]]; then
  echo "Usage: bump-version.sh <repo-path> <new-version> [--plugin <name>]" >&2
  exit 1
fi

REPO="$1"
VERSION="$2"

# ---------- Optional --plugin flag ----------
PLUGIN=""
if [[ $# -ge 4 && "$3" == "--plugin" ]]; then
  PLUGIN="$4"
  if [[ "$PLUGIN" =~ [/\\] ]]; then
    echo "Error: plugin name must not contain path separators" >&2
    exit 1
  fi
fi

# ---------- Optional --dry-run flag ----------
DRY_RUN=false
for arg in "$@"; do
  if [[ "$arg" == "--dry-run" ]]; then
    DRY_RUN=true
    break
  fi
done

# Strip leading 'v' if present (v1.2.0 -> 1.2.0).
VERSION="${VERSION#v}"

# Verify directory exists, then resolve to absolute path.
if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

updated=0

# ---------- Helper ----------
# bump_file <filepath> <sed-expression>
#   In live mode: runs sed in-place and prints the file if changed.
#   In dry-run mode: compares a tempfile to detect changes without writing.
bump_file() {
  local file="$1"
  local expr="$2"

  [[ -f "$file" ]] || return 0

  if [[ "$DRY_RUN" == true ]]; then
    # Apply sed to a temp copy; cmp detects changes without touching the original.
    local tmpfile
    tmpfile=$(mktemp)
    cp "$file" "$tmpfile"
    sed -i -E "$expr" "$tmpfile"
    if ! cmp -s "$file" "$tmpfile"; then
      echo "Would update: $file"
      updated=$((updated + 1))
    fi
    rm -f "$tmpfile"
  else
    local before
    before=$(md5sum "$file")
    sed -i -E "$expr" "$file"
    local after
    after=$(md5sum "$file")
    if [[ "$before" != "$after" ]]; then
      echo "Updated: $file"
      updated=$((updated + 1))
    fi
  fi
}

# ---------- Sections 1-5: single-repo mode (skip when --plugin is set) ----------
if [[ -z "$PLUGIN" ]]; then

# ---------- 1. pyproject.toml ----------
bump_file "$REPO/pyproject.toml" \
  "s/^(version[[:space:]]*=[[:space:]]*\").*(\")/\1${VERSION}\2/"

# ---------- 2. package.json ----------
bump_file "$REPO/package.json" \
  "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

# ---------- 3. Cargo.toml (first occurrence only) ----------
if [[ -f "$REPO/Cargo.toml" ]]; then
  local_file="$REPO/Cargo.toml"
  cargo_expr="0,/^version[[:space:]]*=[[:space:]]*\".*\"/{s/^(version[[:space:]]*=[[:space:]]*\").*(\")/\1${VERSION}\2/}"

  if [[ "$DRY_RUN" == true ]]; then
    tmpfile=$(mktemp)
    cp "$local_file" "$tmpfile"
    sed -i -E "$cargo_expr" "$tmpfile"
    if ! cmp -s "$local_file" "$tmpfile"; then
      echo "Would update: $local_file"
      updated=$((updated + 1))
    fi
    rm -f "$tmpfile"
  else
    before=$(md5sum "$local_file")
    sed -i -E "$cargo_expr" "$local_file"
    after=$(md5sum "$local_file")
    if [[ "$before" != "$after" ]]; then
      echo "Updated: $local_file"
      updated=$((updated + 1))
    fi
  fi
fi

# ---------- 4. .claude-plugin/plugin.json ----------
bump_file "$REPO/.claude-plugin/plugin.json" \
  "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

# ---------- 5. __init__.py files (recursive, skip .git .venv node_modules) ----------
if command -v find &>/dev/null; then
  while IFS= read -r -d '' initfile; do
    bump_file "$initfile" \
      "s/^(__version__[[:space:]]*=[[:space:]]*[\"']).*([\"'])/\1${VERSION}\2/"
  done < <(find "$REPO" \
    -path '*/.git' -prune -o \
    -path '*/.venv' -prune -o \
    -path '*/node_modules' -prune -o \
    -name '__init__.py' -print0)
fi

fi  # end single-repo mode

# ---------- 6. Monorepo plugin mode ----------
if [[ -n "$PLUGIN" ]]; then
  # 6a. Bump plugins/<name>/.claude-plugin/plugin.json
  bump_file "$REPO/plugins/$PLUGIN/.claude-plugin/plugin.json" \
    "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

  # Also try manifest.json (some plugins use this name)
  bump_file "$REPO/plugins/$PLUGIN/.claude-plugin/manifest.json" \
    "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

  # 6b. Bump the matching entry in marketplace.json
  MARKETPLACE="$REPO/.claude-plugin/marketplace.json"
  if [[ -f "$MARKETPLACE" ]]; then
    local_file="$MARKETPLACE"

    if [[ "$DRY_RUN" == true ]]; then
      # Check current version for this plugin without writing.
      current_ver=$(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for p in data.get('plugins', []):
    if p['name'] == sys.argv[2]:
        print(p.get('version', ''))
        break
" "$local_file" "$PLUGIN" 2>/dev/null || true)
      if [[ "$current_ver" != "$VERSION" ]]; then
        echo "Would update: $local_file (plugin: $PLUGIN)"
        updated=$((updated + 1))
      fi
    else
      before=$(md5sum "$local_file")
      # Use python3 for precise JSON manipulation (sed can't target specific array entries)
      python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for p in data.get('plugins', []):
    if p['name'] == sys.argv[2]:
        p['version'] = sys.argv[3]
        break
with open(sys.argv[1], 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$local_file" "$PLUGIN" "$VERSION"
      after=$(md5sum "$local_file")
      if [[ "$before" != "$after" ]]; then
        echo "Updated: $local_file (plugin: $PLUGIN)"
        updated=$((updated + 1))
      fi
    fi
  fi
fi

# ---------- Summary ----------
if [[ "$DRY_RUN" == true ]]; then
  echo "${updated} file(s) would be updated"
else
  echo "${updated} file(s) updated"
fi

if [[ "$updated" -eq 0 ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    echo "Warning: no version strings found that would be updated" >&2
  else
    echo "Warning: no version strings found to update" >&2
  fi
  exit 1
fi

exit 0
