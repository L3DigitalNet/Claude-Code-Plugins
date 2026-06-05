#!/usr/bin/env bash
# Shared helpers for repo-hygiene bats tests.
# These check scripts discover plugins from marketplace.json and must run from repo root.

# TEST-003: bypass workstation's global ~/.gitconfig (core.hooksPath GH007 noreply
# regex hook + commit.gpgsign + tag.gpgsign) so tmpdir test repos don't silently
# reject test@*.com commits. See docs/handoff/conventions.md TEST-003 + docs/handoff/bugs/005-*.md.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

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
