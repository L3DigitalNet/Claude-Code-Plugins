#!/usr/bin/env bash
# convergence-tracker.sh — Manage iteration state for drift analysis phases.
#
# Subcommands:
#   init                       Create fresh tracker state
#   start-phase <phase>        Begin a new phase
#   record-iteration <phase>   Read findings JSON from stdin
#   check-convergence <phase>  Check if phase has converged
#   check-oscillation <phase>  Check for oscillating findings
#   status                     Current state of all phases
#   reset                      Clear all state
#
# Output: JSON to stdout.
# Exit:   0 on success, 1 on failure.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

STATE_FILE="/tmp/up-docs-drift-tracker.json"
TMP_FILE="${STATE_FILE}.tmp"

TEMPLATE='{"phases":{},"overall":{"phases_completed":0,"phases_remaining":4}}'

read_state() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo "$TEMPLATE"
  fi
}

write_state() {
  cat > "$TMP_FILE"
  mv "$TMP_FILE" "$STATE_FILE"
}

cmd_init() {
  echo "$TEMPLATE" | $PYTHON -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))" | write_state
  echo '{"status":"initialized"}'
}

cmd_start_phase() {
  local phase="${1:?Usage: start-phase <phase-number>}"
  read_state | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
phase = sys.argv[1]
state['phases'][phase] = {
    'status': 'in_progress',
    'iteration': 0,
    'max_iterations': 10,
    'history': [],
    'pages_touched': 0,
    'changes_applied': 0,
}
print(json.dumps(state, indent=2))
" "$phase" | write_state
  echo "{\"phase\":$phase,\"status\":\"started\"}"
}

cmd_record_iteration() {
  local phase="${1:?Usage: record-iteration <phase>}"
  local findings_json
  findings_json=$(cat)
  local state
  state=$(read_state)

  echo "$state" | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
phase = sys.argv[1]
findings = json.loads(sys.argv[2])

if phase not in state['phases']:
    print(json.dumps({'error': f'phase {phase} not started'}), file=sys.stderr)
    sys.exit(1)

p = state['phases'][phase]
p['iteration'] += 1

fixes = findings.get('fixes_applied', 0)
p['changes_applied'] += fixes
p['pages_touched'] = max(p['pages_touched'], findings.get('pages_touched', 0))

p['history'].append({
    'iteration': p['iteration'],
    'findings': findings.get('findings', []),
    'fixes_applied': fixes,
})

print(json.dumps(state, indent=2))
" "$phase" "$findings_json" | write_state

  echo "{\"phase\":$phase,\"iteration\":$(read_state | $PYTHON -c "import json,sys; print(json.load(sys.stdin)['phases']['$phase']['iteration'])")}"
}

cmd_check_convergence() {
  local phase="${1:?}"
  read_state | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
phase = sys.argv[1]

if phase not in state['phases']:
    print(json.dumps({'error': f'phase {phase} not started'}))
    sys.exit(0)

p = state['phases'][phase]
history = p.get('history', [])

if not history:
    print(json.dumps({'converged': False, 'reason': 'no iterations yet'}))
    sys.exit(0)

last = history[-1]
findings_count = len(last.get('findings', []))
iteration = p['iteration']
max_iter = p['max_iterations']

converged = findings_count == 0
hit_max = iteration >= max_iter

if converged:
    p['status'] = 'converged'
    state['overall']['phases_completed'] += 1
    state['overall']['phases_remaining'] = max(0, state['overall']['phases_remaining'] - 1)
elif hit_max:
    p['status'] = 'max_iterations_reached'

# Write updated state back
with open('$STATE_FILE.tmp', 'w') as f:
    json.dump(state, f, indent=2)
import os
os.rename('$STATE_FILE.tmp', '$STATE_FILE')

result = {
    'converged': converged,
    'iteration': iteration,
    'findings_remaining': findings_count,
    'max_iterations_reached': hit_max,
    'status': p['status'],
}
print(json.dumps(result, indent=2))
" "$phase"
}

cmd_check_oscillation() {
  local phase="${1:?}"
  read_state | $PYTHON -c "
import json, sys
state = json.load(sys.stdin)
phase = sys.argv[1]

if phase not in state['phases']:
    print(json.dumps({'oscillating': False, 'reason': 'phase not started'}))
    sys.exit(0)

history = state['phases'][phase].get('history', [])
if len(history) < 3:
    print(json.dumps({'oscillating': False, 'reason': 'fewer than 3 iterations'}))
    sys.exit(0)

# Check last 3 iterations for finding keys that appear, disappear, reappear
def finding_keys(findings):
    keys = set()
    for f in findings:
        # Use composite key based on available fields
        key = f.get('key') or f.get('id') or json.dumps(f, sort_keys=True)
        keys.add(key)
    return keys

last3 = history[-3:]
keys_n2 = finding_keys(last3[0].get('findings', []))
keys_n1 = finding_keys(last3[1].get('findings', []))
keys_n0 = finding_keys(last3[2].get('findings', []))

# Oscillating: present in n-2, absent in n-1, present in n-0
oscillating = keys_n2 & keys_n0 - keys_n1
oscillating = {k for k in oscillating if k in keys_n2 and k not in keys_n1 and k in keys_n0}

result = {
    'oscillating': len(oscillating) > 0,
    'oscillating_keys': sorted(oscillating),
    'count': len(oscillating),
}
print(json.dumps(result, indent=2))
" "$phase"
}

cmd_status() {
  read_state | $PYTHON -c "import json,sys; print(json.dumps(json.load(sys.stdin), indent=2))"
}

cmd_reset() {
  rm -f "$STATE_FILE"
  echo '{"status":"reset"}'
}

# --- Dispatch ---
subcmd="${1:-}"
shift || true

case "$subcmd" in
  init)               cmd_init ;;
  start-phase)        cmd_start_phase "$@" ;;
  record-iteration)   cmd_record_iteration "$@" ;;
  check-convergence)  cmd_check_convergence "$@" ;;
  check-oscillation)  cmd_check_oscillation "$@" ;;
  status)             cmd_status ;;
  reset)              cmd_reset ;;
  *)
    echo '{"error":"Usage: convergence-tracker.sh {init|start-phase|record-iteration|check-convergence|check-oscillation|status|reset}"}' >&2
    exit 1
    ;;
esac
