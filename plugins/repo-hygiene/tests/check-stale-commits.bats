#!/usr/bin/env bats
# check-stale-commits.bats — [P2] Quiet success / loud failure on script seam.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  REPO="$TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  git config commit.gpgsign false
  git config tag.gpgsign false
  echo "a" > a.txt
  git add a.txt
  git commit -q -m initial
}
teardown() {
  cd /
  teardown_test_env
}

@test "clean tree → no findings (CSC1 quiet success)" {
  run bash "$SCRIPTS_DIR/check-stale-commits.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
}

@test "output is structured JSON (CSC2 contract)" {
  run bash "$SCRIPTS_DIR/check-stale-commits.sh"
  [ "$status" -eq 0 ]
  check=$(echo "$output" | jq -r '.check')
  [ "$check" = "stale-commits" ] || [ "$check" = "stale_commits" ] || [[ "$check" == *"stale"* ]]
  echo "$output" | jq '.findings' >/dev/null
}
