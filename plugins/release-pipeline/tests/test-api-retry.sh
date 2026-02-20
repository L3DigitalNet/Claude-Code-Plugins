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

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
