#!/usr/bin/env bash
set -euo pipefail

# ensure-deps.sh — Lazy dependency installer for gh-manager helper
#
# Checks if node_modules exists in the helper directory.
# If missing, installs dependencies automatically.
# Idempotent: runs silently when deps are already installed.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HELPER_DIR="$SCRIPT_DIR/../helper"

# Check Node.js is available
if ! command -v node &>/dev/null; then
    echo "ERROR: Node.js is not installed. gh-manager requires Node.js 18+."
    echo "Install it from https://nodejs.org/ or via your package manager."
    exit 1
fi

# Check Node.js version (need 18+)
NODE_MAJOR=$(node -e "process.stdout.write(String(process.versions.node.split('.')[0]))")
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "ERROR: Node.js $NODE_MAJOR.x detected. gh-manager requires Node.js 18+."
    echo "Current: $(node --version)"
    exit 1
fi

# If node_modules exists and has @octokit, deps are installed
if [ -d "$HELPER_DIR/node_modules/@octokit" ]; then
    exit 0
fi

# Dependencies missing — install them
echo "First-run setup: installing gh-manager dependencies..."

if ! command -v npm &>/dev/null; then
    echo "ERROR: npm is not available. Install Node.js 18+ (includes npm)."
    exit 1
fi

cd "$HELPER_DIR"
npm install --omit=dev --no-audit --no-fund 2>&1

echo "Dependencies installed successfully."
