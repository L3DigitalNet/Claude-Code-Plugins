#!/usr/bin/env bats
# post-tool-use.bats — [P2] Detection Automatic, Resolution Deferred.
# Hook silently observes file writes and routes to queue-append.sh.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  SCRIPT="$SCRIPTS_DIR/post-tool-use.sh"
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK"
}
teardown() { teardown_test_env; }

invoke_hook() {
  local fp="$1"
  local in="$BATS_TEST_TMPDIR/in.json"
  python3 -c "
import json,sys
print(json.dumps({'tool_input': {'file_path': sys.argv[1]}}))
" "$fp" > "$in"
  bash "$SCRIPT" < "$in"
}

@test "empty stdin → silent exit 0 (PT1)" {
  run --separate-stderr bash -c "bash '$SCRIPT' < /dev/null"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing file_path in JSON → silent exit 0 (PT2)" {
  echo '{}' > "$BATS_TEST_TMPDIR/in.json"
  run --separate-stderr bash -c "bash '$SCRIPT' < '$BATS_TEST_TMPDIR/in.json'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "node_modules path → ignored (PT3 noise filter)" {
  mkdir -p "$WORK/node_modules/foo"
  echo "x" > "$WORK/node_modules/foo/file.md"
  run --separate-stderr invoke_hook "$WORK/node_modules/foo/file.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test ".git path → ignored (PT4)" {
  mkdir -p "$WORK/.git/hooks"
  echo "x" > "$WORK/.git/hooks/pre-commit"
  run --separate-stderr invoke_hook "$WORK/.git/hooks/pre-commit"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "missing file (deleted) → silent exit 0 (PT5)" {
  run --separate-stderr invoke_hook "$WORK/never-existed.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-md non-tracked file → silent exit 0 (PT6)" {
  echo "code" > "$WORK/code.py"
  run --separate-stderr invoke_hook "$WORK/code.py"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
