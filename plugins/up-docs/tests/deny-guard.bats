#!/usr/bin/env bats
# Tests for scripts/deny-guard.sh — the PreToolUse forbidden-command validator.

load helpers

GUARD="$(cd "$BATS_TEST_DIRNAME/.." && pwd)/scripts/deny-guard.sh"
export GUARD  # required: bash -c subshells in tests below need GUARD in their env

setup() {
    # deny-guard is scoped: it only enforces when invoked from inside an
    # up-docs:* subagent (detected by walking the JSONL transcript for an
    # open Agent tool_use block). Point transcript_path at a fixture that
    # simulates that condition so the enforcement path is exercised.
    export TRANSCRIPT="$BATS_TEST_DIRNAME/fixtures/up-docs-active-transcript.jsonl"
}

@test "deny-guard blocks rm" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"rm -rf /tmp/x"}}'
    [ "$status" -eq 2 ]
    [[ "$output" == *'"permissionDecision":"deny"'* ]]
}

@test "deny-guard blocks pct destroy" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"pct destroy 105"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks systemctl stop" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"systemctl stop nginx"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks tee redirect to /etc" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"cat foo | tee /etc/passwd"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks chained rm after &&" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"ls /tmp && rm -rf /tmp/junk"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks rm inside subshell substitution" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"echo $(rm -rf /tmp/x)"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks SQL DELETE" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"sqlite3 db.sqlite \"DELETE FROM users\""}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks redirect to /etc" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"echo bad > /etc/hosts"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard blocks pip install" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"pip install requests"}}'
    [ "$status" -eq 2 ]
}

@test "deny-guard allows git status" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"git status"}}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "deny-guard allows ssh read-only" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","transcript_path":"'"$TRANSCRIPT"'","tool_input":{"command":"ssh gmk pct list"}}'
    [ "$status" -eq 0 ]
}

@test "deny-guard fails open on malformed JSON" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ 'not-json'
    [ "$status" -eq 0 ]
}

@test "deny-guard fails open on missing command field" {
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{}}'
    [ "$status" -eq 0 ]
}

@test "deny-guard fails open when not inside an up-docs subagent (no transcript)" {
    # Sanity check on the scope-gating behavior introduced in commit 8483991:
    # the same rm command that's blocked above must exit 0 when no transcript
    # is provided, because the deny-guard only enforces inside up-docs:* agents.
    run bash -c 'echo "$1" | bash "$GUARD"' _ '{"tool_name":"Bash","tool_input":{"command":"rm -rf /tmp/x"}}'
    [ "$status" -eq 0 ]
}
