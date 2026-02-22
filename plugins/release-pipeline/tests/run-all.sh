#!/usr/bin/env bash
# tests/run-all.sh — Run all release-pipeline test scripts and report aggregate results.
#
# Usage: bash tests/run-all.sh [--filter <pattern>]
#   --filter: only run test files matching the pattern (e.g. "api-retry")
#
# Each test-*.sh script exits 0 on all-pass, 1 on any failure.
# This runner prints per-script headers, aggregates totals, and exits 1 if any fail.

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter) FILTER="$2"; shift 2 ;;
    *)        echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

PASS=0
FAIL=0
FAILED_SCRIPTS=()

for test_script in "$TESTS_DIR"/test-*.sh; do
  [[ -f "$test_script" ]] || continue
  script_name=$(basename "$test_script")

  # Apply filter if specified
  if [[ -n "$FILTER" && "$script_name" != *"$FILTER"* ]]; then
    continue
  fi

  echo "=== $script_name ==="
  if bash "$test_script"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_SCRIPTS+=("$script_name")
  fi
  echo ""
done

echo "=============================="
echo "SUITE RESULTS: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed scripts:"
  for s in "${FAILED_SCRIPTS[@]}"; do
    echo "  ✗ $s"
  done
  exit 1
fi

exit 0
