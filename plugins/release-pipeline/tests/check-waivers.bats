#!/usr/bin/env bats
# check-waivers.bats — [P5] Convergence is the Contract (waiver = explicit override)
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/check-waivers.sh"
  WAIVER_FILE="$BATS_TEST_TMPDIR/.release-waivers.json"
  cat > "$WAIVER_FILE" <<'JSON'
{
  "waivers": [
    { "check": "dirty_working_tree", "plugin": "*",            "reason": "monorepo always dirty" },
    { "check": "missing_tests",      "plugin": "docs-manager", "reason": "docs-only plugin" },
    { "check": "tag_exists",         "plugin": "my-plugin",    "reason": "re-running partial release" }
  ]
}
JSON
}

@test "wildcard waiver matches any plugin (CW1)" {
  run bash "$SCRIPT" "$WAIVER_FILE" dirty_working_tree any-plugin
  [ "$status" -eq 0 ]
  [ "$output" = "monorepo always dirty" ]
}

@test "plugin-specific waiver matches exact plugin (CW2)" {
  run bash "$SCRIPT" "$WAIVER_FILE" missing_tests docs-manager
  [ "$status" -eq 0 ]
  [ "$output" = "docs-only plugin" ]
}

@test "plugin-specific waiver rejects mismatched plugin (CW3)" {
  run bash "$SCRIPT" "$WAIVER_FILE" missing_tests other-plugin
  [ "$status" -eq 1 ]
}

@test "unwaived check returns exit 1 (CW4)" {
  run bash "$SCRIPT" "$WAIVER_FILE" noreply_email any-plugin
  [ "$status" -eq 1 ]
}

@test "missing waiver file returns exit 1 (CW5)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/nonexistent.json" any_check any-plugin
  [ "$status" -eq 1 ]
}

@test "malformed waiver JSON returns exit 1 (CW6)" {
  echo 'not json' > "$WAIVER_FILE"
  run bash "$SCRIPT" "$WAIVER_FILE" dirty_working_tree any-plugin
  [ "$status" -eq 1 ]
}

@test "missing args → usage error (CW7)" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
