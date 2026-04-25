#!/usr/bin/env bats
# gh-manager-guard.bats — PreToolUse hook contract.
# Plan originally framed this as a "block on no --approved" hook, but reality is
# it's NON-blocking — only logs PENDING audit entries. Test reflects actual contract.
bats_require_minimum_version 1.5.0

PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/gh-manager-guard.sh"
  export REAL_HOME="$HOME"
  export HOME="$BATS_TEST_TMPDIR/fakehome"
  mkdir -p "$HOME"
}
teardown() {
  export HOME="$REAL_HOME"
}

invoke_hook() {
  local tool="$1" cmd="$2"
  local in="$BATS_TEST_TMPDIR/in.json"
  python3 -c "
import json, sys
print(json.dumps({'tool_name': sys.argv[1], 'tool_input': {'command': sys.argv[2]}}))
" "$tool" "$cmd" > "$in"
  bash "$SCRIPT" < "$in"
}

@test "non-Bash tool call → silent exit 0 (GG1)" {
  run --separate-stderr invoke_hook "Read" "irrelevant"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "Bash command without gh-manager → silent exit 0 (GG2)" {
  run --separate-stderr invoke_hook "Bash" "ls -la"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "non-mutation gh-manager command → exit 0, no PENDING log (GG3)" {
  run --separate-stderr invoke_hook "Bash" "node gh-manager.js issue list"
  [ "$status" -eq 0 ]
  # No audit log entry for read-only commands.
  [ ! -s "$HOME/.github-repo-manager-audit.log" ] || ! grep -q PENDING "$HOME/.github-repo-manager-audit.log"
}

@test "[P1] hook is non-blocking — even mutations exit 0 (GG-non-blocking)" {
  # Documented contract: hook logs PENDING but never blocks. Behavioral
  # enforcement (approval gate) lives in the skill file, not here.
  run --separate-stderr invoke_hook "Bash" "node gh-manager.js issues close 42"
  [ "$status" -eq 0 ]
}

@test "mutation command appends PENDING audit entry (GG-audit)" {
  invoke_hook "Bash" "node gh-manager.js issues close 42" || true
  [ -f "$HOME/.github-repo-manager-audit.log" ]
  grep -q PENDING "$HOME/.github-repo-manager-audit.log"
}

@test "malformed stdin → silent exit 0, no crash (GG-robust)" {
  echo 'not json' > "$BATS_TEST_TMPDIR/bad.json"
  run --separate-stderr bash -c "bash '$SCRIPT' < '$BATS_TEST_TMPDIR/bad.json'"
  [ "$status" -eq 0 ]
}
