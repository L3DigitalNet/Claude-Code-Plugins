#!/usr/bin/env bash
# Stop hook handler — surfaces queue summary at session end.
# Outputs nothing if queue is empty. Always exits 0.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/scripts}"
[[ -z "$SCRIPTS_DIR" ]] && SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

main() {
    local count
    count=$(bash "$SCRIPTS_DIR/queue-read.sh" --count 2>/dev/null || echo "0")

    if [[ "$count" -gt 0 ]]; then
        echo "Session ending with $count queued documentation item(s). Run \`/docs queue review\` to review, or \`/docs queue clear --reason '...'\` to dismiss all."
    fi

    # Write last-fired timestamp
    mkdir -p "$DOCS_MANAGER_HOME/hooks"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$DOCS_MANAGER_HOME/hooks/stop.last-fired"
}

if ! main; then
    : # Silent — never disrupt session shutdown
fi
exit 0
