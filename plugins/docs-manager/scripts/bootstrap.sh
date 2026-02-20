#!/usr/bin/env bash
# Creates ~/.docs-manager/ directory structure and empty queue.
# Called on first plugin use or by /docs setup. Idempotent.
set -euo pipefail

DOCS_MANAGER_HOME="${DOCS_MANAGER_HOME:-$HOME/.docs-manager}"

main() {
    mkdir -p "$DOCS_MANAGER_HOME"/{hooks,cache}

    if [[ ! -f "$DOCS_MANAGER_HOME/queue.json" ]]; then
        printf '{"created":"%s","items":[]}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            > "$DOCS_MANAGER_HOME/queue.json"
    fi

    echo "docs-manager initialized at $DOCS_MANAGER_HOME"
}

if ! main "$@"; then
    echo "⚠ docs-manager bootstrap failed" >&2
    exit 1
fi
