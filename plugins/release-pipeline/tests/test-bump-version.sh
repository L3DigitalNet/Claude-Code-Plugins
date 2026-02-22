#!/usr/bin/env bash
# tests/test-bump-version.sh — Unit tests for bump-version.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/bump-version.sh"
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

# ---- Test 1: bumps plugin.json ----
REPO="$TMPDIR_TEST/repo1"
mkdir -p "$REPO/.claude-plugin"
printf '{"version": "1.0.0", "name": "test"}\n' > "$REPO/.claude-plugin/plugin.json"
out=$(bash "$SCRIPT" "$REPO" 2.0.0 2>/dev/null)
assert_contains "$out" "plugin.json" "bump plugin.json: file reported in output"
content=$(< "$REPO/.claude-plugin/plugin.json")
assert_contains "$content" '"2.0.0"' "bump plugin.json: version string updated"

# ---- Test 2: --dry-run does not write ----
REPO="$TMPDIR_TEST/repo2"
mkdir -p "$REPO/.claude-plugin"
printf '{"version": "1.0.0", "name": "test"}\n' > "$REPO/.claude-plugin/plugin.json"
out=$(bash "$SCRIPT" "$REPO" 3.0.0 --dry-run 2>/dev/null)
assert_contains "$out" "Would update:" "--dry-run: reports would-change"
content=$(< "$REPO/.claude-plugin/plugin.json")
assert_contains "$content" '"1.0.0"' "--dry-run: original file unchanged"

# ---- Test 3: no version strings → exit 1 ----
REPO="$TMPDIR_TEST/repo3"
mkdir -p "$REPO"
echo "no version here" > "$REPO/README.md"
assert_exit 1 "no version strings → exit 1" bash "$SCRIPT" "$REPO" 1.0.0

# ---- Test 4: monorepo --plugin bumps plugin.json and marketplace.json ----
REPO="$TMPDIR_TEST/repo4"
mkdir -p "$REPO/plugins/my-plugin/.claude-plugin"
mkdir -p "$REPO/.claude-plugin"
printf '{"version": "0.1.0", "name": "my-plugin"}\n' \
  > "$REPO/plugins/my-plugin/.claude-plugin/plugin.json"
printf '{"name":"test","plugins":[{"name":"my-plugin","version":"0.1.0","source":"./plugins/my-plugin","description":"D"}]}\n' \
  > "$REPO/.claude-plugin/marketplace.json"
bash "$SCRIPT" "$REPO" 0.2.0 --plugin my-plugin 2>/dev/null
pjson=$(< "$REPO/plugins/my-plugin/.claude-plugin/plugin.json")
assert_contains "$pjson" '"0.2.0"' "--plugin: plugin.json version updated"
mktplace=$(< "$REPO/.claude-plugin/marketplace.json")
assert_contains "$mktplace" '"0.2.0"' "--plugin: marketplace.json version updated"

# ---- Test 5: strips leading 'v' from version input ----
REPO="$TMPDIR_TEST/repo5"
mkdir -p "$REPO/.claude-plugin"
printf '{"version": "1.0.0"}\n' > "$REPO/.claude-plugin/plugin.json"
bash "$SCRIPT" "$REPO" v1.5.0 2>/dev/null
content=$(< "$REPO/.claude-plugin/plugin.json")
assert_contains "$content" '"1.5.0"' "strips leading 'v' from version"

# ---- Test 6: bumps pyproject.toml ----
REPO="$TMPDIR_TEST/repo6"
mkdir -p "$REPO"
printf '[tool.poetry]\nname = "myapp"\nversion = "0.3.0"\n' > "$REPO/pyproject.toml"
bash "$SCRIPT" "$REPO" 0.4.0 2>/dev/null
content=$(< "$REPO/pyproject.toml")
assert_contains "$content" '"0.4.0"' "bumps pyproject.toml"

# ---- Test 7: --plugin --dry-run reports but does not write ----
REPO="$TMPDIR_TEST/repo7"
mkdir -p "$REPO/plugins/myplugin/.claude-plugin"
mkdir -p "$REPO/.claude-plugin"
printf '{"version": "1.0.0", "name": "myplugin"}\n' \
  > "$REPO/plugins/myplugin/.claude-plugin/plugin.json"
printf '{"name":"t","plugins":[{"name":"myplugin","version":"1.0.0","source":"./plugins/myplugin","description":"D"}]}\n' \
  > "$REPO/.claude-plugin/marketplace.json"
out=$(bash "$SCRIPT" "$REPO" 2.0.0 --plugin myplugin --dry-run 2>/dev/null)
assert_contains "$out" "Would update:" "--plugin --dry-run: reports would-change"
pjson=$(< "$REPO/plugins/myplugin/.claude-plugin/plugin.json")
assert_contains "$pjson" '"1.0.0"' "--plugin --dry-run: plugin.json not changed"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
