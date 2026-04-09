#!/usr/bin/env bash
# Shared helpers for github-repo-manager bats tests.

setup_test_env() {
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    export PLUGIN_ROOT="$BATS_TEST_DIRNAME/.."
    export TEST_TMPDIR="$BATS_TMPDIR/grm-test-$$"
    mkdir -p "$TEST_TMPDIR"
}

teardown_test_env() {
    rm -rf "$TEST_TMPDIR"
}
