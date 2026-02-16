#!/bin/bash
# Setup git hooks for this repository

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Setting up git hooks..."

# Configure git to use .githooks directory
git config core.hooksPath .githooks

echo "✓ Git hooks configured"
echo ""
echo "Active hooks:"
ls -1 "$REPO_ROOT/.githooks/" | grep -v "\.sample$" | while read -r HOOK; do
    echo "  - $HOOK"
done
echo ""
echo "Hooks are now active. Run 'git commit' to test."
