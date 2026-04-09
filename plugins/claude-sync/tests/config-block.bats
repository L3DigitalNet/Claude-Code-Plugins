#!/usr/bin/env bats
load bats-helpers

setup() {
    setup_test_env
    export REAL_HOME="$HOME"
    export HOME="$TEST_TMPDIR/fakehome"
    mkdir -p "$HOME/.claude"
}

teardown() {
    export HOME="$REAL_HOME"
    teardown_test_env
}

@test "read with no CLAUDE.md returns block_found=false" {
    run bash "$SCRIPTS_DIR/config-block.sh" read
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.block_found')" = "false" ]
}

@test "read with valid config block returns parsed JSON with all fields" {
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
# My Config

<!-- claude-sync-config
sync_path: /mnt/share/sync
repos_root: /home/user/projects
machine_id: testbox
exclude:
  - .credentials.json
  - statsig/
-->

Other stuff here.
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" read
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.block_found')" = "true" ]
    [ "$(echo "$output" | jq -r '.sync_path')" = "/mnt/share/sync" ]
    [ "$(echo "$output" | jq -r '.repos_root')" = "/home/user/projects" ]
    [ "$(echo "$output" | jq -r '.machine_id')" = "testbox" ]
    [ "$(echo "$output" | jq '.exclude | length')" = "2" ]
}

@test "write creates config block" {
    run bash -c 'echo "{\"sync_path\":\"/mnt/share\",\"repos_root\":\"/home/user/projects\",\"machine_id\":\"box1\"}" | bash "$SCRIPTS_DIR/config-block.sh" write'
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.block_found')" = "true" ]

    # Verify file was actually written
    [ -f "$HOME/.claude/CLAUDE.md" ]
    grep -q "claude-sync-config" "$HOME/.claude/CLAUDE.md"
}

@test "update changes a single key" {
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
<!-- claude-sync-config
sync_path: /old/path
machine_id: box1
-->
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" update sync_path /new/path
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.sync_path')" = "/new/path" ]
    # machine_id should be preserved
    [ "$(echo "$output" | jq -r '.machine_id')" = "box1" ]
}

@test "add-exclude appends to exclude list" {
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
<!-- claude-sync-config
sync_path: /mnt/share
exclude:
  - .credentials.json
-->
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" add-exclude "statsig/"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.exclude | length')" = "2" ]
    [[ "$(echo "$output" | jq -r '.exclude[1]')" == "statsig/" ]]
}

@test "remove-exclude removes from exclude list" {
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
<!-- claude-sync-config
sync_path: /mnt/share
exclude:
  - .credentials.json
  - statsig/
-->
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" remove-exclude "statsig/"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.exclude | length')" = "1" ]
    [ "$(echo "$output" | jq -r '.exclude[0]')" = ".credentials.json" ]
}

@test "validate with missing required fields returns valid=false" {
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
<!-- claude-sync-config
sync_path: /mnt/share
-->
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" validate
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.valid')" = "false" ]
    # Should mention missing repos_root and machine_id
    local issues
    issues=$(echo "$output" | jq -r '.issues[]')
    [[ "$issues" == *"repos_root"* ]]
    [[ "$issues" == *"machine_id"* ]]
}

@test "validate with valid config returns valid=true" {
    # Create dirs that the validator checks for existence
    mkdir -p "$TEST_TMPDIR/sync-path"
    mkdir -p "$TEST_TMPDIR/repos-root"

    cat > "$HOME/.claude/CLAUDE.md" << EOF
<!-- claude-sync-config
sync_path: $TEST_TMPDIR/sync-path
repos_root: $TEST_TMPDIR/repos-root
machine_id: testbox
-->
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" validate
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.valid')" = "true" ]
    [ "$(echo "$output" | jq '.issues | length')" = "0" ]
}

@test "write replaces existing config block" {
    # Write an initial config
    run bash -c 'echo "{\"sync_path\":\"/first/path\",\"repos_root\":\"/home/user/projects\",\"machine_id\":\"box1\"}" | bash "$SCRIPTS_DIR/config-block.sh" write'
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.sync_path')" = "/first/path" ]

    # Overwrite with a different config
    run bash -c 'echo "{\"sync_path\":\"/second/path\",\"repos_root\":\"/home/other/projects\",\"machine_id\":\"box2\"}" | bash "$SCRIPTS_DIR/config-block.sh" write'
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.sync_path')" = "/second/path" ]

    # Read back and verify the second write replaced the first
    run bash "$SCRIPTS_DIR/config-block.sh" read
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.block_found')" = "true" ]
    [ "$(echo "$output" | jq -r '.sync_path')" = "/second/path" ]
    [ "$(echo "$output" | jq -r '.repos_root')" = "/home/other/projects" ]
    [ "$(echo "$output" | jq -r '.machine_id')" = "box2" ]

    # Verify only one config block exists (not two)
    local count
    count=$(grep -c "claude-sync-config" "$HOME/.claude/CLAUDE.md")
    [ "$count" -eq 1 ]
}

@test "invalid subcommand exits 1" {
    run bash "$SCRIPTS_DIR/config-block.sh" badcmd
    [ "$status" -eq 1 ]
}

@test "validate with missing required field returns valid=false" {
    # Config block with sync_path and repos_root but no machine_id
    mkdir -p "$TEST_TMPDIR/sync-path"
    mkdir -p "$TEST_TMPDIR/repos-root"

    cat > "$HOME/.claude/CLAUDE.md" << EOF
<!-- claude-sync-config
sync_path: $TEST_TMPDIR/sync-path
repos_root: $TEST_TMPDIR/repos-root
-->
EOF

    run bash "$SCRIPTS_DIR/config-block.sh" validate
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.valid')" = "false" ]
    local issues
    issues=$(echo "$output" | jq -r '.issues[]')
    [[ "$issues" == *"machine_id"* ]]
}
