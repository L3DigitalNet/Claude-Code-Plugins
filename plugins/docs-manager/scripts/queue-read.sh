#!/usr/bin/env bash
# Reads and displays the docs-manager queue.
# Merges fallback queue first if present. Always exits 0.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
QUEUE_FILE="$DOCS_MANAGER_HOME/queue.json"
FALLBACK_FILE="$DOCS_MANAGER_HOME/queue.fallback.json"

merge_fallback() {
    [[ ! -f "$FALLBACK_FILE" ]] && return 0
    [[ ! -f "$QUEUE_FILE" ]] && { mv "$FALLBACK_FILE" "$QUEUE_FILE"; return 0; }

    local tmp="$QUEUE_FILE.tmp.$$"
    # Merge fallback items into main queue, deduplicating by doc-path + type
    jq -s '
        .[0] as $main | .[1].items as $fb |
        ($main.items | map(.["doc-path"] + "|" + .type)) as $existing |
        ($fb | map(select((.["doc-path"] + "|" + .type) as $key | $existing | index($key) | not))) as $new |
        $main | .items += $new
    ' "$QUEUE_FILE" "$FALLBACK_FILE" > "$tmp" 2>/dev/null \
        && mv "$tmp" "$QUEUE_FILE" && rm -f "$FALLBACK_FILE" \
        || rm -f "$tmp"
}

main() {
    local mode="human" status_filter="" json_flag=false count_flag=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)   json_flag=true;     shift ;;
            --count)  count_flag=true;    shift ;;
            --status) status_filter="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    # Merge fallback if present
    merge_fallback

    # Ensure queue exists
    if [[ ! -f "$QUEUE_FILE" ]]; then
        $count_flag && echo "0" && return 0
        $json_flag && echo '{"items":[]}' && return 0
        echo "Queue empty — 0 items"
        return 0
    fi

    # Apply status filter
    local items_query='.items'
    if [[ -n "$status_filter" ]]; then
        items_query=".items | map(select(.status == \"$status_filter\"))"
    fi

    # Sort: critical first, then by detected-at
    local sorted_query="$items_query | sort_by(if .priority == \"critical\" then 0 else 1 end, .[\"detected-at\"])"

    # Count mode
    if $count_flag; then
        jq "$sorted_query | length" "$QUEUE_FILE"
        return 0
    fi

    # JSON mode
    if $json_flag; then
        jq "{items: ($sorted_query)}" "$QUEUE_FILE"
        return 0
    fi

    # Human-readable mode
    local count
    count=$(jq "$sorted_query | length" "$QUEUE_FILE")

    if [[ "$count" -eq 0 ]]; then
        echo "Queue empty — 0 items"
        return 0
    fi

    echo "$count queued documentation item(s):"
    echo ""

    # Table output
    jq -r "$sorted_query | .[] |
        \"  \" + .id + \"  \" + .type + \"  \" + .[\"doc-path\"] + \"  [\" + .library + \"]\"" \
        "$QUEUE_FILE"
}

if ! main "$@"; then
    echo "Queue empty — 0 items"
fi
exit 0
