#!/usr/bin/env bats
load helpers

setup() {
    setup_test_env
    # Use a unique state file per test to avoid cross-contamination
    export STATE_FILE="$TEST_TMPDIR/tracker-state.json"
    # The script hardcodes /tmp/up-docs-drift-tracker.json — we clean it
    rm -f /tmp/up-docs-drift-tracker.json
}

teardown() {
    rm -f /tmp/up-docs-drift-tracker.json
    teardown_test_env
}

@test "init returns status=initialized" {
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.status')" = "initialized" ]
}

@test "start-phase creates phase entry" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.status')" = "started" ]
}

@test "record-iteration increments iteration count" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    run bash -c 'echo "{\"findings\":[\"a\"],\"fixes_applied\":1}" | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.iteration')" = "1" ]

    run bash -c 'echo "{\"findings\":[\"b\"],\"fixes_applied\":1}" | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1'
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.iteration')" = "2" ]
}

@test "check-convergence with zero findings returns converged=true" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":[],"fixes_applied":0}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-convergence 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.converged')" = "true" ]
}

@test "check-convergence with findings returns converged=false" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":["issue-a"],"fixes_applied":1}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-convergence 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.converged')" = "false" ]
}

@test "check-oscillation with <3 iterations returns oscillating=false" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":["a"],"fixes_applied":1}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    echo '{"findings":[],"fixes_applied":0}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-oscillation 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.oscillating')" = "false" ]
    [[ "$output" == *"fewer than 3 iterations"* ]]
}

@test "reset clears state" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" reset
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.status')" = "reset" ]

    # After reset, status should return the template (empty phases)
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq '.phases | length')" = "0" ]
}

@test "oscillation detection with oscillating data" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    # iter 1: finding with key "X" present (objects with .key for finding_keys)
    echo '{"findings":[{"key":"X"}],"fixes_applied":1}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    # iter 2: finding "X" absent
    echo '{"findings":[],"fixes_applied":0}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    # iter 3: finding "X" reappears
    echo '{"findings":[{"key":"X"}],"fixes_applied":1}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-oscillation 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.oscillating')" = "true" ]
}

@test "max_iterations_reached status" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    # Record 10 iterations each with findings (max_iterations defaults to 10)
    for i in $(seq 1 10); do
        echo "{\"findings\":[\"issue-$i\"],\"fixes_applied\":1}" \
          | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    done

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" check-convergence 1
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.max_iterations_reached')" = "true" ]
    [ "$(echo "$output" | jq -r '.converged')" = "false" ]
}

@test "check-convergence updates phase status to converged" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1
    echo '{"findings":[],"fixes_applied":0}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    # Trigger convergence check which should update internal state
    bash "$SCRIPTS_DIR/convergence-tracker.sh" check-convergence 1

    # Now verify via status that the phase is marked converged
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.phases["1"].status')" = "converged" ]
}

@test "record-iteration on un-started phase exits 1" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init

    run bash -c 'echo "{\"findings\":[],\"fixes_applied\":0}" | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 99'
    [ "$status" -eq 1 ]
}

@test "record-iteration accumulates changes_applied" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    echo '{"findings":["a","b","c"],"fixes_applied":3}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    echo '{"findings":["d","e"],"fixes_applied":2}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.phases["1"].changes_applied')" = "5" ]
}

@test "record-iteration tracks pages_touched as max" {
    bash "$SCRIPTS_DIR/convergence-tracker.sh" init
    bash "$SCRIPTS_DIR/convergence-tracker.sh" start-phase 1

    echo '{"findings":["a"],"fixes_applied":1,"pages_touched":3}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1
    echo '{"findings":["b"],"fixes_applied":1,"pages_touched":5}' | bash "$SCRIPTS_DIR/convergence-tracker.sh" record-iteration 1

    run bash "$SCRIPTS_DIR/convergence-tracker.sh" status
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.phases["1"].pages_touched')" = "5" ]
}

@test "invalid subcommand exits 1" {
    run bash "$SCRIPTS_DIR/convergence-tracker.sh" bogus-command
    [ "$status" -eq 1 ]
}
