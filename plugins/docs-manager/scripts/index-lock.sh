#!/usr/bin/env bash
# Acquires a write lock on the docs-manager index.
# Checks for stale locks from dead PIDs. Times out after 5 seconds.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
LOCK_FILE="$DOCS_MANAGER_HOME/index.lock"

main() {
    local operation="unknown"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --operation) operation="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    local timeout=5
    local waited=0

    while [[ -f "$LOCK_FILE" ]]; do
        # Read PID from lock
        local lock_pid
        lock_pid=$(jq -r '.pid' "$LOCK_FILE" 2>/dev/null || echo "0")

        # Check if process is alive
        if ! kill -0 "$lock_pid" 2>/dev/null; then
            # Stale lock — remove it
            rm -f "$LOCK_FILE"
            break
        fi

        # Same PID = idempotent
        if [[ "$lock_pid" == "$$" ]]; then
            return 0
        fi

        # Wait
        sleep 1
        waited=$((waited + 1))
        if [[ "$waited" -ge "$timeout" ]]; then
            echo "Error: index lock timeout after ${timeout}s (held by PID $lock_pid)" >&2
            return 1
        fi
    done

    # Acquire lock atomically
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local tmp="$LOCK_FILE.tmp.$$"
    printf '{"pid":%d,"acquired":"%s","operation":"%s"}\n' "$$" "$now" "$operation" > "$tmp"
    mv "$tmp" "$LOCK_FILE"
}

main "$@"
