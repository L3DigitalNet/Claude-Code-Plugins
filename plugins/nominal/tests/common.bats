#!/usr/bin/env bats
# Tests for _common.sh shared utilities.

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "ensure_python sets PYTHON" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && echo \"\$PYTHON\""
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *python* ]]
}

@test "has_tool returns 0 for existing tool (python3)" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && has_tool python3"
    [ "$status" -eq 0 ]
}

@test "has_tool returns 1 for nonexistent tool (zzz_fake_tool)" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && has_tool zzz_fake_tool"
    [ "$status" -eq 1 ]
}

@test "detect_firewall returns a known value" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && detect_firewall"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should be one of the known firewall tools or "none"
    [[ "$output" =~ ^(ufw|firewall-cmd|nft|iptables|none)$ ]]
}

@test "detect_dns_tool returns a known value" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && detect_dns_tool"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" =~ ^(dig|host|nslookup|python)$ ]]
}

@test "check_result produces valid JSON with name, status, evidence fields" {
    run bash -c 'source "'"$SCRIPTS_DIR"'/_common.sh" && echo "test evidence" | check_result "test_check" "pass"'
    [ "$status" -eq 0 ]
    # Validate JSON structure
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['name'] == 'test_check', f'name mismatch: {data[\"name\"]}'
assert data['status'] == 'pass', f'status mismatch: {data[\"status\"]}'
assert data['evidence'] == 'test evidence', f'evidence mismatch: {data[\"evidence\"]}'
"
}

@test "json_error exits 1 and writes to stderr" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && json_error 'something broke' 2>&1"
    [ "$status" -eq 1 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['error'] == 'something broke'
"
}

@test "load_profile with nonexistent file exits 1" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && load_profile '/tmp/nonexistent_profile_$$' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Profile not found"* ]]
}

@test "load_profile with valid JSON file returns the JSON content" {
    echo '{"foo": "bar", "num": 42}' > "$TEST_TMPDIR/valid_profile.json"
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && load_profile '$TEST_TMPDIR/valid_profile.json'"
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['foo'] == 'bar', f'foo mismatch: {data[\"foo\"]}'
assert data['num'] == 42, f'num mismatch: {data[\"num\"]}'
"
}

@test "load_profile with malformed JSON exits 1" {
    echo 'not valid json {{{' > "$TEST_TMPDIR/bad_profile.json"
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && load_profile '$TEST_TMPDIR/bad_profile.json' 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Invalid environment.json"* ]]
}

@test "run_check with empty command returns error" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && run_check '' 2>&1"
    [ "$status" -ne 0 ]
}

@test "run_check executes local command successfully" {
    run bash -c "source '$SCRIPTS_DIR/_common.sh' && run_check 'echo hello'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hello"* ]]
}

@test "check_result with multiline evidence produces valid JSON" {
    run bash -c 'source "'"$SCRIPTS_DIR"'/_common.sh" && printf "line one\nline two\nline three" | check_result "multi_check" "pass"'
    [ "$status" -eq 0 ]
    echo "$output" | python3 -c "
import json, sys
data = json.load(sys.stdin)
assert data['name'] == 'multi_check'
assert data['status'] == 'pass'
assert 'line one' in data['evidence']
assert 'line two' in data['evidence']
assert 'line three' in data['evidence']
"
}
