#!/usr/bin/env bats
# api-retry.bats — [P3] Succeed Quietly, Fail Transparently (loud-fail contract)
# Uses base_delay_ms=1 so retry sleeps round to ~0s — keeps suite fast.
load test_helper

setup() {
  SCRIPT="$PLUGIN_ROOT/scripts/api-retry.sh"
  STUB="$BATS_TEST_TMPDIR/cmd-stub"
}

# Helper: build a stub command that fails N times then succeeds, tracking attempts.
make_failing_then_succeed_stub() {
  local n="$1"
  local stderr_msg="${2:-transient failure}"
  local counter="$BATS_TEST_TMPDIR/attempts"
  echo "0" > "$counter"
  cat > "$STUB" <<STUB
#!/usr/bin/env bash
n=\$(cat "$counter")
n=\$((n+1))
echo \$n > "$counter"
if [ \$n -le $n ]; then
  echo "$stderr_msg attempt \$n" >&2
  exit 1
fi
echo "success on attempt \$n"
exit 0
STUB
  chmod +x "$STUB"
}

@test "command succeeding on first attempt: exit 0, no retry messages (AR1)" {
  cat > "$STUB" <<'STUB'
#!/usr/bin/env bash
echo "ok"
exit 0
STUB
  chmod +x "$STUB"
  run bash "$SCRIPT" 3 1 -- "$STUB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
  [[ "$output" != *"Retrying in"* ]]
}

@test "transient failure retried; succeeds within max attempts (AR2)" {
  make_failing_then_succeed_stub 1
  run bash "$SCRIPT" 3 1 -- "$STUB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"success on attempt"* ]]
  [[ "$output" == *"Retrying in"* ]]
}

@test "all attempts exhausted: exit 1 with raw last error (AR3)" {
  cat > "$STUB" <<'STUB'
#!/usr/bin/env bash
echo "permanent fail" >&2
exit 1
STUB
  chmod +x "$STUB"
  run bash "$SCRIPT" 2 1 -- "$STUB"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed after 2 attempts"* ]]
  [[ "$output" == *"permanent fail"* ]]
}

@test "'already exists' stderr treated as success (AR4 idempotency)" {
  cat > "$STUB" <<'STUB'
#!/usr/bin/env bash
echo "release v1.0.0 already exists" >&2
exit 1
STUB
  chmod +x "$STUB"
  run bash "$SCRIPT" 3 1 -- "$STUB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "HTTP 404 fails fast without retry (AR5)" {
  cat > "$STUB" <<'STUB'
#!/usr/bin/env bash
echo "HTTP 404: not found" >&2
exit 1
STUB
  chmod +x "$STUB"
  run bash "$SCRIPT" 5 1 -- "$STUB"
  [ "$status" -eq 1 ]
  [[ "$output" == *"permanent API error"* ]]
  [[ "$output" == *"404"* ]]
  [[ "$output" != *"Retrying in"* ]]
}

@test "HTTP 429 (rate-limit) IS retried (AR6)" {
  make_failing_then_succeed_stub 1 "HTTP 429: rate limited"
  run bash "$SCRIPT" 3 1 -- "$STUB"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Retrying in"* ]]
  [[ "$output" == *"success on attempt"* ]]
}

@test "invalid max_attempts (zero) → exit 1 with usage error (AR7)" {
  run bash "$SCRIPT" 0 1 -- echo
  [ "$status" -eq 1 ]
  [[ "$output" == *"max_attempts"* ]]
}

@test "missing args → usage error (AR8)" {
  run bash "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Usage:"* ]]
}
