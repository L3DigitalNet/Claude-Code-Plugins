#!/usr/bin/env bats

load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

# --- Frontmatter Reader Tests ---

@test "frontmatter-read extracts specific field" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" library
    [ "$status" -eq 0 ]
    [ "$output" = "raspi5-homelab" ]
}

@test "frontmatter-read outputs all fields as JSON" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md"
    [ "$status" -eq 0 ]
    echo "$output" | jq . > /dev/null 2>&1
    local lib
    lib=$(echo "$output" | jq -r '.library')
    [ "$lib" = "raspi5-homelab" ]
}

@test "frontmatter-read returns exit 1 for file without frontmatter" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md" library
    [ "$status" -eq 1 ]
}

@test "frontmatter-read extracts source-files as JSON array" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" source-files
    [ "$status" -eq 0 ]
    [[ "$output" == *"/etc/caddy/Caddyfile"* ]]
}

@test "frontmatter-read handles --has-frontmatter check" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-with-frontmatter.md" --has-frontmatter
    [ "$status" -eq 0 ]
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "$BATS_TEST_DIRNAME/fixtures/doc-without-frontmatter.md" --has-frontmatter
    [ "$status" -eq 1 ]
}

@test "frontmatter-read returns exit 1 for nonexistent file" {
    run bash "$SCRIPTS_DIR/frontmatter-read.sh" "/tmp/nonexistent-file-$$.md" library
    [ "$status" -eq 1 ]
}
