# Shared test helpers — sourced by all .bats test files
# Sets up isolated temp environment so tests never touch ~/.docs-manager/

setup_test_env() {
    export DOCS_MANAGER_HOME="$BATS_TMPDIR/docs-manager-test-$$"
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    mkdir -p "$DOCS_MANAGER_HOME"
}

teardown_test_env() {
    rm -rf "$DOCS_MANAGER_HOME"
}
