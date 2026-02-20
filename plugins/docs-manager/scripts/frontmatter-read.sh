#!/usr/bin/env bash
# Extracts YAML frontmatter from a markdown file.
# Uses Python 3 stdlib only (no pyyaml) — parses simple key: value pairs
# and YAML lists between --- delimiters.
#
# Usage:
#   frontmatter-read.sh <file> [field | --has-frontmatter]
#   No field arg: outputs all frontmatter as JSON
#   Field arg: outputs that field's value (string, or JSON for arrays)
#   --has-frontmatter: exits 0 if file has docs-manager frontmatter (has 'library'), else 1
set -euo pipefail

main() {
    local filepath="${1:-}"
    local field="${2:-}"

    [[ -z "$filepath" || ! -f "$filepath" ]] && return 1

    python3 -c '
import sys, json, re

filepath = sys.argv[1]
field = sys.argv[2] if len(sys.argv) > 2 else None

with open(filepath) as f:
    content = f.read()

if not content.startswith("---"):
    sys.exit(1)

# Find closing ---
rest = content[3:]
idx = rest.find("\n---")
if idx < 0:
    sys.exit(1)

raw = rest[:idx].strip()
if not raw:
    sys.exit(1)

# Parse simple YAML: key: value pairs and list items
fm = {}
current_key = None
current_list = None

for line in raw.split("\n"):
    # List continuation: "  - value"
    list_match = re.match(r"^\s+-\s+(.+)$", line)
    if list_match and current_key:
        if current_list is None:
            current_list = []
        current_list.append(list_match.group(1).strip())
        continue

    # Save any pending list
    if current_list is not None and current_key:
        fm[current_key] = current_list
        current_list = None

    # Key: value pair
    kv_match = re.match(r"^([a-zA-Z0-9_-]+):\s*(.*)$", line)
    if kv_match:
        current_key = kv_match.group(1)
        val = kv_match.group(2).strip()
        if val:
            fm[current_key] = val
        else:
            # Could be start of a list
            current_list = []

# Save final pending list
if current_list is not None and current_key:
    fm[current_key] = current_list

if not fm:
    sys.exit(1)

if field == "--has-frontmatter":
    sys.exit(0 if "library" in fm else 1)

if field:
    val = fm.get(field)
    if val is None:
        sys.exit(1)
    if isinstance(val, (list, dict)):
        print(json.dumps(val))
    else:
        print(val)
else:
    print(json.dumps(fm, default=str))
' "$filepath" "$field"
}

main "$@"
