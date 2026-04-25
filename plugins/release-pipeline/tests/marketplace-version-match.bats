#!/usr/bin/env bats
# marketplace-version-match.bats — [P4] Use the Full Toolkit (Structural)
# Wraps validate-marketplace.sh so version drift fails fast in this suite, not just on install.
load test_helper

@test "validate-marketplace.sh passes on the live marketplace tree (MV1)" {
  run bash "$REPO_ROOT/scripts/validate-marketplace.sh"
  [ "$status" -eq 0 ]
}

@test "version mismatch between plugin.json and marketplace.json is detected (MV2)" {
  TMP_MKT="$BATS_TEST_TMPDIR/mkt"
  mkdir -p "$TMP_MKT/.claude-plugin" \
           "$TMP_MKT/plugins/sample/.claude-plugin" \
           "$TMP_MKT/scripts"
  cat > "$TMP_MKT/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "test-mkt",
  "owner": {"name": "test"},
  "plugins": [
    {"name": "sample", "description": "x", "version": "1.0.0", "source": "./plugins/sample"}
  ]
}
JSON
  cat > "$TMP_MKT/plugins/sample/.claude-plugin/plugin.json" <<'JSON'
{"name": "sample", "version": "9.9.9", "description": "x"}
JSON
  cp "$REPO_ROOT/scripts/validate-marketplace.sh" "$TMP_MKT/scripts/"
  run bash "$TMP_MKT/scripts/validate-marketplace.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Version mismatch"* ]]
}

@test "invalid plugin.json field (Zod-strict) is rejected (MV3)" {
  TMP_MKT="$BATS_TEST_TMPDIR/mkt2"
  mkdir -p "$TMP_MKT/.claude-plugin" \
           "$TMP_MKT/plugins/sample/.claude-plugin" \
           "$TMP_MKT/scripts"
  cat > "$TMP_MKT/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "test-mkt",
  "owner": {"name": "test"},
  "plugins": [
    {"name": "sample", "description": "x", "version": "1.0.0", "source": "./plugins/sample"}
  ]
}
JSON
  # 'category' is rejected by Zod strict mode for plugin.json.
  cat > "$TMP_MKT/plugins/sample/.claude-plugin/plugin.json" <<'JSON'
{"name": "sample", "version": "1.0.0", "description": "x", "category": "tools"}
JSON
  cp "$REPO_ROOT/scripts/validate-marketplace.sh" "$TMP_MKT/scripts/"
  run bash "$TMP_MKT/scripts/validate-marketplace.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"category"* ]]
}
