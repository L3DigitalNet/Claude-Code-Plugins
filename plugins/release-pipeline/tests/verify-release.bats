#!/usr/bin/env bats
# verify-release.bats — [P3] Succeed Quietly, Fail Transparently (verification report)
# Uses local bare-repo origin + PATH-stubbed gh so all four checks are deterministic.
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/verify-release.sh"
  REPO=$(make_git_repo)
  ORIGIN=$(make_bare_origin "$REPO")
  # make_git_repo initializes 'dev'; verify-release expects current branch != main.
  path_prepend_stubs
}

@test "all checks pass on a tagged + released + dev-branched repo (VR1)" {
  git -C "$REPO" tag v1.0.0
  git -C "$REPO" push origin v1.0.0 >/dev/null 2>&1
  GH_STUB_MODE=release_ok run bash "$SCRIPT" "$REPO" 1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"✓ Tag exists on remote"* ]]
  [[ "$output" == *"✓ GitHub release exists"* ]]
  [[ "$output" == *"✓ Release notes present"* ]]
  [[ "$output" == *"4 passed, 0 failed"* ]]
}

@test "missing remote tag fails the tag check (VR2)" {
  GH_STUB_MODE=release_missing run bash "$SCRIPT" "$REPO" 1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"✗ Tag exists on remote"* ]]
}

@test "missing GitHub release fails its check (VR3)" {
  git -C "$REPO" tag v1.0.0
  git -C "$REPO" push origin v1.0.0 >/dev/null 2>&1
  GH_STUB_MODE=release_missing run bash "$SCRIPT" "$REPO" 1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"✓ Tag exists on remote"* ]]
  [[ "$output" == *"✗ GitHub release exists"* ]]
}

@test "branch == main fails the dev-branch-return check (VR4)" {
  git -C "$REPO" tag v1.0.0
  git -C "$REPO" push origin v1.0.0 >/dev/null 2>&1
  git -C "$REPO" checkout -B main >/dev/null 2>&1
  GH_STUB_MODE=release_ok run bash "$SCRIPT" "$REPO" 1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"on: main"* ]]
}

@test "version with leading 'v' is normalized; no double-v (VR5)" {
  git -C "$REPO" tag v1.0.0
  git -C "$REPO" push origin v1.0.0 >/dev/null 2>&1
  GH_STUB_MODE=release_ok run bash "$SCRIPT" "$REPO" v1.0.0
  [ "$status" -eq 0 ]
  [[ "$output" == *"v1.0.0"* ]]
  [[ "$output" != *"vv1.0.0"* ]]
}

@test "--plugin flag prefixes tag as <plugin>/v<version> (VR6)" {
  git -C "$REPO" tag "myplug/v1.0.0"
  git -C "$REPO" push origin "myplug/v1.0.0" >/dev/null 2>&1
  GH_STUB_MODE=release_ok run bash "$SCRIPT" "$REPO" 1.0.0 --plugin myplug
  [ "$status" -eq 0 ]
  [[ "$output" == *"myplug/v1.0.0"* ]]
}

@test "--plugin name with path separator → exit 1 loudly (VR7 security)" {
  run bash "$SCRIPT" "$REPO" 1.0.0 --plugin "../etc"
  [ "$status" -eq 1 ]
  [[ "$output" == *"path separators"* ]]
}

@test "missing repo dir → exit 1 loudly (VR8)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/missing" 1.0.0
  [ "$status" -eq 1 ]
  [[ "$output" == *"does not exist"* ]]
}
