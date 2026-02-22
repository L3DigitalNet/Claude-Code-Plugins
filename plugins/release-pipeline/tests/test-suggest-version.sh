#!/usr/bin/env bash
# tests/test-suggest-version.sh — Unit tests for suggest-version.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/suggest-version.sh"
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

setup_repo() {
  local dir="$1"
  git init "$dir" >/dev/null 2>&1
  git -C "$dir" config user.email "test@example.com"
  git -C "$dir" config user.name "Test"
  echo "init" > "$dir/file.txt"
  git -C "$dir" add .
  git -C "$dir" commit -m "initial" >/dev/null 2>&1
}

# ---- Test 1: fix commits only → patch bump ----
REPO="$TMPDIR_TEST/repo1"
setup_repo "$REPO"
git -C "$REPO" tag v1.2.3
git -C "$REPO" commit --allow-empty -m "fix: something" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
version=$(echo "$out" | awk '{print $1}')
assert_eq "$version" "1.2.4" "fix only → patch bump (1.2.3 → 1.2.4)"

# ---- Test 2: feat commit → minor bump, patch resets ----
REPO="$TMPDIR_TEST/repo2"
setup_repo "$REPO"
git -C "$REPO" tag v1.2.3
git -C "$REPO" commit --allow-empty -m "feat: add something" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
version=$(echo "$out" | awk '{print $1}')
assert_eq "$version" "1.3.0" "feat → minor bump (1.2.3 → 1.3.0)"

# ---- Test 3: breaking change (feat!) → major bump ----
REPO="$TMPDIR_TEST/repo3"
setup_repo "$REPO"
git -C "$REPO" tag v1.2.3
git -C "$REPO" commit --allow-empty -m "feat!: breaking change" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
version=$(echo "$out" | awk '{print $1}')
assert_eq "$version" "2.0.0" "breaking change (feat!) → major bump (1.2.3 → 2.0.0)"

# ---- Test 4: BREAKING CHANGE in message → major bump ----
REPO="$TMPDIR_TEST/repo4"
setup_repo "$REPO"
git -C "$REPO" tag v2.1.0
git -C "$REPO" commit --allow-empty -m "refactor: BREAKING CHANGE drops old API" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
version=$(echo "$out" | awk '{print $1}')
assert_eq "$version" "3.0.0" "BREAKING CHANGE in body → major bump (2.1.0 → 3.0.0)"

# ---- Test 5: no previous tag → default base 0.1.0, patch bump ----
REPO="$TMPDIR_TEST/repo5"
setup_repo "$REPO"
git -C "$REPO" commit --allow-empty -m "fix: initial fix" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
version=$(echo "$out" | awk '{print $1}')
assert_eq "$version" "0.1.1" "no tag → default base 0.1.0, patch bump"

# ---- Test 6: --plugin scopes suggestion to plugin path ----
REPO="$TMPDIR_TEST/repo6"
setup_repo "$REPO"
mkdir -p "$REPO/plugins/myplugin"
echo "plugin v1" > "$REPO/plugins/myplugin/file.txt"
git -C "$REPO" add .
git -C "$REPO" commit -m "feat: initial plugin" >/dev/null 2>&1
git -C "$REPO" tag "myplugin/v1.0.0"
echo "plugin v2" > "$REPO/plugins/myplugin/file.txt"
git -C "$REPO" add .
git -C "$REPO" commit -m "fix(myplugin): fix within plugin" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" --plugin myplugin 2>/dev/null)
version=$(echo "$out" | awk '{print $1}')
assert_eq "$version" "1.0.1" "--plugin: patch bump scoped to plugin commits"

# ---- Test 7: commit counts reported correctly ----
REPO="$TMPDIR_TEST/repo7"
setup_repo "$REPO"
git -C "$REPO" tag v1.0.0
git -C "$REPO" commit --allow-empty -m "feat: f1" >/dev/null 2>&1
git -C "$REPO" commit --allow-empty -m "feat: f2" >/dev/null 2>&1
git -C "$REPO" commit --allow-empty -m "fix: f3" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
feat_count=$(echo "$out" | awk '{print $2}')
fix_count=$(echo "$out" | awk '{print $3}')
assert_eq "$feat_count" "2" "feat count = 2"
assert_eq "$fix_count" "1" "fix count = 1"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
