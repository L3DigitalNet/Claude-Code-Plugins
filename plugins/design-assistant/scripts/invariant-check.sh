#!/usr/bin/env bash
# invariant-check.sh — Validate state invariants for design sessions.
#
# Usage: invariant-check.sh <command-type> <session-id-or-stdin>
#   command-type: "draft" or "review"
#   For review: reads state file by session-id
#   For draft: reads state JSON from stdin (pass "-" as session-id placeholder)
#
# Output: JSON with invariants_checked, passed, failed, violations.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

CMD_TYPE="${1:?Usage: invariant-check.sh <draft|review> <session-id>}"
SESSION_ID="${2:--}"

if [[ "$CMD_TYPE" == "review" ]]; then
  STATE_FILE="/tmp/design-assistant-${SESSION_ID}.json"
  if [[ ! -f "$STATE_FILE" ]]; then
    echo "{\"error\":\"session not found\",\"session_id\":\"$SESSION_ID\"}" >&2
    exit 1
  fi
  STATE_JSON=$(cat "$STATE_FILE")
elif [[ "$CMD_TYPE" == "draft" ]]; then
  STATE_JSON=$(cat)
else
  echo '{"error":"command-type must be draft or review"}' >&2
  exit 1
fi

echo "$STATE_JSON" | $PYTHON -c "
import json, sys

state = json.load(sys.stdin)
cmd_type = sys.argv[1]
violations = []

def fail(invariant, detail, severity='warning'):
    violations.append({'invariant': invariant, 'detail': detail, 'severity': severity})

if cmd_type == 'review':
    # 1. global_finding_counter never decreases across passes
    history = state.get('history', [])
    for i in range(1, len(history)):
        if history[i].get('global_finding_counter', 0) < history[i-1].get('global_finding_counter', 0):
            fail('Finding counter monotonic', f'Counter decreased between pass {history[i-1].get(\"pass_number\")} and {history[i].get(\"pass_number\")}', 'critical')

    # 2. PRINCIPLE findings never auto_fix_eligible
    for f in state.get('finding_queue', []):
        if f.get('track') == 'B' and f.get('auto_fix_eligible'):
            fail('PRINCIPLE findings never auto-fixed', f'Finding #{f[\"id\"]} (Track B, PRINCIPLE) has auto_fix_eligible=true', 'critical')

    # 3. Resolved findings must have resolution
    for f in state.get('finding_queue', []):
        if f.get('status') == 'resolved' and not f.get('resolution'):
            fail('Resolved findings have resolution', f'Finding #{f[\"id\"]} resolved without resolution text')

    # 4. Retired deferred findings must have valid retired_by
    finding_ids = {f['id'] for f in state.get('finding_queue', [])}
    for d in state.get('deferred_log', []):
        if d.get('retired_status') == 'RETIRED':
            if not d.get('retired_by') or d['retired_by'] not in finding_ids:
                fail('Retired findings have valid retired_by', f'Deferred #{d[\"id\"]} retired_by={d.get(\"retired_by\")} is invalid')

    # 5. Section modification count only increases
    for i in range(1, len(history)):
        prev = history[i-1].get('section_status', {})
        curr = history[i].get('section_status', {})
        for section in prev:
            if section in curr:
                if curr[section].get('modification_count', 0) < prev[section].get('modification_count', 0):
                    fail('Section mod count monotonic', f'Section \"{section}\" mod count decreased')

    # 6. Violation streaks >= 3 have systemic_triggers entry
    triggers = state.get('systemic_triggers', [])
    for principle, streak in state.get('violation_streaks', {}).items():
        if streak >= 3:
            has_trigger = any(principle in t for t in triggers)
            if not has_trigger:
                fail('Streak triggers logged', f'{principle} streak={streak} has no systemic_trigger entry')

    # 7. Check pending findings in current pass (should be empty if start-pass succeeded)
    current_pass = state.get('pass_number', 0)
    if current_pass > 0:
        prev_pass = current_pass - 1
        pending_prev = [f for f in state.get('finding_queue', [])
                       if f.get('pass') == prev_pass and f.get('status') == 'pending']
        if pending_prev:
            fail('All findings processed before next pass', f'{len(pending_prev)} pending findings from pass {prev_pass}')

    total = 7

elif cmd_type == 'draft':
    phase = state.get('phase', 0)

    # 1. No Pending candidates past Phase 2B
    if phase > 2.2:
        candidates = state.get('candidates', [])
        pending = [c for c in candidates if c.get('status') == 'Pending']
        if pending:
            fail('No pending candidates past Phase 2B', f'{len(pending)} pending candidates')

    # 2. All Active tensions resolved before Phase 2D lock
    if phase >= 2.4:
        tensions = state.get('tension_log', [])
        active = [t for t in tensions if t.get('status') == 'Active']
        if active:
            fail('Tensions resolved before Phase 2D', f'{len(active)} active tensions')

    # 3. Registry locked before Phase 3
    if phase >= 3:
        if not state.get('registry_locked'):
            fail('Registry locked before Phase 3', 'Registry not locked')

    # 4. All constraints/risks mapped before Phase 5
    if phase >= 5:
        if not state.get('coverage_sweep_complete'):
            fail('Coverage sweep before Phase 5', 'Coverage sweep not completed')

    # 5. No duplicate principle names
    candidates = state.get('candidates', [])
    names = [c.get('name', '') for c in candidates]
    dupes = [n for n in names if names.count(n) > 1]
    if dupes:
        fail('No duplicate principle names', f'Duplicates: {set(dupes)}')

    # 6. Stress-test verdicts are final
    for c in candidates:
        if c.get('stress_test_verdict') and c.get('re_tested'):
            fail('Stress-test verdicts final', f'Candidate \"{c.get(\"name\")}\" re-tested after verdict')

    # 7. Phase transitions monotonic
    phase_history = state.get('phase_history', [])
    for i in range(1, len(phase_history)):
        if phase_history[i] < phase_history[i-1]:
            fail('Phase transitions monotonic', f'Phase went from {phase_history[i-1]} to {phase_history[i]}')

    total = 7

else:
    total = 0

passed = total - len(violations)

result = {
    'command': cmd_type,
    'invariants_checked': total,
    'passed': passed,
    'failed': len(violations),
    'violations': violations,
}

print(json.dumps(result, indent=2))
" "$CMD_TYPE"
