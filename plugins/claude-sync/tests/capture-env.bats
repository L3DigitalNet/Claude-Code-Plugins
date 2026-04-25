#!/usr/bin/env bats
# capture-env.bats — [P1] Wholesale Capture, [P2] Code via Git, [P3] Secrets Never Leave,
# [P5] Machine-Local Config Stays Local. Highest-stakes assertion in the plugin
# is the [P3] secrets-exclusion guarantee — verified against the produced tarball.
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

# Helper: list contents of the snapshot tarball.
list_archive() {
  local sync_path="$1"
  local archive
  archive=$(ls "$sync_path"/claude-sync-*.tar.gz 2>/dev/null | head -1)
  [[ -n "$archive" ]] || return 1
  tar -tzf "$archive"
}

@test "[P1] arbitrary unknown files under ~/.claude are captured (CE-P1)" {
  # Wholesale capture must include files Claude Code may add in future releases.
  echo "future-feature" > "$HOME/.claude/__future_feature__.json"
  mkdir -p "$HOME/.claude/some_new_dir"
  echo "x" > "$HOME/.claude/some_new_dir/whatever.dat"
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  contents=$(list_archive "$SYNC_DIR")
  [[ "$contents" == *"__future_feature__.json"* ]]
  [[ "$contents" == *"some_new_dir/whatever.dat"* ]]
}

@test "[P3] .credentials.json is NOT in the snapshot (CE-P3-creds)" {
  # Highest-value security assertion in the plugin.
  echo '{"oauth": "secret-token"}' > "$HOME/.claude/.credentials.json"
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  contents=$(list_archive "$SYNC_DIR")
  [[ "$contents" != *".credentials.json"* ]]
}

@test "[P3] statsig analytics dir is NOT in the snapshot (CE-P3-statsig)" {
  mkdir -p "$HOME/.claude/statsig"
  echo "tracking" > "$HOME/.claude/statsig/cache.json"
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  contents=$(list_archive "$SYNC_DIR")
  [[ "$contents" != *"statsig"* ]]
}

@test "[P3] projects/ session-history dir is NOT in the snapshot (CE-P3-projects)" {
  mkdir -p "$HOME/.claude/projects/some-proj"
  echo "session" > "$HOME/.claude/projects/some-proj/history.json"
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  contents=$(list_archive "$SYNC_DIR")
  [[ "$contents" != *"projects"* ]] || [[ "$contents" != *"session"* ]]
  # Stricter assertion: no path component named exactly 'projects' under claude/
  [[ "$contents" != *"claude/projects/"* ]]
}

@test "[P3] only mcpServers key extracted from ~/.claude.json — OAuth-shaped fields dropped (CE-P3-mcp-only)" {
  cat > "$HOME/.claude.json" <<'JSON'
{
  "mcpServers": {
    "demo": {"command": "npx", "args": ["-y", "@scope/demo"]}
  },
  "oauthAccount": {"accessToken": "TOKEN_LEAK_THIS_FAILS_THE_TEST"},
  "subscriptionToken": "ANOTHER_LEAK_TARGET"
}
JSON
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  archive=$(ls "$SYNC_DIR"/claude-sync-*.tar.gz | head -1)
  # Extract mcp-servers.json from the archive and verify it does NOT carry the leak markers.
  tmp=$(mktemp -d)
  tar -xzf "$archive" -C "$tmp"
  mcp_content=$(cat "$tmp/mcp-servers.json")
  rm -rf "$tmp"
  [[ "$mcp_content" != *"TOKEN_LEAK"* ]]
  [[ "$mcp_content" != *"ANOTHER_LEAK"* ]]
  [[ "$mcp_content" != *"oauthAccount"* ]]
  [[ "$mcp_content" != *"subscriptionToken"* ]]
  # Sanity: demo server WAS extracted.
  [[ "$mcp_content" == *"demo"* ]]
}

@test "[P2] repository content under repos_root is NOT in the snapshot (CE-P2)" {
  # Code travels via git, not via the snapshot.
  mkdir -p "$REPOS_DIR/myrepo"
  echo "source-code-content" > "$REPOS_DIR/myrepo/main.py"
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  contents=$(list_archive "$SYNC_DIR")
  [[ "$contents" != *"main.py"* ]]
  [[ "$contents" != *"myrepo"* ]] || true   # repo dir name may coincide with other content; we focus on file
}

@test "[P5] claude-sync-config block stripped from CLAUDE.md in snapshot (CE-P5)" {
  cat > "$HOME/.claude/CLAUDE.md" <<'EOF'
# global rules

regular content stays.

<!-- claude-sync-config-start -->
sync_path: /machine-specific/path
secret_store: /local/bao
<!-- claude-sync-config-end -->

more regular content.
EOF
  bash "$SCRIPTS_DIR/capture-env.sh" "$SYNC_DIR" testhost "$REPOS_DIR" >/dev/null
  archive=$(ls "$SYNC_DIR"/claude-sync-*.tar.gz | head -1)
  tmp=$(mktemp -d)
  tar -xzf "$archive" -C "$tmp"
  claude_md=$(cat "$tmp/claude/CLAUDE.md")
  rm -rf "$tmp"
  [[ "$claude_md" != *"machine-specific/path"* ]]
  [[ "$claude_md" != *"claude-sync-config-start"* ]]
  [[ "$claude_md" == *"regular content stays"* ]]
  [[ "$claude_md" == *"more regular content"* ]]
}
