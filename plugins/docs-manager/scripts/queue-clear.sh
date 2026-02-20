#!/usr/bin/env bash
# Clears the docs-manager queue, archiving items to session history.
# Requires --reason argument to prevent accidental dismissal.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
QUEUE_FILE="$DOCS_MANAGER_HOME/queue.json"
HISTORY_FILE="$DOCS_MANAGER_HOME/session-history.jsonl"

main() {
    local reason=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --reason) reason="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$reason" ]]; then
        echo "Error: --reason is required. Provide a reason for clearing the queue." >&2
        return 1
    fi

    [[ ! -f "$QUEUE_FILE" ]] && { echo "Cleared 0 items"; return 0; }

    local count
    count=$(jq '.items | length' "$QUEUE_FILE" 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 ]]; then
        echo "Cleared 0 items"
        return 0
    fi

    # Archive to session history (one JSONL entry per clear operation)
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    jq -c --arg reason "$reason" --arg ts "$now" \
        '{timestamp: $ts, action: "clear", reason: $reason, count: (.items | length), items: .items}' \
        "$QUEUE_FILE" >> "$HISTORY_FILE"

    # Reset queue items to empty
    local tmp="$QUEUE_FILE.tmp.$$"
    jq '.items = []' "$QUEUE_FILE" > "$tmp" && mv "$tmp" "$QUEUE_FILE"

    echo "Cleared $count item(s)"
}

main "$@"
