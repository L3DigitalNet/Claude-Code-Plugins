#!/usr/bin/env bats
# sync-local-plugins.bats — [P2] Scope Fidelity + [P3] Succeed Quietly
# SessionStart hook syncs local plugin source → installed cache for already-installed plugins.
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/sync-local-plugins.sh"
  setup_tmp_home
  export RELEASE_PIPELINE_MARKETPLACE="test-marketplace"
  CACHE="$HOME/.claude/plugins/cache/$RELEASE_PIPELINE_MARKETPLACE"

  # Build a fake source repo with marketplace.json + two plugins.
  REPO="$BATS_TEST_TMPDIR/source-repo"
  mkdir -p "$REPO/.claude-plugin" "$REPO/plugins/p1" "$REPO/plugins/p2"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{"name": "test-marketplace", "owner": {"name": "test"}, "plugins": []}
JSON
  echo "p1-content-v1" > "$REPO/plugins/p1/file.txt"
  echo "p2-content-v1" > "$REPO/plugins/p2/file.txt"
  export CLAUDE_PROJECT_DIR="$REPO"
}

@test "no cache dir → silent exit 0 (SP1 don't-create-cache)" {
  rm -rf "$CACHE"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "[P2] all installed plugins are synced (SP2)" {
  mkdir -p "$CACHE/p1" "$CACHE/p2"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$CACHE/p1/file.txt")" = "p1-content-v1" ]
  [ "$(cat "$CACHE/p2/file.txt")" = "p2-content-v1" ]
  [[ "$output" == *"2 plugin(s)"* ]]
}

@test "non-installed plugin is not created (no silent installs) (SP3)" {
  mkdir -p "$CACHE/p1"   # only p1 installed
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$CACHE/p1/file.txt" ]
  [ ! -d "$CACHE/p2" ]
}

@test "[P3] no output when nothing changed (SP4 quiet success)" {
  mkdir -p "$CACHE/p1"
  cp "$REPO/plugins/p1/file.txt" "$CACHE/p1/file.txt"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "honors RELEASE_PIPELINE_MARKETPLACE env override (SP5)" {
  export RELEASE_PIPELINE_MARKETPLACE="other"
  rm -rf "$HOME/.claude/plugins/cache/$RELEASE_PIPELINE_MARKETPLACE"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "marketplace.json with mismatched name → repo not found, silent (SP6)" {
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{"name": "wrong-name", "owner": {"name": "test"}, "plugins": []}
JSON
  mkdir -p "$CACHE/p1"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # p1 was not synced.
  [ ! -f "$CACHE/p1/file.txt" ]
}

@test "node_modules is excluded from sync (SP7)" {
  mkdir -p "$CACHE/p1" "$REPO/plugins/p1/node_modules"
  echo "should not sync" > "$REPO/plugins/p1/node_modules/junk.js"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -e "$CACHE/p1/node_modules/junk.js" ]
}
