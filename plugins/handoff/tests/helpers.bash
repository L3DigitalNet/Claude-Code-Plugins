setup_test_env() {
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    export TEST_TMPDIR="$BATS_TMPDIR/handoff-test-$$"
    mkdir -p "$TEST_TMPDIR"
    cd "$TEST_TMPDIR"
}
teardown_test_env() { cd /; rm -rf "$TEST_TMPDIR"; }
