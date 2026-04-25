#!/usr/bin/env bats
# reconcile-tags.bats — [P5] Convergence is the Contract (tag idempotency)
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/reconcile-tags.sh"
  REPO=$(make_git_repo)
  ORIGIN=$(make_bare_origin "$REPO")
}

@test "tag absent on local and remote → MISSING (RT1)" {
  run bash "$SCRIPT" "$REPO" v1.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "MISSING" ]
}

@test "tag local only → LOCAL_ONLY (RT2)" {
  git -C "$REPO" tag v1.0.0
  run bash "$SCRIPT" "$REPO" v1.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "LOCAL_ONLY" ]
}

@test "tag on both with same SHA → BOTH (idempotent re-run) (RT3)" {
  git -C "$REPO" tag v1.0.0
  git -C "$REPO" push origin v1.0.0 >/dev/null 2>&1
  run bash "$SCRIPT" "$REPO" v1.0.0
  [ "$status" -eq 0 ]
  [ "$output" = "BOTH" ]
}

@test "tag remote only → fetched, REMOTE_ONLY reported, now exists locally (RT4)" {
  # Push then delete locally to simulate remote-only state.
  git -C "$REPO" tag v1.0.0
  git -C "$REPO" push origin v1.0.0 >/dev/null 2>&1
  git -C "$REPO" tag -d v1.0.0 >/dev/null
  run bash "$SCRIPT" "$REPO" v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"REMOTE_ONLY"* ]]
  # Auto-fetch must have brought the tag back locally.
  git -C "$REPO" tag -l v1.0.0 | grep -qF v1.0.0
}

@test "missing repo dir → exit 1 loudly (RT5)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/missing" v1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "tag name with metacharacters does not corrupt match (RT6 fixed-string)" {
  # Verifies the script's grep -F usage (no regex injection from dots/dashes).
  git -C "$REPO" tag "v1.0-rc.1"
  run bash "$SCRIPT" "$REPO" "v1.0-rc.1"
  [ "$status" -eq 0 ]
  [ "$output" = "LOCAL_ONLY" ]
}

@test "missing args → usage error (RT7)" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
