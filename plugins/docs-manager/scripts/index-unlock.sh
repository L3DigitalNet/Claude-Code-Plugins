#!/usr/bin/env bash
# Releases the docs-manager index write lock.
# Only removes if current PID matches lock PID (safety check).
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
LOCK_FILE="$DOCS_MANAGER_HOME/index.lock"

main() {
    [[ ! -f "$LOCK_FILE" ]] && return 0

    local lock_pid
    lock_pid=$(jq -r '.pid' "$LOCK_FILE" 2>/dev/null || echo "0")

    # Safety: only remove our own lock, or stale locks from dead PIDs
    if [[ "$lock_pid" == "$$" ]] || ! kill -0 "$lock_pid" 2>/dev/null; then
        rm -f "$LOCK_FILE"
    fi
}

main "$@"
