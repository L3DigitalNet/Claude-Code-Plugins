#!/usr/bin/env bats

load helpers

setup() {
    setup_test_env
    bash "$SCRIPTS_DIR/bootstrap.sh" > /dev/null
}
teardown() { teardown_test_env; }

# Helper: simulate PostToolUse stdin JSON
post_tool_json() {
    local file_path="$1"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"test"}}\n' "$file_path"
}

@test "post-tool-use: Path A — file with frontmatter queued as doc-modified" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
    run jq -r '.items[0].type' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "doc-modified" ]
}

@test "post-tool-use: extracts library from frontmatter" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq -r '.items[0].library' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "raspi5-homelab" ]
}

@test "post-tool-use: file without frontmatter is ignored" {
    local doc="$DOCS_MANAGER_HOME/plain.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "post-tool-use: non-markdown file is ignored" {
    post_tool_json "/tmp/script.py" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "post-tool-use: writes last-fired timestamp on success" {
    local doc="$DOCS_MANAGER_HOME/testdoc.md"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    [ -f "$DOCS_MANAGER_HOME/hooks/post-tool-use.last-fired" ]
}

@test "post-tool-use: skips node_modules paths" {
    local doc="$DOCS_MANAGER_HOME/node_modules/pkg/README.md"
    mkdir -p "$(dirname "$doc")"
    cp "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" "$doc"
    post_tool_json "$doc" | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

@test "post-tool-use: always exits 0 on invalid JSON" {
    run bash -c 'echo "invalid json" | bash "$SCRIPTS_DIR/post-tool-use.sh"'
    [ "$status" -eq 0 ]
}

@test "post-tool-use: always exits 0 on empty stdin" {
    run bash -c 'echo "" | bash "$SCRIPTS_DIR/post-tool-use.sh"'
    [ "$status" -eq 0 ]
}

# --- Path B Detection Tests ---

@test "post-tool-use: Path B — source-file edit triggers queue item" {
    # Set up index with a doc that references a source file
    local src_file="$DOCS_MANAGER_HOME/Caddyfile"
    echo "# Caddy config" > "$src_file"
    cat > "$DOCS_MANAGER_HOME/docs-index.json" << INDEXEOF
{"version":"1.0","last-updated":"2026-01-01T00:00:00Z","libraries":[],"documents":[
  {"id":"doc-001","path":"/tmp/caddy-readme.md","title":"Caddy","library":"homelab",
   "machine":"test","doc-type":"sysadmin","status":"active","last-verified":null,
   "template":null,"upstream-url":null,"source-files":["$src_file"],
   "cross-refs":[],"incoming-refs":[],"summary":null}
]}
INDEXEOF
    # Edit the source file (not a .md file)
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"updated"}}\n' "$src_file" \
        | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "1" ]
    run jq -r '.items[0].type' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "source-file-changed" ]
}

@test "post-tool-use: Path B — no match produces no queue item" {
    # Empty index
    echo '{"version":"1.0","last-updated":"2026-01-01T00:00:00Z","libraries":[],"documents":[]}' \
        > "$DOCS_MANAGER_HOME/docs-index.json"
    local src_file="$DOCS_MANAGER_HOME/random.conf"
    echo "config" > "$src_file"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"x"}}\n' "$src_file" \
        | bash "$SCRIPTS_DIR/post-tool-use.sh"
    run jq '.items | length' "$DOCS_MANAGER_HOME/queue.json"
    [ "$output" = "0" ]
}

# --- Stop Hook Tests ---

@test "stop: outputs queue summary when items exist" {
    bash "$SCRIPTS_DIR/queue-append.sh" --type "doc-modified" --doc-path "/tmp/a.md" --library "lib" --trigger "direct-write"
    run bash "$SCRIPTS_DIR/stop.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1"* ]]
    [[ "$output" == *"documentation"* ]] || [[ "$output" == *"queued"* ]]
}

@test "stop: silent when queue is empty" {
    run bash "$SCRIPTS_DIR/stop.sh"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "stop: writes last-fired timestamp" {
    run bash "$SCRIPTS_DIR/stop.sh"
    [ "$status" -eq 0 ]
    [ -f "$DOCS_MANAGER_HOME/hooks/stop.last-fired" ]
}

@test "stop: always exits 0" {
    # Even with corrupted queue
    echo "bad json" > "$DOCS_MANAGER_HOME/queue.json"
    run bash "$SCRIPTS_DIR/stop.sh"
    [ "$status" -eq 0 ]
}
