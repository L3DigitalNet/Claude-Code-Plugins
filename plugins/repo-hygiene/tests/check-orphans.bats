#!/usr/bin/env bats
# check-orphans.bats — [P4] Safety by Construction (Mechanical half)
# CRITICAL FINDING: per the README, the 3-check rm safety guard is enforced in
# the /hygiene COMMAND, not in this script. The script's mechanical contract is
# narrower: emit findings, never propose destructive fix_cmd. These tests lock
# the script's contract; the command-side guard is Behavioral and out of scope.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  export REAL_HOME="$HOME"
  export HOME="$TEST_TMPDIR/fakehome"
  mkdir -p "$HOME/.claude/plugins/cache"
}
teardown() {
  export HOME="$REAL_HOME"
  teardown_test_env
}

@test "[P4] script never emits destructive fix_cmd — every finding has fix_cmd=null (CO-P4-fix-null)" {
  # Build conditions for several finding types simultaneously.
  cat > "$HOME/.claude/plugins/installed_plugins.json" <<'JSON'
{"plugins": {"a@m": [{"installPath": "/p/a"}]}}
JSON
  cat > "$HOME/.claude/settings.json" <<'JSON'
{"enabledPlugins": {"b@m": true}}
JSON
  mkdir -p "$HOME/.claude/plugins/cache/temp_orphan"
  mkdir -p "$HOME/.claude/plugins/cache/temp_..suspicious"
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  # Assert that NO finding has a non-null fix_cmd.
  destructive=$(echo "$output" | jq '[.findings[] | select(.fix_cmd != null)] | length')
  [ "$destructive" -eq 0 ]
  # Assert that NO finding has auto_fix=true.
  auto=$(echo "$output" | jq '[.findings[] | select(.auto_fix == true)] | length')
  [ "$auto" -eq 0 ]
}

@test "temp_* orphan dir flagged with warn severity (CO1)" {
  mkdir -p "$HOME/.claude/plugins/cache/temp_legitimate"
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.path | contains("temp_legitimate")) | select(.severity=="warn")] | length')
  [ "$flagged" -ge 1 ]
}

@test "non-temp_ directory NOT flagged as orphan (CO2)" {
  mkdir -p "$HOME/.claude/plugins/cache/some-marketplace"
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.path | contains("some-marketplace"))] | length')
  [ "$flagged" -eq 0 ]
}

@test "stale enabledPlugins entry without installed_plugins entry flagged (CO3)" {
  cat > "$HOME/.claude/plugins/installed_plugins.json" <<'JSON'
{"plugins": {}}
JSON
  cat > "$HOME/.claude/settings.json" <<'JSON'
{"enabledPlugins": {"stale-plugin@mkt": true}}
JSON
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  flagged=$(echo "$output" | jq '[.findings[] | select(.detail | contains("stale-plugin"))] | length')
  [ "$flagged" -ge 1 ]
}

@test "installed-but-not-enabled is INFO not WARN (CO4 severity classification)" {
  cat > "$HOME/.claude/plugins/installed_plugins.json" <<'JSON'
{"plugins": {"silent@mkt": [{"installPath": "/p"}]}}
JSON
  cat > "$HOME/.claude/settings.json" <<'JSON'
{"enabledPlugins": {}}
JSON
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  info=$(echo "$output" | jq '[.findings[] | select(.detail | contains("silent")) | select(.severity=="info")] | length')
  [ "$info" -ge 1 ]
}

@test "malformed installed_plugins.json → warn finding, not crash (CO5)" {
  echo 'not json' > "$HOME/.claude/plugins/installed_plugins.json"
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  flagged=$(echo "$output" | jq '[.findings[] | select(.detail | contains("Could not parse"))] | length')
  [ "$flagged" -ge 1 ]
}

@test "all files absent → empty findings, exit 0 (CO6 robustness)" {
  rm -f "$HOME/.claude/plugins/installed_plugins.json" "$HOME/.claude/settings.json"
  rm -rf "$HOME/.claude/plugins/cache"
  run bash "$SCRIPTS_DIR/check-orphans.sh"
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq '.findings | length')
  [ "$count" -eq 0 ]
}
