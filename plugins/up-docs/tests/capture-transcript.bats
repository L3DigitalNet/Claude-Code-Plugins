#!/usr/bin/env bats
# Tests for scripts/capture-transcript.sh — opt-in PostToolUse capture hook.

load helpers

CAP="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/capture-transcript.sh"
export CAP  # required: bash -c subshells in tests below need CAP in their env

setup() {
    setup_test_env
    export UP_DOCS_TRANSCRIPT_LOG="$TEST_TMPDIR/transcript.jsonl"
    : > "$UP_DOCS_TRANSCRIPT_LOG"
}

teardown() {
    unset UP_DOCS_TRANSCRIPT_LOG
    teardown_test_env
}

@test "capture is no-op when UP_DOCS_TRANSCRIPT_LOG is unset" {
    unset UP_DOCS_TRANSCRIPT_LOG
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "capture writes a JSONL line for Bash tools" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hello"},"tool_response":{"output":"hello\n"}}'
    [ "$status" -eq 0 ]
    [ -s "$UP_DOCS_TRANSCRIPT_LOG" ]
    run jq -r '.command' "$UP_DOCS_TRANSCRIPT_LOG"
    [ "$output" = "echo hello" ]
}

@test "capture sets file permissions to 600" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}'
    [ "$(stat -c '%a' "$UP_DOCS_TRANSCRIPT_LOG")" = "600" ]
}

@test "capture corrects looser permissions on pre-existing file" {
    chmod 644 "$UP_DOCS_TRANSCRIPT_LOG"
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo hi"},"tool_response":{"output":"hi"}}'
    [ "$(stat -c '%a' "$UP_DOCS_TRANSCRIPT_LOG")" = "600" ]
}

@test "capture does not record Read tool calls" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"},"tool_response":{"output":"root:x"}}'
    [ "$status" -eq 0 ]
    [ ! -s "$UP_DOCS_TRANSCRIPT_LOG" ]
}

@test "capture redacts Bearer tokens" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer abcdefghijklmnopqrstuvwxyz123\""},"tool_response":{"output":""}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" == *"Bearer [REDACTED]"* ]]
    [[ "$output" != *"abcdefghijklmnopqrstuvwxyz123"* ]]
}

@test "capture redacts BAO_TOKEN" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"export BAO_TOKEN=hvs.deadbeef123456789012345 && bao status"},"tool_response":{"output":"sealed=false"}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" != *"hvs.deadbeef123456789012345"* ]]
    [[ "$output" == *"[REDACTED]"* ]]
}

@test "capture redacts ghp_ tokens in output field" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo $GH"},"tool_response":{"output":"ghp_abcdefghijklmnopqrstuvwxyz0123456789"}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" != *"ghp_abcdefghijklmnopqrstuvwxyz0123456789"* ]]
    [[ "$output" == *"[REDACTED]"* ]]
}

@test "capture redacts github_pat_ fine-grained tokens" {
    run bash -c 'echo "$1" | bash "$CAP"' _ '{"tool_name":"Bash","tool_input":{"command":"echo $GH"},"tool_response":{"output":"github_pat_11ABCDEFG0abcdefghijk_abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVW"}}'
    run cat "$UP_DOCS_TRANSCRIPT_LOG"
    [[ "$output" != *"11ABCDEFG0abcdefghijk_abcdefghijklmnopqrstuvwxyz"* ]]
    [[ "$output" == *"github_pat_[REDACTED]"* ]]
}

@test "capture truncates very large outputs" {
    local big_input
    big_input='{"tool_name":"Bash","tool_input":{"command":"yes hi"},"tool_response":{"output":"'"$(printf 'a%.0s' $(seq 1 8192))"'"}}'
    run bash -c 'echo "$1" | bash "$CAP"' _ "$big_input"
    [ "$status" -eq 0 ]
    run jq -r '.output | length' "$UP_DOCS_TRANSCRIPT_LOG"
    [ "$output" -le 4096 ]
}

@test "capture fails open on malformed JSON" {
    run bash -c 'echo "$1" | bash "$CAP"' _ 'not-json'
    [ "$status" -eq 0 ]
    [ ! -s "$UP_DOCS_TRANSCRIPT_LOG" ]
}
