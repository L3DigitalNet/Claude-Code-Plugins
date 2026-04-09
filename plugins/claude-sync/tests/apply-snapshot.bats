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

@test "nonexistent snapshot dir: returns empty actions" {
    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$TEST_TMPDIR/no-such-snapshot" settings
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.actions | length')" = "0" ]
}

@test "--dry-run mode: reports actions but doesn't write" {
    # Set up a snapshot with a settings file
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude"
    echo '{"test": true}' > "$snap/claude/settings.json"
    # Make snapshot file newer than local
    touch -t 203001010000 "$snap/claude/settings.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" settings --dry-run
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.dry_run')" = "true" ]

    # The action should be reported (created or updated)
    local action_count
    action_count=$(echo "$output" | jq '.actions | length')
    [ "$action_count" -ge 1 ]

    # But the file should NOT exist at destination (since no pre-existing file)
    [ ! -f "$HOME/.claude/settings.json" ]
}

@test "settings category: copies files from snapshot to target" {
    # Set up local file (older)
    echo '{"old": true}' > "$HOME/.claude/settings.json"
    touch -t 202001010000 "$HOME/.claude/settings.json"

    # Set up snapshot with newer file
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude"
    echo '{"new": true}' > "$snap/claude/settings.json"
    touch -t 203001010000 "$snap/claude/settings.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" settings
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.category')" = "settings" ]

    # File should have been updated
    local content
    content=$(cat "$HOME/.claude/settings.json")
    [[ "$content" == *'"new"'* ]]

    # Summary should show updated count
    [ "$(echo "$output" | jq '.summary.updated')" -ge 1 ]
}

@test "plugins category merges installed_plugins.json" {
    # Set up local installed_plugins.json with plugin-a
    mkdir -p "$HOME/.claude/plugins"
    echo '{"plugin-a": ["marketplace-1"]}' > "$HOME/.claude/plugins/installed_plugins.json"

    # Set up snapshot with plugin-b
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/plugins"
    echo '{"plugin-b": ["marketplace-2"]}' > "$snap/plugins/installed_plugins.json"
    # Make snapshot file newer
    touch -t 203001010000 "$snap/plugins/installed_plugins.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" plugins
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    # Should report a merge action
    [ "$(echo "$output" | jq -r '.actions[] | select(.action=="merged") | .action')" = "merged" ]

    # The merged file should contain both plugins
    local merged
    merged=$(cat "$HOME/.claude/plugins/installed_plugins.json")
    [ "$(echo "$merged" | jq 'has("plugin-a")')" = "true" ]
    [ "$(echo "$merged" | jq 'has("plugin-b")')" = "true" ]
}

@test "claude-md category preserves local config block" {
    # Set up local CLAUDE.md with a config block
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
# My Local Config

Some local content.

<!-- claude-sync-config
sync_path: /mnt/share/sync
repos_root: /home/user/projects
machine_id: localbox
-->
EOF

    # Set up snapshot CLAUDE.md without a config block
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude-md"
    cat > "$snap/claude-md/CLAUDE.md" << 'EOF'
# Snapshot Config

New content from snapshot.
EOF

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" claude-md
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    # The local config block should be preserved in the result
    grep -q "claude-sync-config" "$HOME/.claude/CLAUDE.md"
    grep -q "machine_id: localbox" "$HOME/.claude/CLAUDE.md"
    # The snapshot content should also be present
    grep -q "New content from snapshot" "$HOME/.claude/CLAUDE.md"
}

@test "unknown category exits 1" {
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" badcategory
    [ "$status" -eq 1 ]
}

@test "update creates backup file" {
    # Set up local file (older)
    mkdir -p "$HOME/.claude"
    echo '{"old": true}' > "$HOME/.claude/settings.json"
    touch -t 202001010000 "$HOME/.claude/settings.json"

    # Set up snapshot with newer file
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude"
    echo '{"new": true}' > "$snap/claude/settings.json"
    touch -t 203001010000 "$snap/claude/settings.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" settings
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    # A .bak file should have been created
    local bak_count
    bak_count=$(find "$HOME/.claude" -name "settings.json.bak.*" | wc -l)
    [ "$bak_count" -ge 1 ]
}

@test "local newer file is skipped" {
    # Set up local file that is NEWER than the snapshot
    mkdir -p "$HOME/.claude"
    echo '{"local": true}' > "$HOME/.claude/settings.json"
    touch -t 203512310000 "$HOME/.claude/settings.json"

    # Set up snapshot with older file
    local snap="$TEST_TMPDIR/snapshot"
    mkdir -p "$snap/claude"
    echo '{"snapshot": true}' > "$snap/claude/settings.json"
    touch -t 202001010000 "$snap/claude/settings.json"

    run bash "$SCRIPTS_DIR/apply-snapshot.sh" "$snap" settings
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    # Action should be skipped with reason "local newer"
    [ "$(echo "$output" | jq -r '.actions[0].action')" = "skipped" ]
    [[ "$(echo "$output" | jq -r '.actions[0].reason')" == *"local newer"* ]]

    # Local file should be unchanged
    [[ "$(cat "$HOME/.claude/settings.json")" == *'"local"'* ]]
}
