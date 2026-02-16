#!/bin/bash
# Remove worktrees and orchestrator branches after all merges are verified.
# Run ONLY after merge-branches.sh has completed successfully.

set -euo pipefail

echo "Cleaning up worktrees and branches..."

# Remove worktrees first (must happen before branch deletion)
if [ -d ".worktrees" ]; then
  for wt in .worktrees/*/; do
    if [ -d "$wt" ]; then
      echo "  Removing worktree: $wt"
      git worktree remove "$wt" --force 2>/dev/null || true
    fi
  done
  rmdir .worktrees 2>/dev/null || true
fi

# Delete orchestrator branches (safe delete — warns if unmerged)
BRANCHES=$(git branch --list 'orchestrator/*' | sed 's/^[* ]*//')
if [ -n "$BRANCHES" ]; then
  for branch in $BRANCHES; do
    echo "  Deleting branch: $branch"
    git branch -d "$branch" 2>/dev/null || echo "    WARNING: $branch has unmerged changes, skipping"
  done
fi

echo "=== Worktree cleanup complete ==="
