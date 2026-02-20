#!/usr/bin/env bash
# Registers a document in the docs-manager index.
# Reads frontmatter to populate fields. Creates index if missing.
# Acquires lock, appends entry, rebuilds docs-index.md, releases lock.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
INDEX_FILE="$DOCS_MANAGER_HOME/docs-index.json"

read_config_field() {
    local field="$1"
    local config="$DOCS_MANAGER_HOME/config.yaml"
    [[ ! -f "$config" ]] && return 1
    python3 -c "
import sys, re
field = sys.argv[1]
with open(sys.argv[2]) as f:
    for line in f:
        m = re.match(r'^' + re.escape(field) + r':\s*(.+)$', line.strip())
        if m:
            print(m.group(1))
            sys.exit(0)
sys.exit(1)
" "$field" "$config" 2>/dev/null
}

main() {
    local doc_path="" library="" title=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)    doc_path="$2";  shift 2 ;;
            --library) library="$2";   shift 2 ;;
            --title)   title="$2";     shift 2 ;;
            *) shift ;;
        esac
    done

    [[ -z "$doc_path" ]] && { echo "Error: --path required" >&2; return 1; }
    [[ ! -f "$doc_path" ]] && { echo "Error: file not found: $doc_path" >&2; return 1; }

    # Read frontmatter
    local fm_json
    fm_json=$(bash "$SCRIPTS_DIR/frontmatter-read.sh" "$doc_path" 2>/dev/null || echo "{}")

    # Extract fields from frontmatter, with flag overrides
    [[ -z "$library" ]] && library=$(echo "$fm_json" | jq -r '.library // empty' 2>/dev/null || echo "")
    [[ -z "$library" ]] && { echo "Error: no library in frontmatter and --library not provided" >&2; return 1; }

    [[ -z "$title" ]] && {
        # Try to extract title from first H1 in the document
        title=$(python3 -c "
import sys
with open(sys.argv[1]) as f:
    in_fm = False
    for line in f:
        if line.strip() == '---':
            in_fm = not in_fm
            continue
        if not in_fm and line.startswith('# '):
            print(line[2:].strip())
            sys.exit(0)
print('Untitled')
" "$doc_path" 2>/dev/null || echo "Untitled")
    }

    local machine doc_type fm_status last_verified upstream_url source_files
    machine=$(echo "$fm_json" | jq -r '.machine // empty' 2>/dev/null || echo "")
    [[ -z "$machine" ]] && machine=$(read_config_field "machine" 2>/dev/null || hostname)
    doc_type=$(echo "$fm_json" | jq -r '.["doc-type"] // empty' 2>/dev/null || echo "")
    fm_status=$(echo "$fm_json" | jq -r '.status // "active"' 2>/dev/null || echo "active")
    last_verified=$(echo "$fm_json" | jq -r '.["last-verified"] // empty' 2>/dev/null || echo "")
    upstream_url=$(echo "$fm_json" | jq -r '.["upstream-url"] // empty' 2>/dev/null || echo "")
    source_files=$(echo "$fm_json" | jq -c '.["source-files"] // []' 2>/dev/null || echo "[]")

    # Create index if missing
    if [[ ! -f "$INDEX_FILE" ]]; then
        local now
        now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        printf '{"version":"1.0","last-updated":"%s","libraries":[],"documents":[]}\n' "$now" > "$INDEX_FILE"
    fi

    # Check for duplicate path
    local existing
    existing=$(jq --arg p "$doc_path" '[.documents[] | select(.path == $p)] | length' "$INDEX_FILE" 2>/dev/null || echo "0")
    if [[ "$existing" -gt 0 ]]; then
        echo "Already registered: $doc_path"
        return 0
    fi

    # Acquire lock
    bash "$SCRIPTS_DIR/index-lock.sh" --operation "register" 2>/dev/null || true

    # Generate next doc ID
    local count
    count=$(jq '.documents | length' "$INDEX_FILE")
    local id
    id=$(printf "doc-%03d" $((count + 1)))

    # Build document entry
    local entry
    entry=$(jq -n \
        --arg id "$id" --arg path "$doc_path" --arg title "$title" \
        --arg library "$library" --arg machine "$machine" \
        --arg doc_type "$doc_type" --arg status "$fm_status" \
        --arg last_verified "$last_verified" --arg upstream_url "$upstream_url" \
        --argjson source_files "$source_files" \
        '{
            id: $id, path: $path, title: $title,
            library: $library, machine: $machine,
            "doc-type": $doc_type, status: $status,
            "last-verified": (if $last_verified != "" then $last_verified else null end),
            template: null,
            "upstream-url": (if $upstream_url != "" then $upstream_url else null end),
            "source-files": $source_files,
            "cross-refs": [], "incoming-refs": [],
            summary: null
        }')

    # Ensure library exists in index
    local lib_exists
    lib_exists=$(jq --arg name "$library" '[.libraries[] | select(.name == $name)] | length' "$INDEX_FILE")
    if [[ "$lib_exists" -eq 0 ]]; then
        local lib_entry
        lib_entry=$(jq -n --arg name "$library" --arg machine "$machine" \
            '{name: $name, machine: $machine, description: "", "root-path": ""}')
        local tmp="$INDEX_FILE.tmp.$$"
        jq --argjson lib "$lib_entry" '.libraries += [$lib]' "$INDEX_FILE" > "$tmp" && mv "$tmp" "$INDEX_FILE"
    fi

    # Append document
    local now
    now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local tmp="$INDEX_FILE.tmp.$$"
    jq --argjson entry "$entry" --arg now "$now" \
        '.documents += [$entry] | .["last-updated"] = $now' \
        "$INDEX_FILE" > "$tmp" && mv "$tmp" "$INDEX_FILE"

    # Rebuild markdown mirror
    bash "$SCRIPTS_DIR/index-rebuild-md.sh" 2>/dev/null || true

    # Release lock
    bash "$SCRIPTS_DIR/index-unlock.sh" 2>/dev/null || true

    echo "Registered: $title ($id) in $library"
}

main "$@"
