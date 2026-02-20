#!/usr/bin/env bash
# Regenerates docs-index.md from docs-index.json.
# The markdown file is a human-readable mirror — never edit manually.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
INDEX_FILE="$DOCS_MANAGER_HOME/docs-index.json"
MD_FILE="$DOCS_MANAGER_HOME/docs-index.md"

main() {
    [[ ! -f "$INDEX_FILE" ]] && { echo "No index found" >&2; return 1; }

    local updated
    updated=$(jq -r '.["last-updated"]' "$INDEX_FILE")
    local doc_count
    doc_count=$(jq '.documents | length' "$INDEX_FILE")

    {
        echo "# Documentation Index"
        echo ""
        echo "Last updated: $updated | $doc_count document(s)"
        echo ""
        echo "---"
        echo ""

        # Group by library
        jq -r '.libraries[].name' "$INDEX_FILE" | while read -r lib_name; do
            local lib_desc
            lib_desc=$(jq -r --arg n "$lib_name" '.libraries[] | select(.name == $n) | .description // ""' "$INDEX_FILE")
            local lib_machine
            lib_machine=$(jq -r --arg n "$lib_name" '.libraries[] | select(.name == $n) | .machine // ""' "$INDEX_FILE")

            echo "## $lib_name"
            [[ -n "$lib_desc" ]] && echo "*$lib_desc*"
            [[ -n "$lib_machine" ]] && echo "Machine: \`$lib_machine\`"
            echo ""
            echo "| ID | Title | Type | Status | Last Verified |"
            echo "|----|-------|------|--------|---------------|"

            jq -r --arg lib "$lib_name" '
                .documents[] | select(.library == $lib) |
                "| " + .id + " | " + (.title // "Untitled") + " | " + (.["doc-type"] // "-") +
                " | " + (.status // "-") + " | " + (.["last-verified"] // "-") + " |"
            ' "$INDEX_FILE"

            echo ""
        done
    } > "$MD_FILE"

    echo "Rebuilt $MD_FILE ($doc_count documents)"
}

main "$@"
