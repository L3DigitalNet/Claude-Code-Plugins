#!/usr/bin/env bash
# Extracts a reusable template skeleton from an existing document,
# or copies a template file directly to the templates directory.
# Registers the template name in the index.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

read_config_field() {
    local field="$1"
    local config="$DOCS_MANAGER_HOME/config.yaml"
    [[ ! -f "$config" ]] && return 1
    python3 -c "
import sys, re
field = sys.argv[1]
with open(sys.argv[2]) as f:
    for line in f:
        m = re.match(r'^  ' + re.escape(field) + r':\s*(.+)$', line.strip())
        if m:
            print(m.group(1))
            sys.exit(0)
        m2 = re.match(r'^' + re.escape(field) + r':\s*(.+)$', line.strip())
        if m2:
            print(m2.group(1))
            sys.exit(0)
sys.exit(1)
" "$field" "$config" 2>/dev/null
}

main() {
    local from_path="" file_path="" name=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --from) from_path="$2"; shift 2 ;;
            --file) file_path="$2"; shift 2 ;;
            --name) name="$2";      shift 2 ;;
            *) shift ;;
        esac
    done

    # Determine templates directory
    local index_location
    index_location=$(read_config_field "location" 2>/dev/null || echo "$DOCS_MANAGER_HOME")
    local templates_dir="$index_location/templates"
    mkdir -p "$templates_dir"

    if [[ -n "$file_path" ]]; then
        # Direct copy mode
        [[ ! -f "$file_path" ]] && { echo "Error: file not found: $file_path" >&2; return 1; }
        [[ -z "$name" ]] && name=$(basename "$file_path" .md)
        cp "$file_path" "$templates_dir/$name.md"
        echo "Registered template: $name"
        return 0
    fi

    if [[ -n "$from_path" ]]; then
        # Extract skeleton from existing document
        [[ ! -f "$from_path" ]] && { echo "Error: file not found: $from_path" >&2; return 1; }
        [[ -z "$name" ]] && name=$(basename "$from_path" .md | sed 's/README/template/')

        python3 -c "
import sys, re

with open(sys.argv[1]) as f:
    content = f.read()

lines = content.split('\n')
output = []
in_fm = False
fm_done = False

for line in lines:
    if line.strip() == '---' and not fm_done:
        if in_fm:
            fm_done = True
            # Replace values with placeholders in frontmatter
            output.append(line)
        else:
            in_fm = True
            output.append(line)
        continue

    if in_fm:
        # Replace frontmatter values with placeholders
        m = re.match(r'^(\S+):\s*(.+)$', line)
        if m:
            key = m.group(1)
            if key in ('library', 'machine', 'doc-type', 'status'):
                output.append(f'{key}: {{{{' + key + '}}}}')
            else:
                output.append(line)
        else:
            output.append(line)
        continue

    # In body: keep headings, replace prose with placeholders
    if line.startswith('#'):
        output.append(line)
    elif line.startswith('|') or line.startswith('-'):
        output.append(line)
    elif line.strip() == '':
        output.append('')
    else:
        output.append('{{content}}')

# Deduplicate consecutive {{content}} lines
result = []
prev = None
for line in output:
    if line == '{{content}}' and prev == '{{content}}':
        continue
    result.append(line)
    prev = line

print('\n'.join(result))
" "$from_path" > "$templates_dir/$name.md"

        echo "Extracted template: $name → $templates_dir/$name.md"
        return 0
    fi

    echo "Error: provide --from <path> or --file <path>" >&2
    return 1
}

main "$@"
