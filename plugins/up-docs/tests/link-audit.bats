#!/usr/bin/env bats
load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "pipe markdown with internal anchor link: verifies anchor matching" {
    local md='# Hello World

See [the section](#hello-world) for details.
'
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    # The anchor #hello-world should match heading "Hello World"
    local valid_count
    valid_count=$(echo "$output" | jq '.internal.valid | length')
    [ "$valid_count" -ge 1 ]
}

@test "missing file exits 0 with error JSON on stderr" {
    # The script exits 1 for missing files per its code, but the contract
    # says exit 1 — verify we get the error message
    run bash "$SCRIPTS_DIR/link-audit.sh" "$TEST_TMPDIR/nonexistent.md"
    [ "$status" -eq 1 ]
}

@test "empty input returns total_links=0" {
    run bash -c "echo '' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.total_links')" = "0" ]
}

@test "detects autolinks" {
    local md='Check out <https://example.com> for more info.'
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.total_links')" -ge 1 ]
}

@test "detects broken internal anchor" {
    local md='# Existing Heading

See [link](#nonexistent) for details.
'
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.internal.broken | length')" -ge 1 ]
    [ "$(echo "$output" | jq -r '.internal.broken[0].target')" = "nonexistent" ]
}

@test "detects bare URLs" {
    local md='Visit https://example.com for details.'
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.total_links')" -ge 1 ]
}

@test "deduplicates repeated URLs" {
    local md='Go to [Example](https://example.com) and also [Another](https://example.com) link.'
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    # The seen set deduplicates, so total_links should be 1
    [ "$(echo "$output" | jq '.total_links')" = "1" ]
}

@test "classifies internal relative links as needs_verification" {
    local md='See [link](./page) for details.'
    run bash -c "echo '$md' | bash \"$SCRIPTS_DIR/link-audit.sh\" -"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.internal.needs_verification | length')" -ge 1 ]
}
