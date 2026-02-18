#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER_DIR="$SCRIPT_DIR/../helper"

echo "📦 Installing gh-manager helper dependencies..."
cd "$HELPER_DIR"
npm install --omit=dev

echo ""
echo "✅ gh-manager helper installed"
echo ""
echo "Next steps:"
echo "  1. Set GITHUB_PAT environment variable:"
echo "     export GITHUB_PAT=ghp_your_token_here"
echo ""
echo "  2. Verify authentication:"
echo "     node $HELPER_DIR/bin/gh-manager.js auth verify"
echo ""
echo "  3. Use /repo-manager in Claude Code to get started"
