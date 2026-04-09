#!/usr/bin/env bats
# Tests for test-status-update.sh
# Validates all subcommands for TEST_STATUS.json management.

load helpers

setup() {
    setup_test_env
}

teardown() {
    teardown_test_env
}

@test "init creates file and returns template" {
    cd "$TEST_TMPDIR"
    run "$SCRIPTS_DIR/test-status-update.sh" init
    [ "$status" -eq 0 ]
    # File should exist
    [ -f "$TEST_TMPDIR/docs/testing/TEST_STATUS.json" ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['last_analysis'] is None
assert d['project_type'] is None
assert d['gaps'] == []
assert d['history'] == []
"
}

@test "read returns template when no file exists" {
    cd "$TEST_TMPDIR"
    run "$SCRIPTS_DIR/test-status-update.sh" read
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['last_analysis'] is None
assert d['gaps'] == []
"
}

@test "update merges at top level (shallow merge)" {
    cd "$TEST_TMPDIR"
    # Initialize first
    "$SCRIPTS_DIR/test-status-update.sh" init > /dev/null 2>&1
    # Update with a patch
    run bash -c 'echo "{\"project_type\":\"python\",\"coverage\":{\"line\":80}}" | '"$SCRIPTS_DIR/test-status-update.sh"' update'
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python', f'expected python, got {d[\"project_type\"]}'
assert d['coverage'] == {'line': 80}, f'expected line:80, got {d[\"coverage\"]}'
# Original fields preserved
assert d['last_analysis'] is None
assert d['gaps'] == []
"
}

@test "set-field sets a string value" {
    cd "$TEST_TMPDIR"
    "$SCRIPTS_DIR/test-status-update.sh" init > /dev/null 2>&1
    run "$SCRIPTS_DIR/test-status-update.sh" set-field project_type "python"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['project_type'] == 'python', f'expected python, got {d[\"project_type\"]}'
"
}

@test "set-field with JSON value parses correctly (42 becomes number)" {
    cd "$TEST_TMPDIR"
    "$SCRIPTS_DIR/test-status-update.sh" init > /dev/null 2>&1
    run "$SCRIPTS_DIR/test-status-update.sh" set-field score "42"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['score'] == 42, f'expected int 42, got {d[\"score\"]} (type {type(d[\"score\"]).__name__})'
assert isinstance(d['score'], int)
"
}

@test "add-gap appends to gaps array" {
    cd "$TEST_TMPDIR"
    "$SCRIPTS_DIR/test-status-update.sh" init > /dev/null 2>&1
    run bash -c 'echo "{\"id\":\"gap-1\",\"description\":\"missing tests for utils\"}" | '"$SCRIPTS_DIR/test-status-update.sh"' add-gap'
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['gaps']) == 1, f'expected 1 gap, got {len(d[\"gaps\"])}'
assert d['gaps'][0]['id'] == 'gap-1'
assert d['gaps'][0]['description'] == 'missing tests for utils'
"
}

@test "remove-gap removes by id" {
    cd "$TEST_TMPDIR"
    "$SCRIPTS_DIR/test-status-update.sh" init > /dev/null 2>&1
    # Add two gaps
    echo '{"id":"gap-1","description":"first"}' | "$SCRIPTS_DIR/test-status-update.sh" add-gap > /dev/null 2>&1
    echo '{"id":"gap-2","description":"second"}' | "$SCRIPTS_DIR/test-status-update.sh" add-gap > /dev/null 2>&1
    # Remove the first
    run "$SCRIPTS_DIR/test-status-update.sh" remove-gap gap-1
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert len(d['gaps']) == 1, f'expected 1 gap remaining, got {len(d[\"gaps\"])}'
assert d['gaps'][0]['id'] == 'gap-2'
"
}

@test "malformed JSON in status file: read exits 1 with error" {
    cd "$TEST_TMPDIR"
    mkdir -p "$TEST_TMPDIR/docs/testing"
    echo "this is not valid json {{{" > "$TEST_TMPDIR/docs/testing/TEST_STATUS.json"
    run "$SCRIPTS_DIR/test-status-update.sh" read
    [ "$status" -eq 1 ]
    # stderr should contain an error about malformed JSON
    echo "$output" | python3 -c "
import sys
text = sys.stdin.read()
assert 'malformed' in text.lower() or 'error' in text.lower(), f'expected error message, got: {text}'
"
}

@test "read on missing file returns template with null last_analysis" {
    cd "$TEST_TMPDIR"
    # Ensure no status file exists
    rm -f "$TEST_TMPDIR/docs/testing/TEST_STATUS.json"
    run "$SCRIPTS_DIR/test-status-update.sh" read
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
d = json.load(sys.stdin)
assert d['last_analysis'] is None, f'expected null last_analysis, got {d[\"last_analysis\"]}'
assert d['project_type'] is None, f'expected null project_type, got {d[\"project_type\"]}'
assert d['gaps'] == [], f'expected empty gaps, got {d[\"gaps\"]}'
assert d['history'] == [], f'expected empty history, got {d[\"history\"]}'
"
}

@test "invalid subcommand exits 1" {
    cd "$TEST_TMPDIR"
    run "$SCRIPTS_DIR/test-status-update.sh" bogus
    [ "$status" -eq 1 ]
}
