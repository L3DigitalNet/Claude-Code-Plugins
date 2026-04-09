#!/usr/bin/env bats
load helpers

setup() {
    setup_test_env
    export REAL_HOME="$HOME"
    export HOME="$DOCS_MANAGER_HOME/fakehome"
    mkdir -p "$HOME"
}

teardown() {
    export HOME="$REAL_HOME"
    teardown_test_env
}

@test "without ~/.docs-manager/: config.exists=false" {
    # HOME has no .docs-manager directory
    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.config.exists')" = "false" ]
}

@test "with valid config: config.exists=true, config.valid=true" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
index_path: /tmp/docs-index.json
EOF

    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.config.exists')" = "true" ]
    [ "$(echo "$output" | jq -r '.operational.config.valid')" = "true" ]
}

@test "--test flag: output contains tests array" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
EOF

    run bash "$SCRIPTS_DIR/status-dashboard.sh" --test
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    # tests key should be present and be an array
    [ "$(echo "$output" | jq 'has("tests")')" = "true" ]
    [ "$(echo "$output" | jq '.tests | type')" = '"array"' ]
}

@test "output is valid JSON" {
    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
}

@test "stale lock detected" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
EOF

    # Create a lock file with old mtime (> 300s old)
    touch "$HOME/.docs-manager/index.lock"
    # Set mtime to 10 minutes ago
    touch -d '10 minutes ago' "$HOME/.docs-manager/index.lock"

    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.lock.exists')" = "true" ]
    [ "$(echo "$output" | jq -r '.operational.lock.stale')" = "true" ]
}

@test "fallback file detected" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
EOF

    # Create a fallback queue file
    echo '[]' > "$HOME/.docs-manager/queue.fallback.json"

    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.fallback.exists')" = "true" ]
}

@test "hook timestamps parsed when present" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
EOF

    # Create hook timestamp files
    mkdir -p "$HOME/.docs-manager/hooks"
    echo "2026-04-01T10:30:00" > "$HOME/.docs-manager/hooks/post-tool-use.last-fired"

    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.operational.hooks.post_tool_use.last_fired')" != "null" ]
    [ "$(echo "$output" | jq -r '.operational.hooks.post_tool_use.last_fired')" = "2026-04-01T10:30:00" ]
}

@test "library health with fixture index" {
    mkdir -p "$HOME/.docs-manager"

    local idx_path="$DOCS_MANAGER_HOME/docs-index.json"

    cat > "$HOME/.docs-manager/config.yaml" << EOF
index_type: json
machine_id: testbox
index_path: $idx_path
EOF

    # Create fixture index with 3 documents, 1 missing upstream_url
    cat > "$idx_path" << 'EOF'
{
  "documents": [
    {"title": "Doc A", "upstream_url": "https://example.com/a", "source_files": ["a.md"]},
    {"title": "Doc B", "upstream_url": "https://example.com/b", "source_files": ["b.md"]},
    {"title": "Doc C", "source_files": ["c.md"]}
  ]
}
EOF

    run bash "$SCRIPTS_DIR/status-dashboard.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.library.available')" = "true" ]
    [ "$(echo "$output" | jq '.library.total_documents')" = "3" ]
    [ "$(echo "$output" | jq '.library.missing_upstream_url')" = "1" ]
}

@test "--test flag with failures shows detail" {
    mkdir -p "$HOME/.docs-manager"
    cat > "$HOME/.docs-manager/config.yaml" << 'EOF'
index_type: json
machine_id: testbox
EOF

    # Create a stale lock to trigger a test failure
    touch "$HOME/.docs-manager/index.lock"
    touch -d '10 minutes ago' "$HOME/.docs-manager/index.lock"

    # Create a fallback file to trigger another failure
    echo '[]' > "$HOME/.docs-manager/queue.fallback.json"

    run bash "$SCRIPTS_DIR/status-dashboard.sh" --test
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1

    # Tests array should have entries with pass=false
    local failed_count
    failed_count=$(echo "$output" | jq '[.tests[] | select(.pass == false)] | length')
    [ "$failed_count" -ge 1 ]

    # Specifically, no_stale_lock and no_pending_fallback should fail
    [ "$(echo "$output" | jq -r '[.tests[] | select(.name == "no_stale_lock")] | .[0].pass')" = "false" ]
    [ "$(echo "$output" | jq -r '[.tests[] | select(.name == "no_pending_fallback")] | .[0].pass')" = "false" ]
}
