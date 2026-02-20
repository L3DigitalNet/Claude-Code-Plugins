#!/usr/bin/env bash
# Appends a detection event to the docs-manager queue.
# Called by hook scripts. ALWAYS exits 0 — failures go to fallback queue.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
QUEUE_FILE="$DOCS_MANAGER_HOME/queue.json"
FALLBACK_FILE="$DOCS_MANAGER_HOME/queue.fallback.json"

main() {
    local type="" doc_path="" library="" trigger="" source_file="" priority="standard"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)        type="$2";        shift 2 ;;
            --doc-path)    doc_path="$2";    shift 2 ;;
            --library)     library="$2";     shift 2 ;;
            --trigger)     trigger="$2";     shift 2 ;;
            --source-file) source_file="$2"; shift 2 ;;
            --priority)    priority="$2";    shift 2 ;;
            *) return 1 ;;
        esac
    done

    [[ -z "$type" || -z "$doc_path" || -z "$library" || -z "$trigger" ]] && return 1

    # Ensure queue exists
    if [[ ! -f "$QUEUE_FILE" ]]; then
        mkdir -p "$(dirname "$QUEUE_FILE")"
        printf '{"created":"%s","items":[]}\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$QUEUE_FILE"
    fi

    # Deduplicate: skip if same doc-path + type already pending
    local exists
    exists=$(jq --arg dp "$doc_path" --arg t "$type" \
        '[.items[] | select(.["doc-path"] == $dp and .type == $t and .status == "pending")] | length' \
        "$QUEUE_FILE" 2>/dev/null || echo "0")
    [[ "$exists" -gt 0 ]] && return 0

    # Generate next ID
    local count
    count=$(jq '.items | length' "$QUEUE_FILE" 2>/dev/null || echo "0")
    local id
    id=$(printf "q-%03d" $((count + 1)))

    # Build entry
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local entry
    entry=$(jq -n \
        --arg id "$id" --arg type "$type" --arg doc_path "$doc_path" \
        --arg library "$library" --arg detected_at "$now" \
        --arg trigger "$trigger" --arg priority "$priority" \
        --arg source_file "$source_file" \
        '{id:$id, type:$type, "doc-path":$doc_path, library:$library,
          "detected-at":$detected_at, trigger:$trigger, priority:$priority,
          status:"pending", note:null}
         + (if $source_file != "" then {"source-file":$source_file} else {} end)')

    # Append atomically (temp file + mv)
    local tmp="$QUEUE_FILE.tmp.$$"
    if jq --argjson entry "$entry" '.items += [$entry]' "$QUEUE_FILE" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$QUEUE_FILE"
    else
        rm -f "$tmp"
        # Fallback queue
        if [[ -f "$FALLBACK_FILE" ]]; then
            local ftmp="$FALLBACK_FILE.tmp.$$"
            jq --argjson entry "$entry" '.items += [$entry]' "$FALLBACK_FILE" > "$ftmp" 2>/dev/null \
                && mv "$ftmp" "$FALLBACK_FILE" || rm -f "$ftmp"
        else
            printf '{"created":"%s","items":[%s]}\n' "$now" "$entry" > "$FALLBACK_FILE"
        fi
    fi
}

if ! main "$@"; then
    : # Silent failure — hook context, don't disrupt the session
fi
exit 0
