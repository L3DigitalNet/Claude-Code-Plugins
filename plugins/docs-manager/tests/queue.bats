#!/usr/bin/env bats

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "bootstrap creates state directory structure" {
    run bash "$SCRIPTS_DIR/bootstrap.sh"
    [ "$status" -eq 0 ]
    [ -d "$DOCS_MANAGER_HOME" ]
    [ -d "$DOCS_MANAGER_HOME/hooks" ]
    [ -d "$DOCS_MANAGER_HOME/cache" ]
}

@test "bootstrap creates queue.json if missing" {
    run bash "$SCRIPTS_DIR/bootstrap.sh"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/queue.json" ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "bootstrap is idempotent — does not overwrite existing queue" {
    mkdir -p "$DOCS_MANAGER_HOME"
    echo '{"created":"2026-01-01T00:00:00Z","items":[{"id":"q-001"}]}' > "$DOCS_MANAGER_HOME/queue.json"
    run bash "$SCRIPTS_DIR/bootstrap.sh"
    [ "$status" -eq 0 ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
}
