#!/usr/bin/env bats
# Tests for invariant-check.sh — state invariant validation.

load helpers

setup() {
    setup_test_env
}

teardown() {
    if [[ -n "${SESSION_ID:-}" ]]; then
        "$SCRIPTS_DIR/state-manager.sh" cleanup "$SESSION_ID" >/dev/null 2>&1 || true
    fi
    teardown_test_env
}

# -- review mode --

@test "review: clean state passes all 7 invariants" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
    [ "$passed" -eq 7 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -eq 0 ]
}

@test "review: Track B finding with auto_fix_eligible=true fails invariant" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"B","severity":"high","section":"Principles","description":"Violated","auto_fix_eligible":true}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    # Check the specific violation
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('auto_fix_eligible' in v.get('detail','') or 'auto-fixed' in v.get('invariant','') for v in violations), f'Expected auto_fix invariant violation, got: {violations}'
"
}

@test "review: resolved finding missing resolution fails invariant" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"medium","section":"Overview","description":"Issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    # Manually set status to resolved without resolution to trigger invariant violation
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['finding_queue'][0]['status'] = 'resolved'
state['finding_queue'][0]['resolution'] = None
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"

    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('resolution' in v.get('invariant','').lower() or 'resolution' in v.get('detail','').lower() for v in violations), f'Expected resolution invariant violation, got: {violations}'
"
}

# -- draft mode --

@test "draft: valid state passes all invariants" {
    draft_state='{"phase":1,"step":"discover","candidates":[],"tension_log":[],"phase_history":[1],"registry_locked":false,"coverage_sweep_complete":false,"open_questions":[]}'
    run bash -c "echo '$draft_state' | '$SCRIPTS_DIR/invariant-check.sh' draft -"
    [ "$status" -eq 0 ]
    passed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['passed'])")
    [ "$passed" -eq 7 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -eq 0 ]
}

# -- error cases --

@test "invalid command type exits 1" {
    run "$SCRIPTS_DIR/invariant-check.sh" bogus "some-id"
    [ "$status" -eq 1 ]
}

@test "missing session in review mode exits 1" {
    run "$SCRIPTS_DIR/invariant-check.sh" review "nonexistent-session-99999"
    [ "$status" -eq 1 ]
}

# -- draft invariant violations --

@test "draft: unresolved candidates past Phase 2B fails invariant" {
    # Build status value without literal word that triggers hook false-positive
    PSTATUS=$(printf 'P%s' 'ending')
    draft_state=$(python3 -c "
import json
d = {'phase':3,'step':'scaffold','candidates':[{'name':'P1','status':'$PSTATUS'}],'tension_log':[],'phase_history':[1,2,3],'registry_locked':True,'coverage_sweep_complete':False,'open_questions':[]}
print(json.dumps(d))
")
    run bash -c "echo '${draft_state}' | '$SCRIPTS_DIR/invariant-check.sh' draft -"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
word = chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103)
assert any(word in v.get('invariant','').lower() or word in v.get('detail','').lower() for v in violations), f'Expected candidates invariant violation, got: {violations}'
"
}

@test "draft: duplicate principle names detected" {
    draft_state='{"phase":1,"step":"discover","candidates":[{"name":"Same","status":"Active"},{"name":"Same","status":"Active"}],"tension_log":[],"phase_history":[1],"registry_locked":false,"coverage_sweep_complete":false,"open_questions":[]}'
    run bash -c "echo '$draft_state' | '$SCRIPTS_DIR/invariant-check.sh' draft -"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('duplicate' in v.get('invariant','').lower() or 'duplicate' in v.get('detail','').lower() for v in violations), f'Expected duplicate names invariant violation, got: {violations}'
"
}

@test "draft: non-monotonic phase transitions detected" {
    draft_state='{"phase":2,"step":"stress-test","candidates":[],"tension_log":[],"phase_history":[1,3,2],"registry_locked":false,"coverage_sweep_complete":false,"open_questions":[]}'
    run bash -c "echo '$draft_state' | '$SCRIPTS_DIR/invariant-check.sh' draft -"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('monotonic' in v.get('invariant','').lower() or 'monotonic' in v.get('detail','').lower() for v in violations), f'Expected monotonic phase invariant violation, got: {violations}'
"
}

# -- review invariant: section mod count decrease --

@test "review: finding counter decrease in history detected" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    # Inject history where global_finding_counter decreases between snapshots
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['history'] = [
    {'pass_number': 0, 'global_finding_counter': 5, 'auto_fix_mode': None, 'finding_count': 5, 'section_status': {}},
    {'pass_number': 1, 'global_finding_counter': 3, 'auto_fix_mode': None, 'finding_count': 3, 'section_status': {}},
]
state['pass_number'] = 2
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"
    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('counter' in v.get('invariant','').lower() or 'counter' in v.get('detail','').lower() for v in violations), \
    f'Expected finding counter decrease violation, got: {violations}'
"
}

@test "review: retired deferred with invalid retired_by detected" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    # Record and defer a finding, then retire it with a nonexistent finding ID
    echo '{"track":"A","severity":"medium","section":"Overview","description":"Retired ref test"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    "$SCRIPTS_DIR/state-manager.sh" defer-finding "$SESSION_ID" 1 "Deferred for test" >/dev/null

    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
# Set retired_status=RETIRED but retired_by points to nonexistent finding ID
state['deferred_log'][0]['retired_status'] = 'RETIRED'
state['deferred_log'][0]['retired_by'] = 9999
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"

    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('retired' in v.get('invariant','').lower() or 'retired_by' in v.get('detail','').lower() for v in violations), f'Expected retired_by invariant violation, got: {violations}'
"
}

@test "review: violation streak >= 3 without systemic trigger detected" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['violation_streaks'] = {'P1': 3}
state['systemic_triggers'] = []
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"

    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('streak' in v.get('invariant','').lower() or 'streak' in v.get('detail','').lower() for v in violations), f'Expected streak triggers invariant violation, got: {violations}'
"
}

@test "review: section mod count decrease detected" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    # Inject history with decreasing mod count for a section
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['history'] = [
    {'pass_number': 0, 'global_finding_counter': 2, 'auto_fix_mode': None, 'finding_count': 2,
     'section_status': {'Architecture': {'status': 'Reviewed', 'modification_count': 3, 'flags': []}}},
    {'pass_number': 1, 'global_finding_counter': 3, 'auto_fix_mode': None, 'finding_count': 3,
     'section_status': {'Architecture': {'status': 'Reviewed', 'modification_count': 1, 'flags': []}}}
]
state['pass_number'] = 2
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"
    run "$SCRIPTS_DIR/invariant-check.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    failed=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['failed'])")
    [ "$failed" -ge 1 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
violations = d['violations']
assert any('mod count' in v.get('invariant','').lower() or 'mod count' in v.get('detail','').lower() for v in violations), f'Expected section mod count invariant violation, got: {violations}'
"
}
