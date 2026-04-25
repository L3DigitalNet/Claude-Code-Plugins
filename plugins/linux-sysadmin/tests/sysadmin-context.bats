#!/usr/bin/env bats
# sysadmin-context.bats — SessionStart dispatch contract.
# The script emits a context-injection message when cwd matches a hardcoded
# sysadmin-directory list; otherwise stays silent.
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/sysadmin-context.sh"
}

# Helper: write a {"cwd": "..."} JSON to a tmpfile and pipe it into the script.
# Returns 0 with stdout/stderr captured by bats's run.
run_with_cwd() {
  local cwd="$1"
  local in="$BATS_TEST_TMPDIR/in.json"
  python3 -c "import json,sys; print(json.dumps({'cwd': sys.argv[1]}))" "$cwd" > "$in"
  bash "$SCRIPT" < "$in"
}

@test "cwd exact-match /home/chris → context emitted (SC1)" {
  run --separate-stderr run_with_cwd "/home/chris"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linux-sysadmin"* ]]
}

@test "cwd /home/chris/projects does NOT match (exact-list semantics) (SC2)" {
  run --separate-stderr run_with_cwd "/home/chris/projects"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "cwd in homelab prefix → context emitted (SC3)" {
  run --separate-stderr run_with_cwd "/home/chris/git-luminous3d/homelab/services/foo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linux-sysadmin"* ]]
}

@test "cwd unrelated to any list → silent (SC4)" {
  run --separate-stderr run_with_cwd "/tmp/random"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing cwd in stdin → silent (SC5 robustness)" {
  echo '{}' > "$BATS_TEST_TMPDIR/in.json"
  run --separate-stderr bash -c "bash '$SCRIPT' < '$BATS_TEST_TMPDIR/in.json'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "malformed JSON stdin → silent (SC6 fail-open)" {
  echo 'not json' > "$BATS_TEST_TMPDIR/in.json"
  run --separate-stderr bash -c "bash '$SCRIPT' < '$BATS_TEST_TMPDIR/in.json'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "homelab prefix exact match (no subdir) → context emitted (SC7)" {
  run --separate-stderr run_with_cwd "/home/chris/git-luminous3d/homelab"
  [ "$status" -eq 0 ]
  [[ "$output" == *"linux-sysadmin"* ]]
}
