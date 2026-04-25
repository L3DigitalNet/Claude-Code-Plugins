#!/usr/bin/env bats
# parse-snapshot.bats — Symmetric assertion that import side never expands
# captured mcp-servers.json with anything beyond what was captured.
bats_require_minimum_version 1.5.0
load bats-helpers

setup() {
  setup_test_env
  export REAL_HOME="$HOME"
  export HOME="$TEST_TMPDIR/fakehome"
  mkdir -p "$HOME/.claude"
  SYNC_DIR="$TEST_TMPDIR/sync"
  REPOS_DIR="$TEST_TMPDIR/repos"
  mkdir -p "$SYNC_DIR" "$REPOS_DIR"
}

teardown() {
  export HOME="$REAL_HOME"
  teardown_test_env
}

@test "no snapshot in sync dir → returns no_snapshot error JSON, exit 0 (PS1)" {
  run bash "$SCRIPTS_DIR/parse-snapshot.sh" "$SYNC_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.error')" = "no_snapshot" ]
}

@test "[P3] parse output never echoes raw OAuth-shaped strings even if local .claude.json had them (PS-P3)" {
  # Build a snapshot with a clean mcpServers payload using capture-env.
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  # Now write a *local* .claude.json that has tokens; parse-snapshot should NOT
  # leak those into its output (only mcpServer names are read).
  cat > "$HOME/.claude.json" <<'JSON'
{"mcpServers": {"x": {"command": "npx"}}, "oauthAccount": {"accessToken": "DO_NOT_LEAK_THIS"}}
JSON
  run bash "$SCRIPTS_DIR/parse-snapshot.sh" "$SYNC_DIR"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [[ "$output" != *"DO_NOT_LEAK_THIS"* ]]
}

@test "diff identifies new file in snapshot as additions[] (PS-add)" {
  # Build a snapshot with a unique file that doesn't exist locally.
  echo "new-content" > "$HOME/.claude/snapshot-only.txt"
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  # Now wipe local copy of that file so it appears as an addition.
  rm "$HOME/.claude/snapshot-only.txt"
  run bash "$SCRIPTS_DIR/parse-snapshot.sh" "$SYNC_DIR"
  [ "$status" -eq 0 ]
  add_paths=$(echo "$output" | jq -r '.diff.additions[].path')
  [[ "$add_paths" == *"snapshot-only.txt"* ]]
}
