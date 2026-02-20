#!/usr/bin/env bash
# Merges fallback queue into main queue, deduplicating by doc-path + type.
# Called before queue reads. Deletes fallback file on success.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
QUEUE_FILE="$DOCS_MANAGER_HOME/queue.json"
FALLBACK_FILE="$DOCS_MANAGER_HOME/queue.fallback.json"

main() {
    [[ ! -f "$FALLBACK_FILE" ]] && return 0

    # If no main queue, just promote fallback
    if [[ ! -f "$QUEUE_FILE" ]]; then
        mv "$FALLBACK_FILE" "$QUEUE_FILE"
        return 0
    fi

    local tmp="$QUEUE_FILE.tmp.$$"
    jq -s '
        .[0] as $main | .[1].items as $fb |
        ($main.items | map(.["doc-path"] + "|" + .type)) as $existing |
        ($fb | map(select((.["doc-path"] + "|" + .type) as $key | $existing | index($key) | not))) as $new |
        $main | .items += $new
    ' "$QUEUE_FILE" "$FALLBACK_FILE" > "$tmp" 2>/dev/null \
        && mv "$tmp" "$QUEUE_FILE" && rm -f "$FALLBACK_FILE" \
        || { rm -f "$tmp"; return 1; }
}

main "$@"
