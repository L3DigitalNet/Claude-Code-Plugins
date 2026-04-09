#!/usr/bin/env bash
# test-status-update.sh — Atomic read-merge-write for TEST_STATUS.json.
#
# Subcommands:
#   read                      Output current status or empty template
#   update                    Read JSON patch from stdin, shallow-merge at top level
#   set-field <key> <value>   Set a top-level JSON field
#   add-gap                   Read gap JSON from stdin, append to gaps array
#   remove-gap <id>           Remove a gap by identifier
#   init                      Create directory and empty template
#
# Output: Final JSON to stdout. File written atomically.
# Exit:   0 on success, 1 on malformed input.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

STATUS_DIR="docs/testing"
STATUS_FILE="$STATUS_DIR/TEST_STATUS.json"
TMP_FILE="$STATUS_FILE.tmp"

TEMPLATE='{"last_analysis":null,"project_type":null,"coverage":{},"gaps":[],"history":[]}'

ensure_dir() { mkdir -p "$STATUS_DIR"; }

read_status() {
  if [[ -f "$STATUS_FILE" ]]; then
    # Validate JSON
    if $PYTHON -c "import json,sys; json.load(open(sys.argv[1]))" "$STATUS_FILE" 2>/dev/null; then
      cat "$STATUS_FILE"
    else
      local raw
      raw=$(head -c 500 "$STATUS_FILE")
      echo "{\"error\":\"malformed TEST_STATUS.json\",\"raw_content\":$(echo "$raw" | $PYTHON -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}" >&2
      exit 1
    fi
  else
    echo "$TEMPLATE"
  fi
}

write_atomic() {
  # Read final JSON from stdin, write atomically
  ensure_dir
  cat > "$TMP_FILE"
  mv "$TMP_FILE" "$STATUS_FILE"
}

cmd_read() {
  read_status | $PYTHON -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))"
}

cmd_init() {
  ensure_dir
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo "$TEMPLATE" | $PYTHON -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))" | write_atomic
  fi
  read_status | $PYTHON -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))"
}

cmd_update() {
  local patch
  patch=$(cat)
  local current
  current=$(read_status)

  echo "$current" | $PYTHON -c "
import json, sys

current = json.load(sys.stdin)
patch = json.loads(sys.argv[1])

# Shallow merge: patch keys replace entire values
for k, v in patch.items():
    current[k] = v

print(json.dumps(current, indent=2))
" "$patch" | tee >(write_atomic)
}

cmd_set_field() {
  local key="${1:?Usage: set-field <key> <value>}"
  local value="${2:?Usage: set-field <key> <value>}"
  local current
  current=$(read_status)

  echo "$current" | $PYTHON -c "
import json, sys

current = json.load(sys.stdin)
key = sys.argv[1]
value = sys.argv[2]

# Try to parse value as JSON (number, bool, null, object, array)
try:
    current[key] = json.loads(value)
except (json.JSONDecodeError, ValueError):
    current[key] = value  # treat as string

print(json.dumps(current, indent=2))
" "$key" "$value" | tee >(write_atomic)
}

cmd_add_gap() {
  local gap
  gap=$(cat)
  local current
  current=$(read_status)

  echo "$current" | $PYTHON -c "
import json, sys

current = json.load(sys.stdin)
gap = json.loads(sys.argv[1])

if 'gaps' not in current:
    current['gaps'] = []
current['gaps'].append(gap)

print(json.dumps(current, indent=2))
" "$gap" | tee >(write_atomic)
}

cmd_remove_gap() {
  local gap_id="${1:?Usage: remove-gap <id>}"
  local current
  current=$(read_status)

  echo "$current" | $PYTHON -c "
import json, sys

current = json.load(sys.stdin)
gap_id = sys.argv[1]

if 'gaps' in current:
    current['gaps'] = [g for g in current['gaps'] if g.get('id') != gap_id]

print(json.dumps(current, indent=2))
" "$gap_id" | tee >(write_atomic)
}

# --- Dispatch ---
subcmd="${1:-}"
shift || true

case "$subcmd" in
  read)       cmd_read ;;
  init)       cmd_init ;;
  update)     cmd_update ;;
  set-field)  cmd_set_field "$@" ;;
  add-gap)    cmd_add_gap ;;
  remove-gap) cmd_remove_gap "$@" ;;
  *)
    echo '{"error":"Usage: test-status-update.sh {read|init|update|set-field|add-gap|remove-gap}"}' >&2
    exit 1
    ;;
esac
