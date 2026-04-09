#!/usr/bin/env bats
load helpers

setup() { setup_test_env; }
teardown() { teardown_test_env; }

@test "in a git repo: outputs valid JSON with is_git_repo=true and branch present" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "hello" > file.txt
    git add file.txt
    git commit -q -m "initial"

    run bash "$SCRIPTS_DIR/context-gather.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.is_git_repo')" = "true" ]
    [ "$(echo "$output" | jq -r '.branch')" = "main" ]
}

@test "outside git repo: returns is_git_repo=false" {
    # TEST_TMPDIR is not a git repo
    run bash "$SCRIPTS_DIR/context-gather.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    [ "$(echo "$output" | jq -r '.is_git_repo')" = "false" ]
}

@test "diff_stat has insertions and deletions fields" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "line1" > file.txt
    git add file.txt
    git commit -q -m "initial"
    echo "line2" >> file.txt
    git add file.txt
    git commit -q -m "add line"

    run bash "$SCRIPTS_DIR/context-gather.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    local ins dels
    ins=$(echo "$output" | jq '.diff_stat.insertions')
    dels=$(echo "$output" | jq '.diff_stat.deletions')
    # Both must be numbers >= 0
    [ "$ins" -ge 0 ]
    [ "$dels" -ge 0 ]
}

@test "commits have files_changed count" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    echo "a" > a.txt
    echo "b" > b.txt
    git add a.txt b.txt
    git commit -q -m "initial with two files"

    run bash "$SCRIPTS_DIR/context-gather.sh"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    local fc
    fc=$(echo "$output" | jq '.last_n_commits[0].files_changed')
    # files_changed must be a number (not null)
    [ "$fc" != "null" ]
    [ "$fc" -ge 1 ]
}

@test "--depth flag limits commit count" {
    git init -q -b main
    git config user.email "test@test.com"
    git config user.name "Test"
    for i in 1 2 3 4 5; do
        echo "change $i" > "file$i.txt"
        git add "file$i.txt"
        git commit -q -m "commit $i"
    done

    run bash "$SCRIPTS_DIR/context-gather.sh" --depth 2
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null 2>&1
    local count
    count=$(echo "$output" | jq '.last_n_commits | length')
    [ "$count" -le 2 ]
}
