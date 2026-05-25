# TEST-003: bypass workstation's global ~/.gitconfig (core.hooksPath GH007 noreply
# regex hook + commit.gpgsign + tag.gpgsign) so tmpdir test repos don't silently
# reject test@*.com commits. Defense-in-depth: no git ops in current tests but
# applied so future additions don't regress. See docs/conventions.md TEST-003.
export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1

setup_test_env() {
    export SCRIPTS_DIR="$BATS_TEST_DIRNAME/../scripts"
    export TEST_TMPDIR="$BATS_TMPDIR/nominal-test-$$"
    mkdir -p "$TEST_TMPDIR"
    cd "$TEST_TMPDIR"
}
teardown_test_env() {
    cd /
    rm -rf "$TEST_TMPDIR"
}
