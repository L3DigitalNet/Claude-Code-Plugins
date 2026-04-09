#!/usr/bin/env bats
# Tests for flight-log.sh — flight log management.

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "append with valid JSON adds timestamp and writes to runs.jsonl" {
    run bash -c "echo '{\"type\":\"postflight\",\"result\":\"nominal\"}' | '$SCRIPTS_DIR/flight-log.sh' append"
    [ "$status" -eq 0 ]
    # Output should be valid JSON with a timestamp field
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert 'timestamp' in data, 'missing timestamp'
assert data['type'] == 'postflight'
assert data['result'] == 'nominal'
"
    # File should exist
    [ -f ".claude/nominal/runs.jsonl" ]
}

@test "append with invalid JSON exits 1" {
    run bash -c "echo 'not json at all' | '$SCRIPTS_DIR/flight-log.sh' append 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid JSON"* ]]
}

@test "read with --last 1 returns last record" {
    # Write two records
    echo '{"type":"preflight","seq":1}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null
    echo '{"type":"postflight","seq":2}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null

    run bash "$SCRIPTS_DIR/flight-log.sh" read --last 1
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert isinstance(data, list), 'expected array'
assert len(data) == 1, f'expected 1 record, got {len(data)}'
assert data[0]['seq'] == 2, f'expected seq 2, got {data[0][\"seq\"]}'
"
}

@test "read on nonexistent file returns empty array" {
    run bash "$SCRIPTS_DIR/flight-log.sh" read
    [ "$status" -eq 0 ]
    [[ "$output" == "[]" ]]
}

@test "query --type filters correctly" {
    echo '{"type":"postflight","data":"a"}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null
    echo '{"type":"abort","data":"b"}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null
    echo '{"type":"postflight","data":"c"}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null

    run bash "$SCRIPTS_DIR/flight-log.sh" query --type postflight
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert isinstance(data, list)
assert len(data) == 2, f'expected 2 postflight records, got {len(data)}'
for r in data:
    assert r['type'] == 'postflight'
"
}

@test "query without --type exits 1" {
    run bash -c "'$SCRIPTS_DIR/flight-log.sh' query 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"--type"* ]]
}

@test "invalid subcommand exits 1" {
    run bash -c "'$SCRIPTS_DIR/flight-log.sh' badcommand 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage"* ]]
}

@test "read with --last 3 returns multiple records" {
    echo '{"type":"preflight","seq":1}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null
    echo '{"type":"postflight","seq":2}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null
    echo '{"type":"abort","seq":3}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null

    run bash "$SCRIPTS_DIR/flight-log.sh" read --last 3
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert isinstance(data, list), 'expected array'
assert len(data) == 3, f'expected 3 records, got {len(data)}'
assert data[0]['seq'] == 1
assert data[1]['seq'] == 2
assert data[2]['seq'] == 3
"
}

@test "append preserves user-supplied timestamp" {
    run bash -c "echo '{\"type\":\"postflight\",\"timestamp\":\"2025-01-01T00:00:00Z\",\"result\":\"nominal\"}' | '$SCRIPTS_DIR/flight-log.sh' append"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['timestamp'] == '2025-01-01T00:00:00Z', f'timestamp was overwritten: {data[\"timestamp\"]}'
assert data['type'] == 'postflight'
assert data['result'] == 'nominal'
"
}

@test "query returns records with correct data fields" {
    echo '{"type":"postflight","result":"nominal","host":"srv1"}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null
    echo '{"type":"abort","reason":"disk_full"}' | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null

    run bash "$SCRIPTS_DIR/flight-log.sh" query --type postflight
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert len(data) >= 1
rec = data[0]
assert rec['type'] == 'postflight'
assert rec['result'] == 'nominal'
assert rec['host'] == 'srv1'
assert 'timestamp' in rec, 'missing timestamp field'
"
}
