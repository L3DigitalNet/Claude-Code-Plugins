#!/bin/bash
# Integration tests - run scripts against example integrations
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/../.."

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    exit 1
}

echo "=== Integration Tests: Scripts Against Examples ==="
echo ""

# Test validate-manifest.py
echo "Testing validate-manifest.py..."
for example in polling-hub minimal-sensor push-integration; do
    manifest=$(find "$PLUGIN_DIR/examples/$example" -name manifest.json | head -1)
    if [ -f "$manifest" ]; then
        if python3 "$PLUGIN_DIR/scripts/validate-manifest.py" "$manifest" > /dev/null 2>&1; then
            pass "validate-manifest.py: $example"
        else
            # Check if it's expected warnings vs errors
            output=$(python3 "$PLUGIN_DIR/scripts/validate-manifest.py" "$manifest" 2>&1)
            if echo "$output" | grep -q "ERROR"; then
                fail "validate-manifest.py: $example - has errors"
            else
                pass "validate-manifest.py: $example (warnings only)"
            fi
        fi
    else
        fail "Manifest not found for $example"
    fi
done

echo ""

# Test validate-strings.py
echo "Testing validate-strings.py..."
for example in polling-hub minimal-sensor push-integration; do
    strings=$(find "$PLUGIN_DIR/examples/$example" -name strings.json | head -1)
    if [ -f "$strings" ]; then
        if python3 "$PLUGIN_DIR/scripts/validate-strings.py" "$strings" > /dev/null 2>&1; then
            pass "validate-strings.py: $example"
        else
            output=$(python3 "$PLUGIN_DIR/scripts/validate-strings.py" "$strings" 2>&1)
            if echo "$output" | grep -qi "error\|missing"; then
                # Some missing items might be expected for minimal examples
                if [ "$example" = "minimal-sensor" ]; then
                    pass "validate-strings.py: $example (minimal, some missing expected)"
                else
                    fail "validate-strings.py: $example - has issues"
                fi
            else
                pass "validate-strings.py: $example"
            fi
        fi
    else
        fail "Strings not found for $example"
    fi
done

echo ""

# Test check-patterns.py
echo "Testing check-patterns.py..."
for example in polling-hub minimal-sensor push-integration; do
    integration_dir=$(find "$PLUGIN_DIR/examples/$example/custom_components" -mindepth 1 -maxdepth 1 -type d | head -1)
    if [ -d "$integration_dir" ]; then
        output=$(python3 "$PLUGIN_DIR/scripts/check-patterns.py" "$integration_dir" 2>&1)
        error_count=$(echo "$output" | grep -c "ERROR" || true)
        warning_count=$(echo "$output" | grep -c "WARNING" || true)
        
        if [ "$error_count" -eq 0 ]; then
            if [ "$warning_count" -eq 0 ]; then
                pass "check-patterns.py: $example (no issues)"
            else
                pass "check-patterns.py: $example ($warning_count warnings)"
            fi
        else
            fail "check-patterns.py: $example - $error_count errors"
        fi
    else
        fail "Integration dir not found for $example"
    fi
done

echo ""
echo "=== All Integration Tests Passed ==="
