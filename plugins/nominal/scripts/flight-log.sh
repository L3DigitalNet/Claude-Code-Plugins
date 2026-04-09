#!/usr/bin/env bash
# flight-log.sh — Manage the nominal flight log (runs.jsonl).
#
# Subcommands:
#   append              Read JSON from stdin, validate, append to runs.jsonl
#   read [--last N]     Read last N records (default: 1)
#   query --type <type> Filter records by type (postflight|abort|preflight_refresh)
#
# Output: JSON to stdout. Errors to stderr as JSON.
# Exit:   0 on success, 1 on failure.

source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

LOG_DIR=".claude/nominal"
LOG_FILE="$LOG_DIR/runs.jsonl"

cmd_append() {
  mkdir -p "$LOG_DIR"

  local input
  input=$(cat)

  # Validate JSON and add timestamp if missing, then append
  $PYTHON -c "
import json, sys
from datetime import datetime, timezone

try:
    record = json.loads(sys.argv[1])
except (json.JSONDecodeError, ValueError) as e:
    print(json.dumps({'error': f'Invalid JSON: {e}'}), file=sys.stderr)
    sys.exit(1)

if 'timestamp' not in record:
    record['timestamp'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

line = json.dumps(record, separators=(',', ':'))

with open('$LOG_FILE', 'a') as f:
    f.write(line + '\n')

print(line)
" "$input"
}

cmd_read() {
  local last=1
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --last) last="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ ! -f "$LOG_FILE" ]]; then
    echo "[]"
    return
  fi

  tail -n "$last" "$LOG_FILE" | $PYTHON -c "
import json, sys
records = []
for line in sys.stdin:
    line = line.strip()
    if line:
        records.append(json.loads(line))
print(json.dumps(records, indent=2))
"
}

cmd_query() {
  local record_type=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type) record_type="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -z "$record_type" ]]; then
    json_error "query requires --type argument"
  fi

  if [[ ! -f "$LOG_FILE" ]]; then
    echo "[]"
    return
  fi

  $PYTHON -c "
import json, sys
records = []
for line in sys.stdin:
    line = line.strip()
    if line:
        try:
            r = json.loads(line)
            if r.get('type') == sys.argv[1]:
                records.append(r)
        except json.JSONDecodeError:
            pass
print(json.dumps(records, indent=2))
" "$record_type" < "$LOG_FILE"
}

# --- Dispatch ---

subcmd="${1:-}"
shift || true

case "$subcmd" in
  append) cmd_append ;;
  read)   cmd_read "$@" ;;
  query)  cmd_query "$@" ;;
  *)      json_error "Usage: flight-log.sh {append|read|query}" ;;
esac
