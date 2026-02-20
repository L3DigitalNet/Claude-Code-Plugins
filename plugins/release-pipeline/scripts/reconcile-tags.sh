#!/usr/bin/env bash
set -euo pipefail

# reconcile-tags.sh — Compare local vs remote tag state before a release push.
#
# Usage: reconcile-tags.sh <repo-path> <tag>
# Output (stdout): MISSING | LOCAL_ONLY | BOTH | REMOTE_ONLY
#   MISSING    — tag absent everywhere: create and push normally
#   LOCAL_ONLY — tag local only: push will create it; no git tag -a needed
#   BOTH       — tag on local and remote: skip git tag -a, verify GitHub release
#   REMOTE_ONLY— tag remote only: auto-fetched to local; treat as BOTH
# Exit: 0 = resolved state (proceed), 1 = unrecoverable conflict

if [[ $# -lt 2 ]]; then
  echo "Usage: reconcile-tags.sh <repo-path> <tag>" >&2
  exit 1
fi

REPO="$1"
TAG="$2"

if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

local_exists=false
remote_exists=false

# Check local tags — use fixed-string matching to avoid regex injection
# from tag names containing dots, brackets, or other metacharacters
if git -C "$REPO" tag -l "$TAG" | grep -qF "${TAG}" 2>/dev/null; then
  local_exists=true
fi

# Check remote tags (ls-remote outputs "SHA refs/tags/TAG" when found)
# -F: fixed-string match avoids metacharacter issues; no anchor needed since
# "refs/tags/TAG" is unique enough in ls-remote output
if git -C "$REPO" ls-remote --tags origin "refs/tags/${TAG}" 2>/dev/null \
    | grep -qF "refs/tags/${TAG}"; then
  remote_exists=true
fi

if [[ "$local_exists" == false && "$remote_exists" == false ]]; then
  echo "MISSING"
  exit 0
fi

if [[ "$local_exists" == true && "$remote_exists" == false ]]; then
  echo "LOCAL_ONLY"
  exit 0
fi

if [[ "$local_exists" == true && "$remote_exists" == true ]]; then
  echo "BOTH"
  exit 0
fi

# REMOTE_ONLY: tag exists on remote but not local — auto-fetch to sync
if git -C "$REPO" fetch origin "refs/tags/${TAG}:refs/tags/${TAG}" >/dev/null 2>&1; then
  echo "REMOTE_ONLY"
  echo "Auto-fetched remote tag ${TAG} to local." >&2
  exit 0
else
  echo "REMOTE_ONLY"
  echo "Warning: could not fetch remote tag ${TAG} — push may fail." >&2
  exit 1
fi
