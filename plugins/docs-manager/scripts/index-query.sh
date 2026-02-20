#!/usr/bin/env bash
# Queries the docs-manager index with optional filters.
# Returns JSON array of matching document entries.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX_FILE="$DOCS_MANAGER_HOME/docs-index.json"

main() {
    local library="" doc_type="" search="" path="" source_file="" machine="" human=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --library)     library="$2";     shift 2 ;;
            --doc-type)    doc_type="$2";    shift 2 ;;
            --search)      search="$2";      shift 2 ;;
            --path)        path="$2";        shift 2 ;;
            --source-file) source_file="$2"; shift 2 ;;
            --machine)     machine="$2";     shift 2 ;;
            --human)       human=true;       shift ;;
            *) shift ;;
        esac
    done

    if [[ ! -f "$INDEX_FILE" ]]; then
        echo "[]"
        return 0
    fi

    # Build jq filter chain
    local filter='.documents'

    if [[ -n "$library" ]]; then
        filter="$filter | map(select(.library == \"$library\"))"
    fi

    if [[ -n "$doc_type" ]]; then
        filter="$filter | map(select(.[\"doc-type\"] == \"$doc_type\"))"
    fi

    if [[ -n "$machine" ]]; then
        filter="$filter | map(select(.machine == \"$machine\"))"
    fi

    if [[ -n "$path" ]]; then
        filter="$filter | map(select(.path == \"$path\"))"
    fi

    if [[ -n "$source_file" ]]; then
        filter="$filter | map(select(.[\"source-files\"] and ([.[\"source-files\"][] | select(. == \"$source_file\")] | length > 0)))"
    fi

    if [[ -n "$search" ]]; then
        filter="$filter | map(select((.title // \"\" | ascii_downcase | contains(\"$(echo "$search" | tr '[:upper:]' '[:lower:]')\")) or (.path // \"\" | ascii_downcase | contains(\"$(echo "$search" | tr '[:upper:]' '[:lower:]')\")) or (.summary // \"\" | ascii_downcase | contains(\"$(echo "$search" | tr '[:upper:]' '[:lower:]')\"))))"
    fi

    local result
    result=$(jq "$filter" "$INDEX_FILE" 2>/dev/null || echo "[]")

    if $human; then
        echo "$result" | jq -r '.[] | "  " + .id + "  " + (.title // "Untitled") + "  " + .library + "  " + .path'
    else
        echo "$result"
    fi
}

main "$@"
