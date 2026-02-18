#!/usr/bin/env bash
set -euo pipefail

# suggest-version.sh — Suggest a semver bump based on conventional commits.
#
# Usage: suggest-version.sh <repo-path> [--plugin <name>]
# Output: <suggested-version> <feat-count> <fix-count> <other-count>
#   e.g., "1.2.0 3 1 2"
# Exit:   0 = suggestion made, 1 = no previous tag or error

# ---------- Argument handling ----------

if [[ $# -lt 1 ]]; then
  echo "Usage: suggest-version.sh <repo-path> [--plugin <name>]" >&2
  exit 1
fi

REPO="$1"
shift

# ---------- Optional --plugin flag ----------
PLUGIN=""
if [[ $# -ge 2 && "$1" == "--plugin" ]]; then
  PLUGIN="$2"
  if [[ "$PLUGIN" =~ [/\\] ]]; then
    echo "Error: plugin name must not contain path separators" >&2
    exit 1
  fi
fi

# Verify directory exists, then resolve to absolute path.
if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

# ---------- Find last tag ----------

last_tag=""
path_filter=""

if [[ -n "$PLUGIN" ]]; then
  # Plugin mode: find the last plugin-name/v* tag and filter by plugin path.
  last_tag=$(git -C "$REPO" tag -l "${PLUGIN}/v*" --sort=-v:refname | head -1) || true
  path_filter="plugins/${PLUGIN}/"
else
  # Single-repo mode: find the last v* tag.
  if git -C "$REPO" describe --tags --abbrev=0 &>/dev/null; then
    last_tag="$(git -C "$REPO" describe --tags --abbrev=0)"
  fi
fi

# ---------- Parse current version from tag ----------

current_version=""
if [[ -n "$last_tag" ]]; then
  # Strip everything up to and including the last 'v' prefix.
  # Handles both "v1.2.3" and "plugin-name/v1.2.3".
  current_version="${last_tag##*/v}"
  # If there was no '/' (single-repo tag like v1.2.3), strip leading 'v'.
  current_version="${current_version#v}"
fi

# Default to 0.1.0 if no tag found.
if [[ -z "$current_version" ]]; then
  current_version="0.1.0"
fi

# Split into major.minor.patch.
IFS='.' read -r major minor patch <<< "$current_version"

# Ensure numeric values (default to 0 if parsing fails).
major="${major:-0}"
minor="${minor:-0}"
patch="${patch:-0}"

# ---------- Collect commits since last tag ----------

commits=""
if [[ -n "$last_tag" && -n "$path_filter" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges -- "$path_filter")" || true
elif [[ -n "$last_tag" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges)" || true
elif [[ -n "$path_filter" ]]; then
  commits="$(git -C "$REPO" log --oneline --no-merges -- "$path_filter")" || true
else
  commits="$(git -C "$REPO" log --oneline --no-merges)" || true
fi

# If no commits found, report and exit.
if [[ -z "$commits" ]]; then
  echo "No commits since last tag." >&2
  exit 1
fi

# ---------- Categorize commits ----------

feat_count=0
fix_count=0
other_count=0
has_breaking=false

while IFS= read -r line; do
  # Skip empty lines.
  [[ -z "$line" ]] && continue

  # Strip the short SHA prefix (first word).
  msg="${line#* }"

  # Detect breaking changes: "feat!:" or "fix!:" or "BREAKING CHANGE" in message.
  if [[ "$msg" =~ ^[a-z]+(\(.*\))?!: ]] || [[ "$msg" == *"BREAKING CHANGE"* ]]; then
    has_breaking=true
  fi

  # Categorize by conventional commit prefix.
  if [[ "$msg" =~ ^feat(\(.*\))?\!?:  ]]; then
    feat_count=$((feat_count + 1))
  elif [[ "$msg" =~ ^fix(\(.*\))?\!?:  ]]; then
    fix_count=$((fix_count + 1))
  else
    other_count=$((other_count + 1))
  fi
done <<< "$commits"

# ---------- Determine bump ----------

if [[ "$has_breaking" == true ]]; then
  # Breaking change → major bump.
  major=$((major + 1))
  minor=0
  patch=0
elif [[ "$feat_count" -gt 0 ]]; then
  # New features → minor bump.
  minor=$((minor + 1))
  patch=0
else
  # Fixes and other → patch bump.
  patch=$((patch + 1))
fi

new_version="${major}.${minor}.${patch}"

# ---------- Output ----------

echo "${new_version} ${feat_count} ${fix_count} ${other_count}"

exit 0
