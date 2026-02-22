#!/usr/bin/env bash
# tests/test-api-retry.sh — Unit tests for api-retry.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/api-retry.sh"
PASS=0; FAIL=0

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

# ---- Test 1: succeeds on first attempt ----
out=$(bash "$SCRIPT" 3 100 -- echo "ok" 2>/dev/null)
assert_eq "$out" "ok" "passes through output on success"

# ---- Test 2: fails all attempts → exit 1 ----
bash "$SCRIPT" 3 100 -- false 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "exits 1 when all attempts exhausted"

# ---- Test 3: succeeds on second attempt ----
COUNT_FILE=$(mktemp)
echo "0" > "$COUNT_FILE"
CMD=$(mktemp)
trap 'rm -f "$COUNT_FILE" "$CMD"' EXIT
cat > "$CMD" <<CMDEOF
#!/usr/bin/env bash
count=\$(cat "$COUNT_FILE")
count=\$((count + 1))
echo \$count > "$COUNT_FILE"
[[ \$count -ge 2 ]]  # exits 0 on attempt 2+
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 3 100 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "0" "retries and succeeds on second attempt"
rm -f "$COUNT_FILE" "$CMD"

# ---- Test 4: 'already exists' in stderr → treated as success ----
CMD=$(mktemp)
cat > "$CMD" <<'CMDEOF'
#!/usr/bin/env bash
echo "already exists" >&2
exit 1
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 3 100 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "0" "already-exists in stderr treated as success"
rm -f "$CMD"

# ---- Test 5: HTTP 400 in stderr → exit 1 immediately (no retry) ----
CMD=$(mktemp)
COUNTER_FILE=$(mktemp)
echo "0" > "$COUNTER_FILE"
cat > "$CMD" <<CMDEOF
#!/usr/bin/env bash
count=\$(cat "$COUNTER_FILE")
count=\$((count + 1))
echo \$count > "$COUNTER_FILE"
echo "HTTP 400: Bad Request" >&2
exit 1
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 3 100 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "HTTP 400 → exit 1 immediately"
# Should only attempt once — permanent error, no retry
attempts=$(cat "$COUNTER_FILE")
assert_eq "$attempts" "1" "HTTP 400 → only 1 attempt (no retry)"
rm -f "$CMD" "$COUNTER_FILE"

# ---- Test 6: HTTP 404 in stderr → exit 1 immediately ----
CMD=$(mktemp)
cat > "$CMD" <<'CMDEOF'
#!/usr/bin/env bash
echo "HTTP 404: Not Found" >&2
exit 1
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 3 100 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "HTTP 404 → exit 1 immediately (no retry)"
rm -f "$CMD"

# ---- Test 7: HTTP 429 (rate-limit) → retried (not immediately aborted) ----
CMD=$(mktemp)
COUNTER_FILE=$(mktemp)
echo "0" > "$COUNTER_FILE"
cat > "$CMD" <<CMDEOF
#!/usr/bin/env bash
count=\$(cat "$COUNTER_FILE")
count=\$((count + 1))
echo \$count > "$COUNTER_FILE"
echo "HTTP 429: Too Many Requests" >&2
exit 1
CMDEOF
chmod +x "$CMD"
bash "$SCRIPT" 2 50 -- bash "$CMD" 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "HTTP 429 → exhausts retries (not immediately aborted)"
attempts=$(cat "$COUNTER_FILE")
assert_eq "$attempts" "2" "HTTP 429 → retried (attempt count = max_attempts)"
rm -f "$CMD" "$COUNTER_FILE"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
