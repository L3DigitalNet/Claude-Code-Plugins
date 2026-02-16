#!/bin/bash
# Remove all orchestration state. Run when the user chooses "clean up" in Phase 3.6.

set -euo pipefail

echo "Cleaning up orchestration state..."

# Remove state directory
if [ -d ".claude/state" ]; then
  rm -rf .claude/state/
  echo "  Removed .claude/state/"
fi

# Remove gitignore entries
if [ -f ".gitignore" ]; then
  sed -i '/^\.claude\/state\/$/d; /^\.worktrees\/$/d' .gitignore
  echo "  Cleaned .gitignore entries"
fi

echo "=== Orchestration state cleanup complete ==="
