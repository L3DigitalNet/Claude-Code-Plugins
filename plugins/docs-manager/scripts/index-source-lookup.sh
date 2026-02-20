#!/usr/bin/env bash
# Queries index for documents whose source-files contain the given path.
# Used by PostToolUse hook for Path B detection.
# Output: JSON array of matching document entries.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

main() {
    local file_path="${1:-}"
    [[ -z "$file_path" ]] && { echo "[]"; return 0; }

    bash "$SCRIPTS_DIR/index-query.sh" --source-file "$file_path"
}

main "$@"
