#!/usr/bin/env bash
# tests/test-detect-unreleased.sh — Unit tests for detect-unreleased.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/detect-unreleased.sh"
PASS=0; FAIL=0

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local actual="$1" pattern="$2" label="$3"
  if [[ "$actual" == *"$pattern"* ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (expected '$pattern' in: '$actual')"; FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local actual="$1" pattern="$2" label="$3"
  if [[ "$actual" != *"$pattern"* ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (unexpected '$pattern' in: '$actual')"; FAIL=$((FAIL + 1))
  fi
}

assert_exit() {
  local expected_code="$1" label="$2"
  shift 2
  local actual_code=0
  "$@" 2>/dev/null && actual_code=0 || actual_code=$?
  if [[ "$actual_code" == "$expected_code" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (exit: got $actual_code, want $expected_code)"; FAIL=$((FAIL + 1))
  fi
}

# Set up a monorepo with two plugins
REPO="$TMPDIR_TEST/repo"
mkdir -p "$REPO/plugins/plugin-a/.claude-plugin"
mkdir -p "$REPO/plugins/plugin-b/.claude-plugin"
mkdir -p "$REPO/.claude-plugin"

git init "$REPO" >/dev/null 2>&1
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"

cat > "$REPO/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "test-marketplace",
  "owner": {"name": "Test"},
  "plugins": [
    {"name": "plugin-a", "version": "1.0.0", "source": "./plugins/plugin-a", "description": "A"},
    {"name": "plugin-b", "version": "1.0.0", "source": "./plugins/plugin-b", "description": "B"}
  ]
}
JSON

printf '{"version": "1.0.0", "name": "plugin-a"}\n' > "$REPO/plugins/plugin-a/.claude-plugin/plugin.json"
printf '{"version": "1.0.0", "name": "plugin-b"}\n' > "$REPO/plugins/plugin-b/.claude-plugin/plugin.json"
git -C "$REPO" add .
git -C "$REPO" commit -m "initial" >/dev/null 2>&1
git -C "$REPO" tag "plugin-a/v1.0.0"
git -C "$REPO" tag "plugin-b/v1.0.0"

# ---- Test 1: no unreleased changes → empty stdout, exit 0 ----
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
assert_eq "$out" "" "no unreleased changes → empty output"
assert_exit 0 "no unreleased changes → exit 0" bash "$SCRIPT" "$REPO"

# ---- Test 2: add commit to plugin-a → plugin-a appears, plugin-b does not ----
echo "change" >> "$REPO/plugins/plugin-a/.claude-plugin/plugin.json"
git -C "$REPO" add .
git -C "$REPO" commit -m "feat: update plugin-a" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
assert_contains "$out" "plugin-a" "plugin-a with unreleased commit appears"
assert_not_contains "$out" "plugin-b" "plugin-b (unchanged) not in output"

# ---- Test 3: TSV format — 4 fields: name, version, count, last-tag ----
fields=$(echo "$out" | awk -F'\t' '{print NF}')
assert_eq "$fields" "4" "output has 4 TSV fields"

# ---- Test 4: both plugins changed → both appear ----
echo "change" >> "$REPO/plugins/plugin-b/.claude-plugin/plugin.json"
git -C "$REPO" add .
git -C "$REPO" commit -m "fix: update plugin-b" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
assert_contains "$out" "plugin-a" "both changed: plugin-a present"
assert_contains "$out" "plugin-b" "both changed: plugin-b present"

# ---- Test 5: no marketplace.json → exit 1 ----
assert_exit 1 "no marketplace.json → exit 1" bash "$SCRIPT" "/tmp"

# ---- Test 6: single-plugin marketplace (< 2) → exit 1 (not a monorepo) ----
REPO2="$TMPDIR_TEST/single"
mkdir -p "$REPO2/.claude-plugin"
cat > "$REPO2/.claude-plugin/marketplace.json" <<'JSON'
{
  "name": "single",
  "owner": {"name": "Test"},
  "plugins": [{"name": "only", "version": "1.0.0", "source": "./plugins/only", "description": "D"}]
}
JSON
git init "$REPO2" >/dev/null 2>&1
assert_exit 1 "single-plugin marketplace → exit 1 (not monorepo)" bash "$SCRIPT" "$REPO2"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
