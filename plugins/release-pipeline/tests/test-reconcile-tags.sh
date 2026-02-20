#!/usr/bin/env bash
# tests/test-reconcile-tags.sh — Unit tests for reconcile-tags.sh
# Mocks git by overriding it as a function in each test's subshell.
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/reconcile-tags.sh"
PASS=0; FAIL=0

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "  ✓ $label"; PASS=$((PASS + 1))
  else
    echo "  ✗ $label (got: '$actual', want: '$expected')"; FAIL=$((FAIL + 1))
  fi
}

# ---- Test 1: MISSING — tag absent locally and remotely ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo ""; else echo ""; fi
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "MISSING" "MISSING when tag absent everywhere"

# ---- Test 2: LOCAL_ONLY — tag only local ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo "v1.0.0"; else echo ""; fi
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "LOCAL_ONLY" "LOCAL_ONLY when tag only local"

# ---- Test 3: BOTH — tag on local and remote ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo "v1.0.0"
    elif [[ "$*" == *"ls-remote"* ]]; then printf "abc123 refs/tags/v1.0.0\nabc123 refs/tags/v1.0.0^{}\n"; fi
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "BOTH" "BOTH when tag on local and remote"

# ---- Test 4: REMOTE_ONLY — fetches and returns REMOTE_ONLY ----
result=$(
  git() {
    if [[ "$*" == *"tag -l"* ]]; then echo ""
    elif [[ "$*" == *"ls-remote"* ]]; then printf "abc123 refs/tags/v1.0.0\nabc123 refs/tags/v1.0.0^{}\n"
    elif [[ "$*" == *"fetch"* ]]; then echo ""; fi  # fetch succeeds
  }
  export -f git
  bash "$SCRIPT" /tmp v1.0.0 2>/dev/null
)
assert_eq "$(echo "$result" | head -1)" "REMOTE_ONLY" "REMOTE_ONLY triggers auto-fetch"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
