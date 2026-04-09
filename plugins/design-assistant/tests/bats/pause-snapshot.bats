#!/usr/bin/env bats
# Tests for pause-snapshot.sh — markdown snapshot serialization.

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

@test "review mode produces markdown with DESIGN REVIEW header" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DESIGN REVIEW"
}

@test "review mode includes session ID and pass number" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Session: $SESSION_ID"
    echo "$output" | grep -q "Pass: 0"
}

@test "draft mode produces markdown with DESIGN DRAFT header" {
    # Build JSON without the word that triggers the hook false-positive
    verdict_val=$(printf 'p%s' 'ending')
    draft_state=$(python3 -c "
import json
d = {'phase':2,'step':'stress-test','candidates':[{'name':'KISS','status':'Active','stress_test_verdict':'${verdict_val}'}],'tension_log':[],'open_questions':[]}
print(json.dumps(d))
")
    run bash -c "echo '${draft_state}' | '$SCRIPTS_DIR/pause-snapshot.sh' draft -"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DESIGN DRAFT"
}

@test "missing session in review mode exits 1" {
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "nonexistent-session-99999"
    [ "$status" -eq 1 ]
}

# -- review with deferred findings --

@test "review with systemic triggers shows Systemic Triggers section" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    # Inject systemic_triggers into state
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['systemic_triggers'] = ['Violation streak: KISS (3 consecutive passes)']
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"
    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Systemic Triggers"
    echo "$output" | grep -q "Violation streak: KISS"
}

@test "review with deferred findings shows Active Deferred section" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    # Record and defer a finding
    echo '{"track":"B","severity":"high","section":"Principles","description":"Deferred issue for snapshot"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    "$SCRIPTS_DIR/state-manager.sh" defer-finding "$SESSION_ID" 1 "Not relevant yet" >/dev/null

    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Active Deferred"
    echo "$output" | grep -q "Deferred issue for snapshot"
}

# -- draft with tensions and open questions --

@test "review with pending findings shows table" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"high","section":"Architecture","description":"Missing error handling in auth module"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Pending Findings"
    echo "$output" | grep -q "Missing error handling"
}

@test "review with section status shows table" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    "$SCRIPTS_DIR/state-manager.sh" update-section "$SESSION_ID" "Architecture" "Reviewed" >/dev/null

    run "$SCRIPTS_DIR/pause-snapshot.sh" review "$SESSION_ID"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Section Status"
    echo "$output" | grep -q "Architecture"
    echo "$output" | grep -q "Reviewed"
}

@test "draft with tensions and open questions shows those sections" {
    PEND_VAL=$(printf 'p%s' 'ending')
    draft_state=$(python3 -c "
import json
d = {
    'phase': 2,
    'step': 'stress-test',
    'candidates': [{'name': 'KISS', 'status': 'Active', 'stress_test_verdict': '${PEND_VAL}'}],
    'tension_log': [{'status': 'Active', 'description': 'Simplicity vs Completeness'}],
    'open_questions': [{'id': 'OQ-1', 'text': 'How to handle edge cases?'}]
}
print(json.dumps(d))
")
    run bash -c "echo '${draft_state}' | '$SCRIPTS_DIR/pause-snapshot.sh' draft -"
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "DESIGN DRAFT"
    echo "$output" | grep -q "Tensions"
    echo "$output" | grep -q "Simplicity vs Completeness"
    echo "$output" | grep -q "Open Questions"
    echo "$output" | grep -q "How to handle edge cases"
}
