#!/usr/bin/env bats
# force-push-guard.bats — [P5] Convergence is the Contract (branch-protection guard)
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/force-push-guard.sh"
}

# Helper: run the hook with stdin JSON via tmpfile to avoid shell-quoting hazards.
invoke_with() {
  local cmd="$1"
  local in="$BATS_TEST_TMPDIR/in.json"
  python3 -c "import json,sys; print(json.dumps({'tool_input':{'command':sys.argv[1]}}))" "$cmd" > "$in"
  bash "$SCRIPT" < "$in"
}

@test "git push without --force is allowed (FP1)" {
  run invoke_with "git push origin main"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git push --force is blocked with branch-protection reason (FP2)" {
  run invoke_with "git push --force origin main"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Force-push is not allowed"* ]]
  [[ "$output" == *'"decision":"block"'* ]]
}

@test "git push -f is blocked (FP3)" {
  run invoke_with "git push -f origin main"
  [ "$status" -eq 2 ]
  [[ "$output" == *"Force-push is not allowed"* ]]
}

@test "non-push --force command (rm --force) is not blocked (FP4)" {
  run invoke_with "rm --force /tmp/foo"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "git push -fd does not match -f boundary (FP5 false-positive guard)" {
  # Script's regex \s-f(\s|$) requires whitespace boundary, so -fd should not match.
  run invoke_with "git push -fd origin main"
  [ "$status" -eq 0 ]
}

@test "missing/unparseable input fails open (FP6)" {
  echo '{}' > "$BATS_TEST_TMPDIR/empty.json"
  run bash -c "bash '$SCRIPT' < '$BATS_TEST_TMPDIR/empty.json'"
  [ "$status" -eq 0 ]
}

@test "git push --force-with-lease still blocked (literal --force prefix match) (FP7)" {
  # Script greps for '--force' as a substring; --force-with-lease contains --force.
  # Documenting current behavior even though a real --force-with-lease is safer than --force.
  run invoke_with "git push --force-with-lease origin main"
  [ "$status" -eq 2 ]
}
