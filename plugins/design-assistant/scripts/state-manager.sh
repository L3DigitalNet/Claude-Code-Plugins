#!/usr/bin/env bash
# state-manager.sh — Centralized state persistence for design-review sessions.
#
# Subcommands:
#   init <document-path>                        Create fresh state, output session-id
#   record-finding <session-id>                 Read finding JSON from stdin, add to queue
#   resolve-finding <session-id> <id> <resolution...>  Mark finding resolved
#   defer-finding <session-id> <id> <reason...>        Defer a finding
#   retire-finding <session-id> <id> <resolved-by-id>  Retire deferred finding
#   start-pass <session-id>                     Increment pass counter
#   get-queue <session-id> [--severity <level>] Get pending findings
#   get-section-status <session-id>             Get section status table
#   update-section <session-id> <section> <status> Update section status
#   get-state <session-id>                      Full state dump
#   cleanup <session-id>                        Remove state file
#
# Output: JSON to stdout. Errors to stderr.
# Exit:   0 on success, 1 on failure.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

SCHEMA_VERSION=1

state_path() { echo "/tmp/design-assistant-${1}.json"; }

cmd_init() {
  local doc_path="${1:?Usage: state-manager.sh init <document-path>}"
  local session_id
  session_id="$(date +%s%N)-$$"
  local state_file
  state_file=$(state_path "$session_id")

  $PYTHON -c "
import json
state = {
    'schema_version': $SCHEMA_VERSION,
    'session_id': '$session_id',
    'document_path': '$doc_path',
    'pass_number': 0,
    'global_finding_counter': 0,
    'auto_fix_mode': None,
    'finding_queue': [],
    'deferred_log': [],
    'section_status': {},
    'compliance_map': {},
    'coverage_map': {},
    'violation_streaks': {},
    'gap_streaks': {},
    'systemic_triggers': [],
    'context_lines_estimate': 0,
    'history': [],
}
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
print('$session_id')
"
}

load_state() {
  local session_id="$1"
  local state_file
  state_file=$(state_path "$session_id")
  if [[ ! -f "$state_file" ]]; then
    echo "{\"error\":\"session not found\",\"session_id\":\"$session_id\"}" >&2
    exit 1
  fi
  cat "$state_file"
}

save_state() {
  local session_id="$1"
  local state_file
  state_file=$(state_path "$session_id")
  local tmp="${state_file}.tmp"
  cat > "$tmp"
  mv "$tmp" "$state_file"
}

cmd_record_finding() {
  local session_id="${1:?Usage: record-finding <session-id>}"
  local finding_json
  finding_json=$(cat)
  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
finding = json.loads(sys.argv[1])

if state['schema_version'] != $SCHEMA_VERSION:
    print(json.dumps({'error': 'incompatible schema version'}), file=sys.stderr)
    sys.exit(1)

state['global_finding_counter'] += 1
finding['id'] = state['global_finding_counter']
finding['pass'] = state['pass_number']
finding['status'] = 'pending'
finding.setdefault('resolution', None)

state['finding_queue'].append(finding)
print(json.dumps(state, indent=2))
" "$finding_json" | save_state "$session_id"

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
# Return the updated counter
print(json.dumps({'id': state['global_finding_counter'] + 1, 'status': 'recorded'}))
"
}

cmd_resolve_finding() {
  local session_id="${1:?}" finding_id="${2:?}"
  shift 2
  local resolution="${*}"
  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
fid = int(sys.argv[1])
resolution = sys.argv[2]

found = False
for f in state['finding_queue']:
    if f['id'] == fid:
        f['status'] = 'resolved'
        f['resolution'] = resolution
        # Increment section modification count
        section = f.get('section', 'unknown')
        if section not in state['section_status']:
            state['section_status'][section] = {'status': 'Clean', 'modification_count': 0, 'flags': []}
        state['section_status'][section]['modification_count'] += 1
        found = True
        break

if not found:
    print(json.dumps({'error': f'finding {fid} not found'}), file=sys.stderr)
    sys.exit(1)

print(json.dumps(state, indent=2))
" "$finding_id" "$resolution" | save_state "$session_id"

  echo "{\"finding_id\":$finding_id,\"status\":\"resolved\"}"
}

cmd_defer_finding() {
  local session_id="${1:?}" finding_id="${2:?}"
  shift 2
  local reason="${*}"
  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
fid = int(sys.argv[1])
reason = sys.argv[2]

for f in state['finding_queue']:
    if f['id'] == fid:
        f['status'] = 'deferred'
        state['deferred_log'].append({
            'id': fid,
            'type': f.get('track', 'unknown'),
            'section': f.get('section', 'unknown'),
            'severity': f.get('severity', 'unknown'),
            'description': f.get('description', ''),
            'pass': f.get('pass', 0),
            'reason': reason,
            'retired_status': 'Active',
            'retired_by': None,
        })
        break

print(json.dumps(state, indent=2))
" "$finding_id" "$reason" | save_state "$session_id"

  echo "{\"finding_id\":$finding_id,\"status\":\"deferred\"}"
}

cmd_retire_finding() {
  local session_id="${1:?}" finding_id="${2:?}" resolved_by="${3:?}"
  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
fid = int(sys.argv[1])
resolved_by = int(sys.argv[2])

for d in state['deferred_log']:
    if d['id'] == fid:
        d['retired_status'] = 'RETIRED'
        d['retired_by'] = resolved_by
        break

print(json.dumps(state, indent=2))
" "$finding_id" "$resolved_by" | save_state "$session_id"

  echo "{\"finding_id\":$finding_id,\"retired_by\":$resolved_by}"
}

cmd_start_pass() {
  local session_id="${1:?}"
  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)

# Check for unprocessed findings in current pass
current_pass = state['pass_number']
pending = [f for f in state['finding_queue']
           if f.get('pass') == current_pass and f.get('status') == 'pending']
if pending and current_pass > 0:
    ids = [f['id'] for f in pending]
    print(json.dumps({'error': f'unprocessed findings in pass {current_pass}', 'finding_ids': ids}), file=sys.stderr)
    sys.exit(1)

# Snapshot to history (cap at 5)
import copy
snapshot = {
    'pass_number': state['pass_number'],
    'global_finding_counter': state['global_finding_counter'],
    'auto_fix_mode': state['auto_fix_mode'],
    'finding_count': len(state['finding_queue']),
    'section_status': copy.deepcopy(state['section_status']),
}
state['history'].append(snapshot)
if len(state['history']) > 5:
    state['history'] = state['history'][-5:]

# Check violation streaks for systemic triggers
for principle, streak in state.get('violation_streaks', {}).items():
    if streak >= 3:
        trigger = f'Violation streak: {principle} ({streak} consecutive passes)'
        if trigger not in state['systemic_triggers']:
            state['systemic_triggers'].append(trigger)

state['pass_number'] += 1
print(json.dumps(state, indent=2))
" | save_state "$session_id"

  state=$(load_state "$session_id")
  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
print(json.dumps({'pass_number': state['pass_number'], 'status': 'started'}))
"
}

cmd_get_queue() {
  local session_id="${1:?}"
  shift
  local severity=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --severity) severity="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
severity_filter = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] else None

pending = [f for f in state['finding_queue'] if f.get('status') == 'pending']
if severity_filter:
    pending = [f for f in pending if f.get('severity', '').lower() == severity_filter.lower()]

# Sort: Critical > High > Medium > Low
sev_order = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3}
pending.sort(key=lambda f: sev_order.get(f.get('severity', '').lower(), 9))

print(json.dumps({'pending': pending, 'count': len(pending)}, indent=2))
" "$severity"
}

cmd_get_section_status() {
  local session_id="${1:?}"
  local state
  state=$(load_state "$session_id")
  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
print(json.dumps(state.get('section_status', {}), indent=2))
"
}

cmd_update_section() {
  local session_id="${1:?}" section="${2:?}" status="${3:?}"
  local state
  state=$(load_state "$session_id")

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
section = sys.argv[1]
status = sys.argv[2]

if section not in state['section_status']:
    state['section_status'][section] = {'status': 'Clean', 'modification_count': 0, 'flags': []}
state['section_status'][section]['status'] = status

print(json.dumps(state, indent=2))
" "$section" "$status" | save_state "$session_id"

  echo "{\"section\":\"$section\",\"status\":\"$status\"}"
}

cmd_get_state() {
  local session_id="${1:?}"
  load_state "$session_id" | $PYTHON -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))"
}

cmd_cleanup() {
  local session_id="${1:?}"
  local state_file
  state_file=$(state_path "$session_id")
  rm -f "$state_file"
  echo "{\"session_id\":\"$session_id\",\"cleaned\":true}"
}

# --- Dispatch ---
subcmd="${1:-}"
shift || true

case "$subcmd" in
  init)              cmd_init "$@" ;;
  record-finding)    cmd_record_finding "$@" ;;
  resolve-finding)   cmd_resolve_finding "$@" ;;
  defer-finding)     cmd_defer_finding "$@" ;;
  retire-finding)    cmd_retire_finding "$@" ;;
  start-pass)        cmd_start_pass "$@" ;;
  get-queue)         cmd_get_queue "$@" ;;
  get-section-status) cmd_get_section_status "$@" ;;
  update-section)    cmd_update_section "$@" ;;
  get-state)         cmd_get_state "$@" ;;
  cleanup)           cmd_cleanup "$@" ;;
  *)
    echo '{"error":"Usage: state-manager.sh {init|record-finding|resolve-finding|defer-finding|retire-finding|start-pass|get-queue|get-section-status|update-section|get-state|cleanup}"}' >&2
    exit 1
    ;;
esac
