#!/usr/bin/env bats
load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "outputs valid JSON with working_directory, hostname, timestamp, filename" {
    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.working_directory')" != "null" ]
    [ "$(echo "$output" | jq -r '.hostname')" != "null" ]
    [ "$(echo "$output" | jq -r '.timestamp')" != "null" ]
    [ "$(echo "$output" | jq -r '.filename')" != "null" ]
}

@test "--description generates slugified filename" {
    run bash "$SCRIPTS_DIR/gather-context.sh" --description "My Cool Task"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    local filename
    filename=$(echo "$output" | jq -r '.filename')
    # Slug should be lowercase, hyphen-separated, with handoff- in it
    [[ "$filename" == my-cool-task-handoff-* ]]
}

@test "in git repo: git.is_repo=true, branch present" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "hello" > file.txt
    git add file.txt
    git commit -q -m "initial"

    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.git.is_repo')" = "true" ]
    [ "$(echo "$output" | jq -r '.git.branch')" = "main" ]
}

@test "filename contains date pattern" {
    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    local filename
    filename=$(echo "$output" | jq -r '.filename')
    # Should match handoff-YYYY-MM-DD-HHMMSS.md
    [[ "$filename" =~ handoff-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\.md ]]
}

@test "non-git directory returns is_repo false" {
    local nogit="$TEST_TMPDIR/no-git-dir"
    mkdir -p "$nogit"
    cd "$nogit"

    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.git.is_repo')" = "false" ]
}

@test "special characters in description are slugified" {
    run bash "$SCRIPTS_DIR/gather-context.sh" --description "foo@bar#baz!"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    local filename
    filename=$(echo "$output" | jq -r '.filename')
    [[ "$filename" == foo-bar-baz-handoff-* ]]
}

@test "dirty git repo shows uncommitted files" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "hello" > committed.txt
    git add committed.txt
    git commit -q -m "initial"

    # Create an uncommitted file
    echo "dirty" > uncommitted.txt

    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.git.status')" = "dirty" ]
    local uf_len
    uf_len=$(echo "$output" | jq '.git.uncommitted_files | length')
    [ "$uf_len" -ge 1 ]
}

@test "recent_commits have hash and subject" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "hello" > file.txt
    git add file.txt
    git commit -q -m "initial commit"

    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.git.recent_commits[0].hash')" != "null" ]
    [ "$(echo "$output" | jq -r '.git.recent_commits[0].subject')" != "null" ]
    # hash should be a short sha
    [[ "$(echo "$output" | jq -r '.git.recent_commits[0].hash')" =~ ^[0-9a-f]{7,} ]]
}

@test "no upstream sets ahead/behind to null" {
    local repo="$TEST_TMPDIR/local-only-repo"
    mkdir -p "$repo"
    cd "$repo"
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "hello" > file.txt
    git add file.txt
    git commit -q -m "initial"

    # No remote set, so no upstream tracking
    run bash "$SCRIPTS_DIR/gather-context.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq '.git.ahead')" = "null" ]
    [ "$(echo "$output" | jq '.git.behind')" = "null" ]
}
