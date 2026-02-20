#!/usr/bin/env bash
# tests/test-check-waivers.sh — Unit tests for check-waivers.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/check-waivers.sh"
PASS=0; FAIL=0
TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

# Write a test waivers file
WAIVER_FILE="$TMPDIR_LOCAL/.release-waivers.json"
cat > "$WAIVER_FILE" <<'JSON'
{
  "waivers": [
    { "check": "dirty_working_tree", "plugin": "*",            "reason": "monorepo always dirty" },
    { "check": "missing_tests",      "plugin": "docs-manager", "reason": "docs-only plugin" },
    { "check": "tag_exists",         "plugin": "my-plugin",   "reason": "re-running partial release" }
  ]
}
JSON

# ---- Test 1: wildcard waiver matches any plugin ----
reason=$(bash "$SCRIPT" "$WAIVER_FILE" dirty_working_tree any-plugin 2>/dev/null)
EC=$?
assert_eq "$EC" "0" "wildcard waiver: exit 0"
assert_eq "$reason" "monorepo always dirty" "wildcard waiver: correct reason"

# ---- Test 2: plugin-specific waiver matches exact plugin ----
reason=$(bash "$SCRIPT" "$WAIVER_FILE" missing_tests docs-manager 2>/dev/null)
EC=$?
assert_eq "$EC" "0" "specific plugin waiver: exit 0"
assert_eq "$reason" "docs-only plugin" "specific plugin waiver: correct reason"

# ---- Test 3: plugin-specific waiver does NOT match different plugin ----
bash "$SCRIPT" "$WAIVER_FILE" missing_tests other-plugin 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "plugin-specific waiver: no match for other plugin -> exit 1"

# ---- Test 4: check not in waivers → exit 1 ----
bash "$SCRIPT" "$WAIVER_FILE" noreply_email any-plugin 2>/dev/null && RES=0 || RES=$?
assert_eq "$RES" "1" "unknown check -> exit 1"

# ---- Test 5: missing waiver file → exit 1 (fail open: don't waive) ----
bash "$SCRIPT" "/nonexistent/.release-waivers.json" dirty_working_tree any-plugin 2>/dev/null \
  && RES=0 || RES=$?
assert_eq "$RES" "1" "missing waiver file -> exit 1"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
