#!/usr/bin/env bash
# Shared helpers for repo-hygiene bats tests.
# These check scripts discover plugins from marketplace.json and must run from repo root.

setup_test_env() {
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    export REPO_ROOT="$BATS_TEST_DIRNAME/../../.."
    export TEST_TMPDIR="$BATS_TMPDIR/repo-hygiene-test-$$"
    mkdir -p "$TEST_TMPDIR"
    cd "$REPO_ROOT"  # Scripts need to run from repo root
}

teardown_test_env() {
    rm -rf "$TEST_TMPDIR"
}
