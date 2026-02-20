#!/usr/bin/env bash
set -euo pipefail

# check-waivers.sh — Look up whether a pre-flight check is waived.
#
# Usage: check-waivers.sh <waiver-file> <check-name> [plugin-name]
# Output: waiver reason (stdout) if waived
# Exit:   0 = check is waived, 1 = not waived (or file missing)
#
# Waiver file: .release-waivers.json at repo root
# Called by: agents/git-preflight.md, agents/test-runner.md, agents/docs-auditor.md
# before marking any check as FAIL.
#
# Supported check names: dirty_working_tree, protected_branch, noreply_email,
#   tag_exists, missing_tests, stale_docs

if [[ $# -lt 2 ]]; then
  echo "Usage: check-waivers.sh <waiver-file> <check-name> [plugin-name]" >&2
  exit 1
fi

WAIVER_FILE="$1"
CHECK_NAME="$2"
PLUGIN_NAME="${3:-*}"

if [[ ! -f "$WAIVER_FILE" ]]; then
  exit 1
fi

# Use sys.argv to avoid shell injection; exit 0 from python means waived
python3 - "$WAIVER_FILE" "$CHECK_NAME" "$PLUGIN_NAME" <<'PYEOF'
import json, sys

waiver_file = sys.argv[1]
check_name  = sys.argv[2]
plugin_name = sys.argv[3]

try:
    with open(waiver_file) as f:
        data = json.load(f)
except (OSError, json.JSONDecodeError):
    sys.exit(1)

for w in data.get("waivers", []):
    if w.get("check") != check_name:
        continue
    p = w.get("plugin", "*")
    if p == "*" or p == plugin_name:
        print(w.get("reason", "no reason specified"))
        sys.exit(0)

sys.exit(1)
PYEOF
