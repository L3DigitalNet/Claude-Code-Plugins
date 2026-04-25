#!/usr/bin/env bats
# check-manifests.bats — [P3] Scope Fidelity (skip in non-marketplace repos).
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  REPO="$TEST_TMPDIR/repo"
  mkdir -p "$REPO"
  cd "$REPO"
  git init -q -b main
  git config user.email "test@test.com"
  git config user.name "Test"
  git config commit.gpgsign false
  echo "x" > x
  git add x
  git commit -q -m initial
}
teardown() {
  cd /
  teardown_test_env
}

@test "non-marketplace repo (no marketplace.json) → empty findings (CM1 scope-aware skip)" {
  run bash "$SCRIPTS_DIR/check-manifests.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  count=$(echo "$output" | jq '.findings | length')
  [ "$count" -eq 0 ]
}

@test "marketplace repo: matching versions → no findings (CM2)" {
  mkdir -p "$REPO/.claude-plugin" "$REPO/plugins/sample/.claude-plugin"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "test-mkt",
  "owner": {"name": "test"},
  "plugins": [{"name": "sample", "description": "x", "version": "1.0.0", "source": "./plugins/sample"}]
}
JSON
  cat > "$REPO/plugins/sample/.claude-plugin/plugin.json" <<'JSON'
{"name": "sample", "version": "1.0.0", "description": "x"}
JSON
  run bash "$SCRIPTS_DIR/check-manifests.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
}

@test "marketplace repo: version mismatch → flagged (CM3)" {
  mkdir -p "$REPO/.claude-plugin" "$REPO/plugins/sample/.claude-plugin"
  cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "test-mkt",
  "owner": {"name": "test"},
  "plugins": [{"name": "sample", "description": "x", "version": "1.0.0", "source": "./plugins/sample"}]
}
JSON
  cat > "$REPO/plugins/sample/.claude-plugin/plugin.json" <<'JSON'
{"name": "sample", "version": "9.9.9", "description": "x"}
JSON
  run bash "$SCRIPTS_DIR/check-manifests.sh"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  count=$(echo "$output" | jq '.findings | length')
  [ "$count" -ge 1 ]
}
