#!/usr/bin/env bats

load helpers

setup() {
    setup_test_env
    bash "$SCRIPTS_DIR/bootstrap.sh" > /dev/null
    # Create a minimal config pointing index to test env
    cat > "$DOCS_MANAGER_HOME/config.yaml" << EOF
machine: testhost
index:
  type: json
  location: $DOCS_MANAGER_HOME
EOF
}
teardown() { teardown_test_env; }

# --- Index Register Tests ---

@test "index-register creates new index if none exists" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    run bash "$SCRIPTS_DIR/index-register.sh" --path "$doc"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/docs-index.json" ]
    run jq '.documents | length' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "1" ]
}

@test "index-register populates fields from frontmatter" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    bash "$SCRIPTS_DIR/index-register.sh" --path "$doc"
    run jq -r '.documents[0].library' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "raspi5-homelab" ]
    run jq -r '.documents[0]["doc-type"]' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "sysadmin" ]
}

@test "index-register generates sequential doc IDs" {
    local doc1="$DOCS_MANAGER_HOME/doc1.md"
    local doc2="$DOCS_MANAGER_HOME/doc2.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc1"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc2"
    bash "$SCRIPTS_DIR/index-register.sh" --path "$doc1"
    bash "$SCRIPTS_DIR/index-register.sh" --path "$doc2"
    run jq -r '.documents[1].id' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "doc-002" ]
}

@test "index-register rejects duplicate path" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    bash "$SCRIPTS_DIR/index-register.sh" --path "$doc"
    run bash "$SCRIPTS_DIR/index-register.sh" --path "$doc"
    [ "$status" -eq 0 ]
    # Should still have only 1 document
    run jq '.documents | length' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "1" ]
}

@test "index-register creates library entry if new" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    bash "$SCRIPTS_DIR/index-register.sh" --path "$doc"
    run jq '.libraries | length' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "1" ]
    run jq -r '.libraries[0].name' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "raspi5-homelab" ]
}

@test "index-register accepts --library override" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    bash "$SCRIPTS_DIR/index-register.sh" --path "$doc" --library "custom-lib"
    run jq -r '.documents[0].library' "$DOCS_MANAGER_HOME/docs-index.json"
    [ "$output" = "custom-lib" ]
}

# --- Index Query Tests ---

@test "index-query returns matching docs by library" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-query.sh" --library "raspi5-homelab"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" = "1" ]
}

@test "index-query --source-file finds associated docs" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-query.sh" --source-file "/etc/caddy/Caddyfile"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" = "1" ]
}

@test "index-query --source-file returns empty for no match" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-query.sh" --source-file "/etc/nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}

@test "index-query --path returns exact match" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-query.sh" --path "~/projects/homelab/raspi5/caddy/README.md"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" = "1" ]
}

@test "index-query --search finds by title" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-query.sh" --search "Caddy"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" = "1" ]
}

# --- Index Rebuild-MD Tests ---

@test "index-rebuild-md generates markdown from index" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-rebuild-md.sh"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/docs-index.md" ]
    run bash -c "grep -c 'Caddy' '$DOCS_MANAGER_HOME/docs-index.md'"
    [ "$output" -ge 1 ]
}

# --- Index Lock Tests ---

@test "index-lock acquires lock successfully" {
    run bash "$SCRIPTS_DIR/index-lock.sh" --operation "test"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/index.lock" ]
    # Cleanup
    bash "$SCRIPTS_DIR/index-unlock.sh"
}

@test "index-unlock removes lock file" {
    bash "$SCRIPTS_DIR/index-lock.sh" --operation "test"
    run bash "$SCRIPTS_DIR/index-unlock.sh"
    [ "$status" -eq 0 ]
    [ ! -f "$DOCS_MANAGER_HOME/index.lock" ]
}

@test "index-lock cleans stale lock from dead PID" {
    # Write a lock with a PID that doesn't exist
    printf '{"pid":99999,"acquired":"2026-01-01T00:00:00Z","operation":"stale"}' \
        > "$DOCS_MANAGER_HOME/index.lock"
    run bash "$SCRIPTS_DIR/index-lock.sh" --operation "test"
    [ "$status" -eq 0 ]
    # Cleanup
    bash "$SCRIPTS_DIR/index-unlock.sh"
}

# --- Source Lookup Tests ---

@test "index-source-lookup finds docs by source-file" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-source-lookup.sh" "/etc/caddy/Caddyfile"
    [ "$status" -eq 0 ]
    local count
    count=$(echo "$output" | jq 'length')
    [ "$count" = "1" ]
}

@test "index-source-lookup returns empty array for no match" {
    cp "$BATS_TEST_DIRNAME/fixtures/sample-index.json" "$DOCS_MANAGER_HOME/docs-index.json"
    run bash "$SCRIPTS_DIR/index-source-lookup.sh" "/etc/nonexistent"
    [ "$status" -eq 0 ]
    [ "$output" = "[]" ]
}
