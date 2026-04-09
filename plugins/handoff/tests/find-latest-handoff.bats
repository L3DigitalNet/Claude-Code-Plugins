#!/usr/bin/env bats
load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "empty directory returns found=false" {
    mkdir -p "$TEST_TMPDIR/empty-handoffs"
    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/empty-handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "false" ]
}

@test "directory with handoff file returns found=true with metadata" {
    mkdir -p "$TEST_TMPDIR/handoffs"
    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-09-120000.md" << 'EOF'
# Test Handoff Task

**Machine:** testhost
**Working directory:** /tmp/test

## Task Summary
Did some work.

## Next Steps
1. Step one
2. Step two
3. Step three
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "true" ]
    [ "$(echo "$output" | jq -r '.filename')" = "handoff-2026-04-09-120000.md" ]
}

@test "inaccessible directory returns found=false with error" {
    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/does-not-exist"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "false" ]
    [[ "$output" == *"not accessible"* ]]
}

@test "fixture handoff metadata: title, sections, next_steps_count" {
    mkdir -p "$TEST_TMPDIR/handoffs"
    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-09-120000.md" << 'EOF'
# Test Handoff Task

**Machine:** testhost
**Working directory:** /tmp/test

## Task Summary
Did some work.

## Next Steps
1. Step one
2. Step two
3. Step three
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    [ "$(echo "$output" | jq -r '.metadata.title')" = "Test Handoff Task" ]
    [ "$(echo "$output" | jq -r '.metadata.next_steps_count')" = "3" ]

    # Sections should include "Task Summary" and "Next Steps"
    local sections
    sections=$(echo "$output" | jq -r '.metadata.sections[]')
    [[ "$sections" == *"Task Summary"* ]]
    [[ "$sections" == *"Next Steps"* ]]
}

@test "picks most recent from multiple files" {
    mkdir -p "$TEST_TMPDIR/handoffs"

    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-08-100000.md" << 'EOF'
# Older Task

## Task Summary
Old work.

## Next Steps
1. Old step
EOF
    # Make older file actually older by mtime
    touch -t 202604081000 "$TEST_TMPDIR/handoffs/handoff-2026-04-08-100000.md"

    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-09-150000.md" << 'EOF'
# Newer Task

## Task Summary
New work.

## Next Steps
1. New step
EOF
    touch -t 202604091500 "$TEST_TMPDIR/handoffs/handoff-2026-04-09-150000.md"

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "true" ]
    [ "$(echo "$output" | jq -r '.filename')" = "handoff-2026-04-09-150000.md" ]
}

@test "prefixed handoff filename discovered" {
    mkdir -p "$TEST_TMPDIR/handoffs"
    cat > "$TEST_TMPDIR/handoffs/my-task-handoff-2026-04-09-120000.md" << 'EOF'
# My Task

## Task Summary
Some work was done.

## Next Steps
1. Continue
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "true" ]
    [ "$(echo "$output" | jq -r '.filename')" = "my-task-handoff-2026-04-09-120000.md" ]
}

@test "timestamp extracted from filename" {
    mkdir -p "$TEST_TMPDIR/handoffs"
    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-09-153045.md" << 'EOF'
# Timestamp Test

## Task Summary
Testing timestamp extraction.
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "true" ]
    local ts
    ts=$(echo "$output" | jq -r '.metadata.timestamp')
    [ "$ts" != "null" ]
    # Should be formatted as ISO-ish: 2026-04-09T15:30:45
    [[ "$ts" == "2026-04-09T15:30:45" ]]
}

@test "--sort-by filename mode works" {
    mkdir -p "$TEST_TMPDIR/handoffs"

    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-07-090000.md" << 'EOF'
# Task A

## Task Summary
Work A.
EOF

    cat > "$TEST_TMPDIR/handoffs/handoff-2026-04-10-120000.md" << 'EOF'
# Task B

## Task Summary
Work B.
EOF

    run bash "$SCRIPTS_DIR/find-latest-handoff.sh" --directory "$TEST_TMPDIR/handoffs" --sort-by filename
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.found')" = "true" ]
    # Filename sort (reverse) should pick the lexicographically latest
    [ "$(echo "$output" | jq -r '.filename')" = "handoff-2026-04-10-120000.md" ]
}
