#!/usr/bin/env bats
# check-prerequisites.bats — Cross-cutting Mechanical: dependency-discovery report.
bats_require_minimum_version 1.5.0
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/check-prerequisites.sh"
}

@test "script exits with 0 or 1 (CP1 deterministic exit)" {
  run bash "$SCRIPT"
  # Either all-OK (0) or missing prereqs (1) — but never any other code.
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "script reports something to user (not silent on either path) (CP2)" {
  run bash "$SCRIPT"
  [ -n "$output" ]
}

@test "script identifies itself as qt-suite output (CP3)" {
  # All paths emit "qt-suite:" prefix — sanity check that we're seeing the
  # canonical reporter, not stray output from a sourced helper.
  run bash "$SCRIPT"
  [[ "$output" == *"qt-suite"* ]]
}

@test "exit code matches presence of REQUIRED errors (CP4)" {
  # Defensive contract: if "all prerequisites satisfied" appears in output,
  # exit must be 0. If "MISSING REQUIRED" appears, exit must be 1.
  run bash "$SCRIPT"
  if [[ "$output" == *"MISSING REQUIRED"* ]]; then
    [ "$status" -eq 1 ]
  elif [[ "$output" == *"all prerequisites satisfied"* ]]; then
    [ "$status" -eq 0 ]
  fi
  # Else: only optional warnings present → exit 0 acceptable. No assertion.
}
