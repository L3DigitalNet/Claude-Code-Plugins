setup_test_env() {
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    export TEST_TMPDIR="$BATS_TMPDIR/up-docs-test-$$"
    mkdir -p "$TEST_TMPDIR"
    cd "$TEST_TMPDIR"
    # Workstation's global ~/.gitconfig sets core.hooksPath to a GH007 noreply-email
    # regex enforcer that rejects test@test.com commits — silent under `-q`, leaving
    # HEAD unwritten and breaking downstream assertions. Also neutralizes any global
    # commit.gpgsign / tag.gpgsign that would require a key in test envs. Same root
    # cause as plugin-test-harness v0.7.5 (TEST-003) and release-pipeline v2.2.1.
    export GIT_CONFIG_GLOBAL=/dev/null
    export GIT_CONFIG_NOSYSTEM=1
}
teardown_test_env() { cd /; rm -rf "$TEST_TMPDIR"; }
