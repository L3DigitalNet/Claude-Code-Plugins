#!/usr/bin/env bats
# is-survival-context.bats — [P5] Human-First in Survival Contexts.
# Classification rule: survival = (doc-type ∈ {sysadmin,dev,personal}) AND (audience ∈ {human,both}).
# audience=ai is the explicit P5 exception that overrides doc-type.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  SCRIPT="$SCRIPTS_DIR/is-survival-context.sh"
}
teardown() { teardown_test_env; }

@test "sysadmin + human → true (SC1)" {
  run bash "$SCRIPT" --doc-type sysadmin --audience human
  [ "$output" = "true" ]
}

@test "dev + both → true (SC2)" {
  run bash "$SCRIPT" --doc-type dev --audience both
  [ "$output" = "true" ]
}

@test "personal + human → true (SC3)" {
  run bash "$SCRIPT" --doc-type personal --audience human
  [ "$output" = "true" ]
}

@test "[P5 exception] sysadmin + ai → false (SC4)" {
  # AI audience overrides doc-type — never survival.
  run bash "$SCRIPT" --doc-type sysadmin --audience ai
  [ "$output" = "false" ]
}

@test "reference + human → false (SC5 doc-type doesn't qualify)" {
  run bash "$SCRIPT" --doc-type reference --audience human
  [ "$output" = "false" ]
}

@test "missing doc-type → false (SC6 default-safe)" {
  run bash "$SCRIPT"
  [ "$output" = "false" ]
}

@test "audience defaults to human when unspecified (SC7)" {
  run bash "$SCRIPT" --doc-type dev
  [ "$output" = "true" ]
}

@test "missing file path → false (SC8)" {
  run bash "$SCRIPT" "$BATS_TEST_TMPDIR/missing.md"
  [ "$output" = "false" ]
}
