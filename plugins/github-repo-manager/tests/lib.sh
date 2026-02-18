#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# lib.sh — Shared test utilities for gh-manager self-tests
# ─────────────────────────────────────────────────
# Source this at the top of every test script:
#   source "$(dirname "$0")/lib.sh"
# ─────────────────────────────────────────────────

set -euo pipefail

# ── Config ──────────────────────────────────────
TEST_REPO="${TEST_REPO:-L3DigitalNet/testing}"
GH_MANAGER="${GH_MANAGER:-gh-manager}"

# ── State ───────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
FAILURES=()
SKIPS=()
CURRENT_GROUP=""

# ── Colors ──────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN=''; RED=''; YELLOW=''; CYAN=''; BOLD=''; RESET=''
fi

# ── Output helpers ──────────────────────────────

group() {
  CURRENT_GROUP="$1"
  echo ""
  echo -e "${CYAN}${BOLD}── $1 ──${RESET}"
}

pass() {
  local name="$1"
  PASS_COUNT=$((PASS_COUNT + 1))
  echo -e "  ${GREEN}✓${RESET} ${name}"
}

fail() {
  local name="$1"
  local detail="${2:-}"
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURES+=("${CURRENT_GROUP}: ${name}")
  echo -e "  ${RED}✗${RESET} ${name}"
  if [[ -n "$detail" ]]; then
    echo -e "    ${RED}→ ${detail}${RESET}"
  fi
}

skip() {
  local name="$1"
  local reason="${2:-}"
  SKIP_COUNT=$((SKIP_COUNT + 1))
  SKIPS+=("${CURRENT_GROUP}: ${name} — ${reason}")
  echo -e "  ${YELLOW}○${RESET} ${name} ${YELLOW}(skipped: ${reason})${RESET}"
}

# ── Assertion helpers ───────────────────────────

# Run a command, capture stdout+stderr+exit code.
# Sets: CMD_OUT, CMD_ERR, CMD_EXIT
run() {
  CMD_OUT=""
  CMD_ERR=""
  CMD_EXIT=0
  CMD_OUT=$(eval "$@" 2>/tmp/ghm_test_stderr) || CMD_EXIT=$?
  CMD_ERR=$(cat /tmp/ghm_test_stderr 2>/dev/null || true)
}

# Assert exit code is 0
assert_ok() {
  local name="$1"
  shift
  run "$@"
  if [[ $CMD_EXIT -eq 0 ]]; then
    pass "$name"
  else
    fail "$name" "exit=$CMD_EXIT stderr=$(echo "$CMD_ERR" | head -1)"
  fi
}

# Assert exit code is non-zero
assert_fail() {
  local name="$1"
  shift
  run "$@"
  if [[ $CMD_EXIT -ne 0 ]]; then
    pass "$name"
  else
    fail "$name" "expected non-zero exit, got 0"
  fi
}

# Assert stdout contains valid JSON
assert_json() {
  local name="$1"
  shift
  run "$@"
  if [[ $CMD_EXIT -ne 0 ]]; then
    fail "$name" "exit=$CMD_EXIT (expected 0)"
    return
  fi
  if echo "$CMD_OUT" | node -e "JSON.parse(require('fs').readFileSync(0,'utf8'))" 2>/dev/null; then
    pass "$name"
  else
    fail "$name" "output is not valid JSON: $(echo "$CMD_OUT" | head -1)"
  fi
}

# Assert JSON output contains a key (top-level)
assert_json_has() {
  local name="$1"
  local key="$2"
  shift 2
  run "$@"
  if [[ $CMD_EXIT -ne 0 ]]; then
    fail "$name" "exit=$CMD_EXIT (expected 0)"
    return
  fi
  local has_key
  has_key=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    process.stdout.write(d.hasOwnProperty('$key') ? 'yes' : 'no');
  " 2>/dev/null || echo "error")
  if [[ "$has_key" == "yes" ]]; then
    pass "$name"
  else
    fail "$name" "JSON missing key '$key'"
  fi
}

# Assert JSON field equals expected value
assert_json_eq() {
  local name="$1"
  local key="$2"
  local expected="$3"
  shift 3
  run "$@"
  if [[ $CMD_EXIT -ne 0 ]]; then
    fail "$name" "exit=$CMD_EXIT (expected 0)"
    return
  fi
  local actual
  actual=$(echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    const v = d['$key'];
    process.stdout.write(String(v));
  " 2>/dev/null || echo "__ERROR__")
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected $key='$expected', got '$actual'"
  fi
}

# Assert JSON output has dry_run: true
assert_dry_run() {
  local name="$1"
  shift
  assert_json_eq "$name" "dry_run" "true" "$@"
}

# Extract a JSON field from CMD_OUT (use after run)
json_val() {
  echo "$CMD_OUT" | node -e "
    const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
    const keys = '$1'.split('.');
    let v = d;
    for (const k of keys) v = v?.[k];
    process.stdout.write(String(v ?? ''));
  " 2>/dev/null
}

# ── Summary ─────────────────────────────────────

summary() {
  echo ""
  echo -e "${BOLD}═══════════════════════════════════════${RESET}"
  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  echo -e "${BOLD}Results: ${total} tests${RESET}"
  echo -e "  ${GREEN}✓ ${PASS_COUNT} passed${RESET}"
  if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "  ${RED}✗ ${FAIL_COUNT} failed${RESET}"
  fi
  if [[ $SKIP_COUNT -gt 0 ]]; then
    echo -e "  ${YELLOW}○ ${SKIP_COUNT} skipped${RESET}"
  fi

  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    echo ""
    echo -e "${RED}${BOLD}Failures:${RESET}"
    for f in "${FAILURES[@]}"; do
      echo -e "  ${RED}• $f${RESET}"
    done
  fi

  if [[ ${#SKIPS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Skipped:${RESET}"
    for s in "${SKIPS[@]}"; do
      echo -e "  ${YELLOW}• $s${RESET}"
    done
  fi

  echo -e "${BOLD}═══════════════════════════════════════${RESET}"

  if [[ $FAIL_COUNT -gt 0 ]]; then
    return 1
  fi
  return 0
}
