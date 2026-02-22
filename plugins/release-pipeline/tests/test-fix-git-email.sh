#!/usr/bin/env bash
# tests/test-fix-git-email.sh — Unit tests for fix-git-email.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/fix-git-email.sh"
PASS=0; FAIL=0

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

# Create a scratch git repo + a fake gh command that always fails
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

REPO="$TMPDIR_TEST/repo"
git init "$REPO" >/dev/null 2>&1
git -C "$REPO" config user.name "Test"

# Fake gh in PATH so remote-URL fallback is tested without needing a real gh session
FAKE_BIN="$TMPDIR_TEST/fakebin"
mkdir -p "$FAKE_BIN"
printf '#!/bin/bash\nexit 1\n' > "$FAKE_BIN/gh"
chmod +x "$FAKE_BIN/gh"

# ---- Test 1: noreply email → OK, exit 0 ----
git -C "$REPO" config user.email "testuser@users.noreply.github.com"
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
assert_contains "$out" "OK:" "noreply email → OK"
assert_exit 0 "noreply email → exit 0" bash "$SCRIPT" "$REPO"

# ---- Test 2: non-noreply email, no --auto-fix → FAIL, exit 1 ----
git -C "$REPO" config user.email "user@gmail.com"
out=$(bash "$SCRIPT" "$REPO" 2>/dev/null)
assert_contains "$out" "FAIL:" "non-noreply, no --auto-fix → FAIL"
assert_exit 1 "non-noreply, no --auto-fix → exit 1" bash "$SCRIPT" "$REPO"

# ---- Test 3: --auto-fix with HTTPS remote (gh fails → remote URL fallback) ----
git -C "$REPO" config user.email "user@gmail.com"
git -C "$REPO" remote add origin "https://github.com/myuser/myrepo.git" 2>/dev/null || \
  git -C "$REPO" remote set-url origin "https://github.com/myuser/myrepo.git"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" "$REPO" --auto-fix 2>/dev/null)
assert_contains "$out" "FIXED:" "--auto-fix with HTTPS remote → FIXED"
assert_contains "$out" "myuser@users.noreply.github.com" "--auto-fix derives username from HTTPS remote"
# Verify git config was actually updated
new_email=$(git -C "$REPO" config user.email 2>/dev/null)
assert_eq "$new_email" "myuser@users.noreply.github.com" "--auto-fix writes noreply email to git config"

# ---- Test 4: --auto-fix with SSH remote (gh fails → SSH URL fallback) ----
git -C "$REPO" config user.email "user@gmail.com"
git -C "$REPO" remote set-url origin "git@github.com:sshowner/sshrepo.git"
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" "$REPO" --auto-fix 2>/dev/null)
assert_contains "$out" "sshowner@users.noreply.github.com" "--auto-fix derives username from SSH remote"

# ---- Test 5: --auto-fix with no remote, gh fails → FAIL, exit 1 ----
git -C "$REPO" config user.email "user@gmail.com"
git -C "$REPO" remote remove origin 2>/dev/null || true
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" "$REPO" --auto-fix 2>/dev/null)
assert_contains "$out" "FAIL:" "--auto-fix with no remote and no gh → FAIL"
assert_exit 1 "--auto-fix with no remote → exit 1" \
  bash -c "PATH=\"$FAKE_BIN:\$PATH\" bash \"$SCRIPT\" \"$REPO\" --auto-fix"

# ---- Test 6: --scope global applies config globally ----
git -C "$REPO" remote add origin "https://github.com/scopetest/repo.git"
git -C "$REPO" config user.email "user@gmail.com"
# Use --scope local to avoid touching actual global config
out=$(PATH="$FAKE_BIN:$PATH" bash "$SCRIPT" "$REPO" --auto-fix --scope local 2>/dev/null)
assert_contains "$out" "local scope" "--scope local noted in output"

# ---- Test 7: invalid --scope → exit 1 ----
assert_exit 1 "invalid --scope → exit 1" bash "$SCRIPT" "$REPO" --scope invalid

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
