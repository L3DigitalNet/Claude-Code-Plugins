#!/usr/bin/env bash
set -euo pipefail

# bump-version.sh — Find and replace version strings across common project files.
#
# Usage: bump-version.sh <repo-path> <new-version>
# Output: list of files changed (stdout)
# Exit:   0 = at least one file updated, 1 = no version strings found or bad args
#
# Version targets (in order):
#   1. pyproject.toml          — version = "X.Y.Z"
#   2. package.json            — "version": "X.Y.Z"
#   3. Cargo.toml              — version = "X.Y.Z" (first occurrence only)
#   4. .claude-plugin/plugin.json — "version": "X.Y.Z"
#   5. __init__.py (recursive) — __version__ = "X.Y.Z"

# ---------- Argument handling ----------

if [[ $# -lt 2 ]]; then
  echo "Usage: bump-version.sh <repo-path> <new-version>" >&2
  exit 1
fi

REPO="$1"
VERSION="$2"

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
#   Runs sed in-place. If the file changed, prints and counts it.
bump_file() {
  local file="$1"
  local expr="$2"

  [[ -f "$file" ]] || return 0

  # Capture checksum before edit.
  local before
  before=$(md5sum "$file")

  sed -i -E "$expr" "$file"

  local after
  after=$(md5sum "$file")

  if [[ "$before" != "$after" ]]; then
    echo "Updated: $file"
    updated=$((updated + 1))
  fi
}

# ---------- 1. pyproject.toml ----------
bump_file "$REPO/pyproject.toml" \
  "s/^(version[[:space:]]*=[[:space:]]*\").*(\")/\1${VERSION}\2/"

# ---------- 2. package.json ----------
bump_file "$REPO/package.json" \
  "s/(\"version\"[[:space:]]*:[[:space:]]*\").*(\")/\1${VERSION}\2/"

# ---------- 3. Cargo.toml (first occurrence only) ----------
if [[ -f "$REPO/Cargo.toml" ]]; then
  local_file="$REPO/Cargo.toml"
  before=$(md5sum "$local_file")

  # Replace only the first version = "..." line (the [package] version).
  sed -i -E "0,/^version[[:space:]]*=[[:space:]]*\".*\"/{s/^(version[[:space:]]*=[[:space:]]*\").*(\")/\1${VERSION}\2/}" "$local_file"

  after=$(md5sum "$local_file")
  if [[ "$before" != "$after" ]]; then
    echo "Updated: $local_file"
    updated=$((updated + 1))
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

# ---------- Summary ----------
echo "${updated} file(s) updated"

if [[ "$updated" -eq 0 ]]; then
  echo "Warning: no version strings found to update" >&2
  exit 1
fi

exit 0
