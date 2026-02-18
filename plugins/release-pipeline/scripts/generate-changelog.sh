#!/usr/bin/env bash
set -euo pipefail

# generate-changelog.sh — Generate a Keep a Changelog entry from git commits.
#
# Usage: generate-changelog.sh <repo-path> <new-version>
# Output: the formatted changelog entry (stdout)
# Side effect: prepends entry to CHANGELOG.md (creates if missing)
# Exit:   0 = success, 1 = error
#
# Categorizes commits by conventional-commit prefix:
#   feat:                        → Added
#   fix:                         → Fixed
#   refactor: chore: docs: etc.  → Changed
#   No prefix                    → Changed

# ---------- Argument handling ----------

if [[ $# -lt 2 ]]; then
  echo "Usage: generate-changelog.sh <repo-path> <new-version>" >&2
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

TODAY="$(date +%Y-%m-%d)"

# ---------- Collect commits ----------

# Find the last tag. If none exists, use all commits.
last_tag=""
if git -C "$REPO" describe --tags --abbrev=0 &>/dev/null; then
  last_tag="$(git -C "$REPO" describe --tags --abbrev=0)"
fi

if [[ -n "$last_tag" ]]; then
  commits="$(git -C "$REPO" log "${last_tag}..HEAD" --oneline --no-merges)"
else
  commits="$(git -C "$REPO" log --oneline --no-merges)"
fi

# ---------- Categorize commits ----------

added=""
changed=""
fixed=""

while IFS= read -r line; do
  # Skip empty lines.
  [[ -z "$line" ]] && continue

  # Strip the short SHA prefix (first word).
  msg="${line#* }"

  # Match conventional commit prefixes (with optional scope).
  if [[ "$msg" =~ ^feat(\(.*\))?:\ *(.*) ]]; then
    added="${added}- ${BASH_REMATCH[2]}"$'\n'
  elif [[ "$msg" =~ ^fix(\(.*\))?:\ *(.*) ]]; then
    fixed="${fixed}- ${BASH_REMATCH[2]}"$'\n'
  elif [[ "$msg" =~ ^(refactor|chore|docs|style|perf|build|ci|test)(\(.*\))?:\ *(.*) ]]; then
    changed="${changed}- ${BASH_REMATCH[3]}"$'\n'
  else
    # No recognized prefix — default to Changed.
    changed="${changed}- ${msg}"$'\n'
  fi
done <<< "$commits"

# ---------- Build the entry ----------

entry="## [${VERSION}] - ${TODAY}"$'\n'

if [[ -n "$added" ]]; then
  entry+=$'\n'"### Added"$'\n'
  entry+="${added}"
fi

if [[ -n "$changed" ]]; then
  entry+=$'\n'"### Changed"$'\n'
  entry+="${changed}"
fi

if [[ -n "$fixed" ]]; then
  entry+=$'\n'"### Fixed"$'\n'
  entry+="${fixed}"
fi

# ---------- Output to stdout ----------

printf '%s' "$entry"

# ---------- Prepend to CHANGELOG.md ----------

changelog="$REPO/CHANGELOG.md"

if [[ -f "$changelog" ]]; then
  # Insert the new entry before the first existing ## line.
  tmpfile="$(mktemp)"
  trap 'rm -f "$tmpfile"' EXIT

  inserted=false
  while IFS= read -r cline; do
    if [[ "$inserted" == false && "$cline" =~ ^##\  ]]; then
      # Insert new entry with a trailing blank line before the old entry.
      printf '%s\n\n' "$entry" >> "$tmpfile"
      inserted=true
    fi
    printf '%s\n' "$cline" >> "$tmpfile"
  done < "$changelog"

  # If no ## line was found (unusual), append the entry at the end.
  if [[ "$inserted" == false ]]; then
    printf '\n%s\n' "$entry" >> "$tmpfile"
  fi

  mv "$tmpfile" "$changelog"
  trap - EXIT
else
  # Create a new CHANGELOG.md with a standard header.
  {
    printf '# Changelog\n\n'
    printf 'All notable changes to this project will be documented in this file.\n\n'
    printf 'The format is based on [Keep a Changelog](https://keepachangelog.com/).\n\n'
    printf '%s\n' "$entry"
  } > "$changelog"
fi

echo "CHANGELOG.md updated." >&2

exit 0
