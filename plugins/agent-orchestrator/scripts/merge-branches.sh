#!/bin/bash
# Merge each orchestrator branch back into the base branch.
# Handles one branch at a time so merge conflicts are isolated.
# Stops on first conflict for manual/agent resolution.

set -euo pipefail

# Detect base branch
BASE=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)
echo "Merging orchestrator branches into $BASE..."

# Find orchestrator branches (trim leading and trailing whitespace)
BRANCHES=$(git branch --list 'orchestrator/*' | sed 's/^[* ]*//; s/[[:space:]]*$//')

if [ -z "$BRANCHES" ]; then
  echo "No orchestrator branches found. Nothing to merge."
  exit 0
fi

for branch in $BRANCHES; do
  echo ""
  echo "--- Merging $branch ---"

  # Check if branch has any commits beyond base
  COMMIT_COUNT=$(git log "$BASE..$branch" --oneline 2>/dev/null | wc -l)
  if [ "$COMMIT_COUNT" -eq 0 ]; then
    echo "  Skipping $branch — no commits."
    continue
  fi

  if ! git merge --no-ff "$branch" -m "Orchestrator: merge $branch"; then
    echo ""
    echo "  CONFLICT in $branch — stopping for resolution."
    echo "  Resolve the conflict, then re-run this script for remaining branches."
    exit 1
  fi

  echo "  Merged $branch successfully ($COMMIT_COUNT commits)."
done

echo ""
echo "=== All orchestrator branches merged ==="
