#!/usr/bin/env bash
# Run all claude-sync tests
set -uo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0; TOTAL_FAIL=0; SCRIPTS=0

for test_file in "$DIR"/test-*.sh; do
    [ -f "$test_file" ] || continue
    echo ""
    SCRIPTS=$((SCRIPTS + 1))
    if bash "$test_file"; then
        : # test script exited 0
    else
        TOTAL_FAIL=$((TOTAL_FAIL + 1))
    fi
done

echo ""
echo "======================================="
echo "Ran $SCRIPTS test scripts"
if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo "All scripts passed"
else
    echo "$TOTAL_FAIL script(s) had failures"
fi
echo "======================================="
[[ $TOTAL_FAIL -eq 0 ]]
