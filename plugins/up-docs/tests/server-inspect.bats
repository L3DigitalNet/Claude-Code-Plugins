#!/usr/bin/env bats
# server-inspect.bats — [P4] Ground Truth Wins (script reflects live state, no caching).
# PATH-stubbed ssh emits deterministic delimited sections; the script must parse them.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  STUBS_DIR="$BATS_TEST_DIRNAME/fixtures/stubs"
  export PATH="$STUBS_DIR:$PATH"
}
teardown() { teardown_test_env; }

@test "unreachable host → reachable=false in JSON, exit 0 (SI1)" {
  SSH_STUB_MODE=unreachable run bash "$SCRIPTS_DIR/server-inspect.sh" testhost generic
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.reachable')" = "false" ]
}

@test "reachable host emits parsed system + service info (SI2)" {
  SSH_STUB_MODE=reachable run bash "$SCRIPTS_DIR/server-inspect.sh" testhost systemd
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null
  [ "$(echo "$output" | jq -r '.reachable')" = "true" ]
  [ "$(echo "$output" | jq -r '.inspection.system.hostname')" = "fakehost.local" ]
  [ "$(echo "$output" | jq -r '.inspection.system.kernel')" = "6.0.0-test" ]
}

@test "[P4] script output reflects stub responses, not any cached value (SI3)" {
  # Run twice with different stubs — second run must reflect new state.
  SSH_STUB_MODE=reachable bash "$SCRIPTS_DIR/server-inspect.sh" testhost generic > /tmp/run1.json
  SSH_STUB_MODE=unreachable bash "$SCRIPTS_DIR/server-inspect.sh" testhost generic > /tmp/run2.json
  r1=$(jq -r '.reachable' /tmp/run1.json)
  r2=$(jq -r '.reachable' /tmp/run2.json)
  [ "$r1" = "true" ]
  [ "$r2" = "false" ]
}

@test "listening_ports parsed from ss output (SI4)" {
  SSH_STUB_MODE=reachable run bash "$SCRIPTS_DIR/server-inspect.sh" testhost generic
  [ "$status" -eq 0 ]
  ports=$(echo "$output" | jq -r '.inspection.listening_ports[]')
  [[ "$ports" == *"22/tcp"* ]]
  [[ "$ports" == *"80/tcp"* ]]
}

@test "missing args → usage error (SI5)" {
  run bash "$SCRIPTS_DIR/server-inspect.sh"
  [ "$status" -ne 0 ]
}
