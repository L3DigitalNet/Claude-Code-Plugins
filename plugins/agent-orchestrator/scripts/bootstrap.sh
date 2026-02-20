#!/bin/bash
# Orchestrator bootstrap — creates state directory, ledger, teammate protocol, gitignore entries.
# Run once at the start of Phase 2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create state directory
mkdir -p .claude/state

# Gitignore orchestration artifacts
touch .gitignore  # Ensure file exists before appending
for pattern in ".claude/state/" ".worktrees/"; do
  grep -qxF "$pattern" .gitignore || echo "$pattern" >> .gitignore
done

# Copy ledger template
cp "$SCRIPT_DIR/../templates/ledger.md" .claude/state/ledger.md

# Copy teammate protocol
cp "$SCRIPT_DIR/../templates/teammate-protocol.md" .claude/state/teammate-protocol.md

echo "✓ Bootstrap complete — .claude/state/ ready."
echo "  Next: update ledger placeholders in .claude/state/ledger.md"
