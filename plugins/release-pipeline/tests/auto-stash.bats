#!/usr/bin/env bats
# auto-stash.bats — [P3] Succeed Quietly, Fail Transparently
# Quiet on no-op (CLEAN), structured on action (STASHED/RESTORED), loud on error.
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/auto-stash.sh"
  REPO=$(make_git_repo)
}

@test "check on clean repo prints CLEAN (AS1)" {
  run bash "$SCRIPT" "$REPO" check
  [ "$status" -eq 0 ]
  [ "$output" = "CLEAN" ]
}

@test "stash on clean repo is a no-op printing CLEAN (AS2)" {
  run bash "$SCRIPT" "$REPO" stash
  [ "$status" -eq 0 ]
  [ "$output" = "CLEAN" ]
}

@test "check on dirty repo prints DIRTY (AS3)" {
  echo "dirty" >> "$REPO/file.txt"
  run bash "$SCRIPT" "$REPO" check
  [ "$status" -eq 0 ]
  [ "$output" = "DIRTY" ]
}

@test "stash on dirty repo creates marker stash; check then prints CLEAN (AS4)" {
  echo "dirty" >> "$REPO/file.txt"
  run bash "$SCRIPT" "$REPO" stash
  [ "$status" -eq 0 ]
  [[ "$output" == *"STASHED"* ]]
  [ "$(git -C "$REPO" stash list | wc -l)" -eq 1 ]
  run bash "$SCRIPT" "$REPO" check
  [ "$output" = "CLEAN" ]
}

@test "pop restores previously-stashed changes (AS5)" {
  echo "dirty" >> "$REPO/file.txt"
  bash "$SCRIPT" "$REPO" stash >/dev/null
  run bash "$SCRIPT" "$REPO" pop
  [ "$status" -eq 0 ]
  [[ "$output" == *"RESTORED"* ]]
  run bash "$SCRIPT" "$REPO" check
  [ "$output" = "DIRTY" ]
}

@test "pop without our stash returns NO_STASH (AS6)" {
  run bash "$SCRIPT" "$REPO" pop
  [ "$status" -eq 0 ]
  [[ "$output" == *"NO_STASH"* ]]
}

@test "pop refuses to touch a non-marker user stash (AS7 safety)" {
  echo "user-change" >> "$REPO/file.txt"
  git -C "$REPO" stash push -m "user pre-existing stash" >/dev/null
  run bash "$SCRIPT" "$REPO" pop
  [ "$status" -eq 0 ]
  [[ "$output" == *"NO_STASH"* ]]
  # User's stash must still be on the stack untouched.
  [ "$(git -C "$REPO" stash list | wc -l)" -eq 1 ]
}

@test "missing repo dir → exit 1 loudly (AS8)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/missing" check
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "unknown subcommand → exit 1 loudly (AS9)" {
  run bash "$SCRIPT" "$REPO" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown command"* ]]
}

@test "missing args → usage error (AS10)" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
