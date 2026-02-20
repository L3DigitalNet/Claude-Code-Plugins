#!/usr/bin/env bash
# PostToolUse hook handler — detects doc-relevant file changes.
# Reads tool context JSON from stdin. Always exits 0.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
# When called as a hook, CLAUDE_PLUGIN_ROOT is set. In tests, fall back to script dir.
SCRIPTS_DIR="${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/scripts}"
[[ -z "$SCRIPTS_DIR" ]] && SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

main() {
    local input
    input=$(cat) || true

    [[ -z "$input" ]] && return 0

    # Extract file path from tool context JSON
    local file_path
    file_path=$(echo "$input" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('file_path', ''))
except:
    print('')
" 2>/dev/null) || true
    [[ -z "$file_path" ]] && return 0

    # Quick filter: only process files that could be docs or source-files
    # Non-.md files skip Path A but still check Path B (source-file association)
    local is_md=false
    [[ "$file_path" == *.md ]] && is_md=true

    # Quick filter: skip noise directories
    case "$file_path" in
        */node_modules/*|*/.git/*|*/__pycache__/*) return 0 ;;
    esac

    # File must exist (may have been a delete operation)
    [[ ! -f "$file_path" ]] && return 0

    # Path A: check for docs-manager frontmatter (only .md files)
    if $is_md && bash "$SCRIPTS_DIR/frontmatter-read.sh" "$file_path" --has-frontmatter 2>/dev/null; then
        local library
        library=$(bash "$SCRIPTS_DIR/frontmatter-read.sh" "$file_path" library 2>/dev/null || echo "unknown")
        bash "$SCRIPTS_DIR/queue-append.sh" \
            --type "doc-modified" \
            --doc-path "$file_path" \
            --library "$library" \
            --trigger "direct-write"
    fi

    # Path B: source-file association — check if edited file is tracked as a source-file
    local associated
    associated=$(bash "$SCRIPTS_DIR/index-source-lookup.sh" "$file_path" 2>/dev/null || echo "[]")
    if [[ "$associated" != "[]" ]]; then
        echo "$associated" | jq -r '.[] | .path + "|" + .library' 2>/dev/null | while IFS='|' read -r doc_path lib; do
            bash "$SCRIPTS_DIR/queue-append.sh" \
                --type "source-file-changed" \
                --doc-path "$doc_path" \
                --library "$lib" \
                --trigger "source-file-association" \
                --source-file "$file_path"
        done
    fi

    # Queue threshold warning
    local count
    count=$(bash "$SCRIPTS_DIR/queue-read.sh" --count 2>/dev/null || echo "0")
    if [[ "$count" -gt 20 ]]; then
        echo "Documentation queue has $count items. Consider \`/docs queue review\` before continuing."
    fi

    # Write last-fired timestamp
    mkdir -p "$DOCS_MANAGER_HOME/hooks"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$DOCS_MANAGER_HOME/hooks/post-tool-use.last-fired"
}

if ! main; then
    : # Silent — never disrupt the session
fi
exit 0
