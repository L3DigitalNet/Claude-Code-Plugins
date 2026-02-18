#!/usr/bin/env bash
# PostToolUse hook: dispatches HA validation based on file path.
# Receives tool context as JSON on stdin.
# Runs the appropriate validation script for the modified file.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Extract file path from stdin JSON (tool_input.file_path or tool_input.path)
FILE_PATH=$(python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path') or ti.get('path') or ti.get('notebook_path') or '')
except Exception:
    print('')
" 2>/dev/null)

# Nothing to validate if we can't determine the file
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# Dispatch based on file name/path
case "$BASENAME" in
    manifest.json)
        # Only validate HA integration manifests (not npm/node manifests)
        if [[ "$FILE_PATH" == *custom_components* ]] || [[ "$FILE_PATH" == *integrations* ]]; then
            python3 "$PLUGIN_DIR/scripts/validate-manifest.py" "$FILE_PATH" 2>&1 || true
        fi
        ;;
    strings.json|config_flow.py)
        python3 "$PLUGIN_DIR/scripts/validate-strings.py" "$FILE_PATH" 2>&1 || true
        ;;
    *.py)
        if [[ "$FILE_PATH" == *custom_components* ]]; then
            python3 "$PLUGIN_DIR/scripts/check-patterns.py" "$FILE_PATH" 2>&1 || true
        fi
        ;;
esac

exit 0
