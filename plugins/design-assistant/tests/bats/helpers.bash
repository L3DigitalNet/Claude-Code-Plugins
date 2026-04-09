setup_test_env() {
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../../scripts"
    export TEST_TMPDIR="$BATS_TMPDIR/design-assistant-test-$$"
    mkdir -p "$TEST_TMPDIR"
}
teardown_test_env() {
    rm -rf "$TEST_TMPDIR"
}
