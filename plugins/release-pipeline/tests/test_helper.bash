#!/usr/bin/env bash
# Shared bats helpers for release-pipeline tests.
#
# Loaded via `load test_helper` from each .bats file.
# Provides: PLUGIN_ROOT, REPO_ROOT, STUBS_DIR + setup_tmp_home, make_git_repo,
# make_bare_origin, path_prepend_stubs.

PLUGIN_ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)}"
REPO_ROOT="$(cd "$PLUGIN_ROOT/../.." && pwd)"
STUBS_DIR="$PLUGIN_ROOT/tests/fixtures/stubs"

# Redirect HOME into the per-test bats tmpdir + scaffold .claude.
setup_tmp_home() {
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME/.claude/plugins"
}

# Initialize a fresh git repo with one commit; echo absolute path on stdout.
make_git_repo() {
  local dir="$BATS_TEST_TMPDIR/repo-$$-$RANDOM"
  git init "$dir" >/dev/null 2>&1
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  git -C "$dir" config commit.gpgsign false
  # Workstation's global pre-commit hook enforces an author-email regex (GH007 noreply
  # filter) and rejects test@example.com — silent failure under `>/dev/null 2>&1` leaves
  # HEAD unwritten, breaking every downstream `git tag` call. Same fix as
  # plugin-test-harness v0.7.5 (TEST-003 / bug 005).
  git -C "$dir" config core.hooksPath /dev/null
  # User's global config sets tag.gpgsign=true, which makes `git tag <name>` create
  # a signed annotated tag and fail without a message. Force lightweight-tag default
  # in test repos so `git tag v1.0.0` works as a plain ref creation.
  git -C "$dir" config tag.gpgsign false
  git -C "$dir" config tag.forceSignAnnotated false
  git -C "$dir" checkout -B dev >/dev/null 2>&1 || git -C "$dir" branch -m dev 2>/dev/null || true
  echo "initial" > "$dir/file.txt"
  git -C "$dir" add . >/dev/null
  git -C "$dir" commit -m "initial" >/dev/null 2>&1
  echo "$dir"
}

# Add a bare-repo origin to a working repo and push the current branch.
# Echoes the bare-repo absolute path on stdout.
make_bare_origin() {
  local working="$1"
  local bare="$BATS_TEST_TMPDIR/origin-$$-$RANDOM.git"
  git init --bare "$bare" >/dev/null 2>&1
  git -C "$working" remote add origin "$bare" 2>/dev/null \
    || git -C "$working" remote set-url origin "$bare"
  git -C "$working" push origin HEAD >/dev/null 2>&1 || true
  echo "$bare"
}

# Prepend the stubs dir to PATH so fake binaries take precedence over real ones.
path_prepend_stubs() {
  export PATH="$STUBS_DIR:$PATH"
}
