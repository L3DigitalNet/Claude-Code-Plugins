#!/usr/bin/env bash
# tests/test-auto-stash.sh — Unit tests for auto-stash.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/auto-stash.sh"
PASS=0; FAIL=0

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
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
    echo "  ✗ $label (exit code: got $actual_code, want $expected_code)"; FAIL=$((FAIL + 1))
  fi
}

# Create a scratch git repo for tests
TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

REPO="$TMPDIR_TEST/repo"
git init "$REPO" >/dev/null 2>&1
git -C "$REPO" config user.email "test@example.com"
git -C "$REPO" config user.name "Test"
echo "initial" > "$REPO/file.txt"
git -C "$REPO" add .
git -C "$REPO" commit -m "initial commit" >/dev/null 2>&1

# ---- Test 1: check on clean repo → CLEAN ----
out=$(bash "$SCRIPT" "$REPO" check 2>/dev/null)
assert_eq "$out" "CLEAN" "check: clean repo → CLEAN"

# ---- Test 2: stash on clean repo → CLEAN (no-op) ----
out=$(bash "$SCRIPT" "$REPO" stash 2>/dev/null)
assert_eq "$out" "CLEAN" "stash: clean repo → CLEAN"

# ---- Test 3: check on dirty repo → DIRTY ----
echo "dirty change" >> "$REPO/file.txt"
out=$(bash "$SCRIPT" "$REPO" check 2>/dev/null)
assert_eq "$out" "DIRTY" "check: dirty repo → DIRTY"

# ---- Test 4: stash on dirty repo → STASHED ----
out=$(bash "$SCRIPT" "$REPO" stash 2>/dev/null)
assert_eq "$out" "STASHED" "stash: dirty repo → STASHED"

# ---- Test 5: check after stash → CLEAN ----
out=$(bash "$SCRIPT" "$REPO" check 2>/dev/null)
assert_eq "$out" "CLEAN" "check: after stash → CLEAN"

# ---- Test 6: pop after stash → RESTORED ----
out=$(bash "$SCRIPT" "$REPO" pop 2>/dev/null)
assert_eq "$out" "RESTORED" "pop: restores stashed changes"

# ---- Test 7: check after pop → DIRTY again ----
out=$(bash "$SCRIPT" "$REPO" check 2>/dev/null)
assert_eq "$out" "DIRTY" "check: after pop → DIRTY again"

# Reset for next tests
git -C "$REPO" checkout -- . 2>/dev/null

# ---- Test 8: pop when no stash → NO_STASH (no error) ----
out=$(bash "$SCRIPT" "$REPO" pop 2>/dev/null)
assert_eq "$out" "NO_STASH" "pop: no stash → NO_STASH (graceful)"

# ---- Test 9: unknown command → exit 1 ----
assert_exit 1 "unknown command → exit 1" bash "$SCRIPT" "$REPO" unknown

# ---- Test 10: stash captures untracked files ----
echo "new_untracked_file" > "$REPO/untracked.txt"
out=$(bash "$SCRIPT" "$REPO" stash 2>/dev/null)
assert_eq "$out" "STASHED" "stash: includes untracked files"

if [[ ! -f "$REPO/untracked.txt" ]]; then
  echo "  ✓ untracked file was stashed (no longer present)"; PASS=$((PASS + 1))
else
  echo "  ✗ untracked file was NOT stashed (still present)"; FAIL=$((FAIL + 1))
fi

out=$(bash "$SCRIPT" "$REPO" pop 2>/dev/null)
if [[ -f "$REPO/untracked.txt" ]]; then
  echo "  ✓ untracked file restored after pop"; PASS=$((PASS + 1))
else
  echo "  ✗ untracked file NOT restored after pop"; FAIL=$((FAIL + 1))
fi

# ---- Test 11: does not pop a non-release-pipeline stash ----
echo "user stash change" >> "$REPO/file.txt"
# Create a stash WITHOUT our marker
git -C "$REPO" stash push -m "user-created stash: manual work" >/dev/null 2>&1
out=$(bash "$SCRIPT" "$REPO" pop 2>/dev/null)
assert_eq "$out" "NO_STASH" "pop: does not touch non-release-pipeline stash"
# User's stash should still exist
stash_count=$(git -C "$REPO" stash list 2>/dev/null | wc -l)
if [[ "$stash_count" -ge 1 ]]; then
  echo "  ✓ user stash preserved (not popped)"; PASS=$((PASS + 1))
else
  echo "  ✗ user stash was incorrectly popped"; FAIL=$((FAIL + 1))
fi
git -C "$REPO" stash drop 2>/dev/null || true

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
