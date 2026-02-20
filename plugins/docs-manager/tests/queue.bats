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

# --- Queue Append Tests ---

@test "queue-append adds item to empty queue" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    run bash "$SCRIPTS_DIR/queue-append.sh" \
        --type "doc-modified" \
        --doc-path "/tmp/test.md" \
        --library "test-lib" \
        --trigger "direct-write"
    [ "$status" -eq 0 ]
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
    run jq -r '.items[0].type' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "doc-modified" ]
}

@test "queue-append generates sequential IDs" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/b.md" --library "lib" --trigger "direct-write"
    run jq -r '.items[1].id' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "q-002" ]
}

@test "queue-append deduplicates same doc-path + type" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
}

@test "queue-append includes source-file when provided" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    run bash "$SCRIPTS_DIR/queue-append.sh" \
        --type "source-file-changed" \
        --doc-path "/tmp/readme.md" \
        --library "lib" \
        --trigger "source-file-association" \
        --source-file "/etc/caddy/Caddyfile"
    [ "$status" -eq 0 ]
    run jq -r '.items[0]["source-file"]' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "/etc/caddy/Caddyfile" ]
}

@test "queue-append writes to fallback on main queue parse failure" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    # Corrupt queue.json so jq can't parse it for the append step
    echo "not valid json" > "$DOCS_MANAGER_HOME/queue.json"
    run bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/queue.fallback.json" ]
}

@test "queue-append always exits 0 even on error" {
    export DOCS_MANAGER_HOME="$BATS_TMPDIR/nonexistent-$$"
    run bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    [ "$status" -eq 0 ]
}

# --- Queue Read Tests ---

@test "queue-read outputs empty message for empty queue" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    run bash "$SCRIPTS_DIR/queue-read.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"empty"* ]] || [[ "$output" == *"0 items"* ]]
}

@test "queue-read outputs item count and details" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-read.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"* ]]
    [[ "$output" == *"/tmp/a.md"* ]]
}

@test "queue-read --json outputs valid JSON" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-read.sh" --json
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null 2>&1
}

@test "queue-read --count outputs integer count" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/b.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-read.sh" --count
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "queue-read merges fallback queue before reading" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    printf '{"created":"2026-01-01T00:00:00Z","items":[{"id":"fb-001","type":"doc-modified","doc-path":"/tmp/fb.md","library":"lib","detected-at":"2026-01-01T00:00:00Z","trigger":"direct-write","priority":"standard","status":"pending","note":null}]}\n' \
        > "$DOCS_MANAGER_HOME/queue.fallback.json"
    run bash "$SCRIPTS_DIR/queue-read.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/tmp/fb.md"* ]]
    [ ! -f "$DOCS_MANAGER_HOME/queue.fallback.json" ]
}

@test "queue-read --status filters by status" {
    bash "$SCRIPTS_DIR/bootstrap.sh"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    # Manually set one item to deferred
    jq '.items[0].status = "deferred"' "$DOCS_MANAGER_HOME/queue.json" > "$DOCS_MANAGER_HOME/queue.json.tmp" \
        && mv "$DOCS_MANAGER_HOME/queue.json.tmp" "$DOCS_MANAGER_HOME/queue.json"
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/b.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/queue-read.sh" --count --status pending
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}
