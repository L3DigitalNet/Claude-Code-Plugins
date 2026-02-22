#!/usr/bin/env bash
set -euo pipefail

# auto-stash.sh — Auto-stash and restore dirty working tree before/after release.
#
# Usage: auto-stash.sh <repo-path> <stash|pop|check>
#   stash: if dirty, creates a stash and prints "STASHED"; prints "CLEAN" if already clean
#   pop:   restores the release-pipeline stash if one exists; prints "RESTORED" or "NO_STASH"
#   check: prints "DIRTY" or "CLEAN"
#
# Exit: 0 = success, 1 = error
#
# Stash marker "release-pipeline-autostash" identifies our stash for safe pop.
# Only pops a stash we created — never pops a user's pre-existing stash.
#
# Called by: templates/mode-2-full-release.md (Phase 0.5 and Phase 3.5),
#            templates/mode-3-plugin-release.md (same),
#            templates/mode-7-batch-release.md (before/after plugin loop — one stash for entire batch)

STASH_MARKER="release-pipeline-autostash"

if [[ $# -lt 2 ]]; then
  echo "Usage: auto-stash.sh <repo-path> stash|pop|check" >&2
  exit 1
fi

REPO="$1"
COMMAND="$2"

if [[ ! -d "$REPO" ]]; then
  echo "Error: directory '$REPO' does not exist" >&2
  exit 1
fi
REPO="$(cd "$REPO" && pwd)"

case "$COMMAND" in
  check)
    status=$(git -C "$REPO" status --porcelain 2>/dev/null || true)
    if [[ -n "$status" ]]; then
      echo "DIRTY"
    else
      echo "CLEAN"
    fi
    ;;

  stash)
    status=$(git -C "$REPO" status --porcelain 2>/dev/null || true)
    if [[ -z "$status" ]]; then
      echo "CLEAN"
      exit 0
    fi
    # --include-untracked captures new files not yet staged.
    # The marker in the message lets us find exactly this stash for safe pop.
    if git -C "$REPO" stash push --include-untracked \
        -m "${STASH_MARKER}: $(date +%Y%m%d%H%M%S)" >/dev/null 2>&1; then
      echo "STASHED"
      echo "Auto-stashed dirty working tree — will restore after release." >&2
    else
      echo "Error: failed to stash working tree changes" >&2
      exit 1
    fi
    ;;

  pop)
    # Only pop if the top stash entry belongs to this tool — never pop user stashes.
    top_stash=$(git -C "$REPO" stash list 2>/dev/null | head -1 || true)
    if [[ "$top_stash" != *"$STASH_MARKER"* ]]; then
      echo "NO_STASH"
      echo "No release-pipeline stash found — nothing to restore." >&2
      exit 0
    fi
    if git -C "$REPO" stash pop >/dev/null 2>&1; then
      echo "RESTORED"
      echo "Restored auto-stashed working tree changes." >&2
    else
      echo "Error: stash pop failed — run 'git stash pop' manually" >&2
      exit 1
    fi
    ;;

  *)
    echo "Error: unknown command '${COMMAND}'. Use: stash | pop | check" >&2
    exit 1
    ;;
esac

exit 0
