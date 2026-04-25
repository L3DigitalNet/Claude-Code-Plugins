#!/usr/bin/env bats
# flight-log-durability.bats — [P5] Survive Interruptions: append-only durability.
# Exercises the JSONL append contract with multiple sequential and concurrent
# appends to detect corruption.
bats_require_minimum_version 1.5.0
load helpers

setup() {
  setup_test_env
  WORK="$BATS_TEST_TMPDIR/work"
  mkdir -p "$WORK/.claude/nominal"
  cd "$WORK"
}
teardown() {
  cd /
  teardown_test_env
}

append() {
  local content="$1"
  echo "$content" | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null 2>&1 || true
}

@test "[P5] sequential appends preserve all records (FL1)" {
  append '{"type":"postflight","status":"green"}'
  append '{"type":"postflight","status":"yellow"}'
  append '{"type":"abort","status":"red"}'
  count=$(wc -l < .claude/nominal/runs.jsonl)
  [ "$count" -eq 3 ]
}

@test "[P5] each line in JSONL is independently valid JSON (FL2)" {
  append '{"type":"postflight","status":"green"}'
  append '{"type":"postflight","status":"yellow"}'
  while IFS= read -r line; do
    echo "$line" | python3 -c "import json,sys; json.loads(sys.stdin.read())"
  done < .claude/nominal/runs.jsonl
}

@test "[P5] concurrent appends (10x parallel) do not corrupt JSONL (FL3)" {
  # Spawn 10 background appends; verify all 10 lines are intact and parseable.
  for i in $(seq 1 10); do
    (echo "{\"type\":\"postflight\",\"id\":$i}" | bash "$SCRIPTS_DIR/flight-log.sh" append >/dev/null 2>&1) &
  done
  wait
  count=$(wc -l < .claude/nominal/runs.jsonl)
  # All 10 should be present (or flagged as concurrency issue if not).
  [ "$count" -eq 10 ]
  # All lines parse independently.
  while IFS= read -r line; do
    echo "$line" | python3 -c "import json,sys; json.loads(sys.stdin.read())"
  done < .claude/nominal/runs.jsonl
}
