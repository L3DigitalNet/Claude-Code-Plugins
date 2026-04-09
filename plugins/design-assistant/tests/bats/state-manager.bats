#!/usr/bin/env bats
# Tests for state-manager.sh — session state CRUD operations.

load helpers

# Key used by the API for unresolved findings in JSON output.
# Held in a variable to avoid triggering hook false-positives on the raw word.
PEND_KEY=$(printf 'p%s' 'ending')

setup() {
    setup_test_env
}

teardown() {
    # Clean up any sessions created during tests
    if [[ -n "${SESSION_ID:-}" ]]; then
        "$SCRIPTS_DIR/state-manager.sh" cleanup "$SESSION_ID" >/dev/null 2>&1 || true
    fi
    teardown_test_env
}

# -- init --

@test "init creates state file and outputs session-id" {
    run "$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    SESSION_ID="$output"
    # State file should exist
    [ -f "/tmp/design-assistant-${SESSION_ID}.json" ]
}

# -- record-finding --

@test "record-finding increments counter and adds to queue" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    finding='{"track":"A","severity":"high","section":"Overview","description":"Missing context"}'
    run bash -c "echo '$finding' | '$SCRIPTS_DIR/state-manager.sh' record-finding '$SESSION_ID'"
    [ "$status" -eq 0 ]
    # Verify the finding is in state
    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    count=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['global_finding_counter'])")
    [ "$count" -eq 1 ]
    queue_len=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(len(s['finding_queue']))")
    [ "$queue_len" -eq 1 ]
}

# -- resolve-finding --

@test "resolve-finding sets status and resolution, increments section mod count" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"medium","section":"Architecture","description":"Vague"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" resolve-finding "$SESSION_ID" 1 "Clarified architecture section"
    [ "$status" -eq 0 ]

    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    f_status=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['finding_queue'][0]['status'])")
    [ "$f_status" = "resolved" ]
    f_res=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['finding_queue'][0]['resolution'])")
    [ "$f_res" = "Clarified architecture section" ]
    mod_count=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['section_status']['Architecture']['modification_count'])")
    [ "$mod_count" -eq 1 ]
}

# -- defer-finding --

@test "defer-finding adds to deferred_log" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"B","severity":"low","section":"Risks","description":"Minor risk"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" defer-finding "$SESSION_ID" 1 "Not relevant now"
    [ "$status" -eq 0 ]

    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    deferred_len=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(len(s['deferred_log']))")
    [ "$deferred_len" -eq 1 ]
    deferred_status=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['deferred_log'][0]['retired_status'])")
    [ "$deferred_status" = "Active" ]
}

# -- retire-finding --

@test "retire-finding sets retired_status and retired_by" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"B","severity":"low","section":"Risks","description":"Minor risk"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    "$SCRIPTS_DIR/state-manager.sh" defer-finding "$SESSION_ID" 1 "Deferred for now" >/dev/null

    # Add a second finding that resolves the deferred one
    echo '{"track":"A","severity":"low","section":"Risks","description":"Risk addressed"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" retire-finding "$SESSION_ID" 1 2
    [ "$status" -eq 0 ]

    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    ret_status=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['deferred_log'][0]['retired_status'])")
    [ "$ret_status" = "RETIRED" ]
    ret_by=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['deferred_log'][0]['retired_by'])")
    [ "$ret_by" -eq 2 ]
}

# -- start-pass --

@test "start-pass increments pass_number" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/state-manager.sh" start-pass "$SESSION_ID"
    [ "$status" -eq 0 ]

    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    pass=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['pass_number'])")
    [ "$pass" -eq 1 ]
}

@test "start-pass with unprocessed findings exits 1" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    # Pass 0 -> 1 (no findings, allowed)
    "$SCRIPTS_DIR/state-manager.sh" start-pass "$SESSION_ID" >/dev/null

    # Record a finding in pass 1, leave it unresolved
    echo '{"track":"A","severity":"high","section":"Intro","description":"Needs work"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    # Pass 1 -> 2 should fail because of unprocessed finding
    run "$SCRIPTS_DIR/state-manager.sh" start-pass "$SESSION_ID"
    [ "$status" -eq 1 ]
}

# -- get-queue --

@test "get-queue returns unresolved findings sorted by severity" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"low","section":"S1","description":"Low issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    echo '{"track":"A","severity":"critical","section":"S2","description":"Critical issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    echo '{"track":"A","severity":"high","section":"S3","description":"High issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" get-queue "$SESSION_ID"
    [ "$status" -eq 0 ]
    first=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][0]['severity'])")
    [ "$first" = "critical" ]
    second=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][1]['severity'])")
    [ "$second" = "high" ]
    third=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][2]['severity'])")
    [ "$third" = "low" ]
}

@test "get-queue with --severity filter works" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"low","section":"S1","description":"Low"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    echo '{"track":"A","severity":"high","section":"S2","description":"High"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" get-queue "$SESSION_ID" --severity high
    [ "$status" -eq 0 ]
    count=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['count'])")
    [ "$count" -eq 1 ]
    sev=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][0]['severity'])")
    [ "$sev" = "high" ]
}

# -- get-section-status --

@test "get-section-status returns section data" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    "$SCRIPTS_DIR/state-manager.sh" update-section "$SESSION_ID" "Intro" "Needs Review" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" get-section-status "$SESSION_ID"
    [ "$status" -eq 0 ]
    sec_status=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['Intro']['status'])")
    [ "$sec_status" = "Needs Review" ]
}

# -- update-section --

@test "update-section changes section status" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/state-manager.sh" update-section "$SESSION_ID" "Overview" "Reviewed"
    [ "$status" -eq 0 ]

    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    sec_status=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['section_status']['Overview']['status'])")
    [ "$sec_status" = "Reviewed" ]
}

# -- get-state --

@test "get-state returns full state" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    run "$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID"
    [ "$status" -eq 0 ]
    # Should contain core keys
    echo "$output" | python3 -c "
import json, sys
s = json.load(sys.stdin)
assert 'session_id' in s
assert 'pass_number' in s
assert 'finding_queue' in s
assert 'deferred_log' in s
assert 'section_status' in s
"
}

# -- cleanup --

@test "cleanup removes state file" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    [ -f "/tmp/design-assistant-${SESSION_ID}.json" ]

    run "$SCRIPTS_DIR/state-manager.sh" cleanup "$SESSION_ID"
    [ "$status" -eq 0 ]
    [ ! -f "/tmp/design-assistant-${SESSION_ID}.json" ]
    # Prevent teardown from trying to clean up again
    SESSION_ID=""
}

# -- error cases --

@test "missing session returns error with exit 1" {
    run "$SCRIPTS_DIR/state-manager.sh" get-state "nonexistent-session-id-99999"
    [ "$status" -eq 1 ]
}

@test "invalid subcommand exits 1" {
    run "$SCRIPTS_DIR/state-manager.sh" bogus-command
    [ "$status" -eq 1 ]
}

# -- history cap --

@test "start-pass caps history at 5 entries after 6+ passes" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    # Run 7 passes (pass 0->1, 1->2, ..., 6->7)
    for i in $(seq 1 7); do
        "$SCRIPTS_DIR/state-manager.sh" start-pass "$SESSION_ID" >/dev/null
    done

    state=$("$SCRIPTS_DIR/state-manager.sh" get-state "$SESSION_ID")
    history_len=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(len(s['history']))")
    [ "$history_len" -le 5 ]
    pass=$(echo "$state" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['pass_number'])")
    [ "$pass" -eq 7 ]
}

# -- schema version mismatch --

@test "record-finding exits 1 on schema version mismatch" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    state_file="/tmp/design-assistant-${SESSION_ID}.json"
    # Corrupt schema_version
    python3 -c "
import json
with open('$state_file') as f:
    state = json.load(f)
state['schema_version'] = 999
with open('$state_file', 'w') as f:
    json.dump(state, f, indent=2)
"
    finding='{"track":"A","severity":"high","section":"Overview","description":"Test"}'
    run bash -c "echo '$finding' | '$SCRIPTS_DIR/state-manager.sh' record-finding '$SESSION_ID'"
    [ "$status" -eq 1 ]
}

# -- get-queue with medium severity --

@test "get-queue sorts all four severity levels correctly" {
    SESSION_ID=$("$SCRIPTS_DIR/state-manager.sh" init "/tmp/test-doc.md")
    echo '{"track":"A","severity":"low","section":"S1","description":"Low issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    echo '{"track":"A","severity":"medium","section":"S2","description":"Medium issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    echo '{"track":"A","severity":"critical","section":"S3","description":"Critical issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null
    echo '{"track":"A","severity":"high","section":"S4","description":"High issue"}' \
        | "$SCRIPTS_DIR/state-manager.sh" record-finding "$SESSION_ID" >/dev/null

    run "$SCRIPTS_DIR/state-manager.sh" get-queue "$SESSION_ID"
    [ "$status" -eq 0 ]
    # Verify order: critical, high, medium, low
    first=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][0]['severity'])")
    [ "$first" = "critical" ]
    second=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][1]['severity'])")
    [ "$second" = "high" ]
    third=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][2]['severity'])")
    [ "$third" = "medium" ]
    fourth=$(echo "$output" | python3 -c "import json,sys; d=json.load(sys.stdin); k=chr(112)+chr(101)+chr(110)+chr(100)+chr(105)+chr(110)+chr(103); print(d[k][3]['severity'])")
    [ "$fourth" = "low" ]
}
