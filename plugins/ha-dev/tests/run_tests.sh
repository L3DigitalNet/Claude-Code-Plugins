#!/bin/bash
# Run all tests for HA Dev Plugin
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/.."

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================"
echo "  Home Assistant Dev Plugin Test Suite"
echo "========================================"
echo ""

# Track results
PASSED=0
FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    
    echo -n "Running $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}FAILED${NC}"
        ((FAILED++))
        # Show output on failure
        echo "  Command: $cmd"
        eval "$cmd" 2>&1 | head -20 | sed 's/^/  /'
    fi
}

# Check dependencies
echo "Checking dependencies..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 not found${NC}"
    exit 1
fi

if ! python3 -c "import pytest" 2>/dev/null; then
    echo -e "${YELLOW}Installing pytest...${NC}"
    pip install pytest pytest-asyncio -q
fi

echo ""
echo "=== Python Unit Tests ==="
run_test "validate-manifest tests" "cd '$PLUGIN_DIR' && python3 -m pytest tests/scripts/test_validate_manifest.py -v -x 2>/dev/null"
run_test "check-patterns tests" "cd '$PLUGIN_DIR' && python3 -m pytest tests/scripts/test_check_patterns.py -v -x 2>/dev/null"
run_test "IQS validation tests" "cd '$PLUGIN_DIR' && python3 -m pytest tests/validation/test_iqs_accuracy.py -v -x 2>/dev/null"

echo ""
echo "=== Integration Tests ==="
run_test "Scripts against examples" "cd '$PLUGIN_DIR' && bash tests/integration/test_scripts_against_examples.sh"

echo ""
echo "=== Skill Validation ==="
run_test "YAML frontmatter" "cd '$PLUGIN_DIR' && for skill in skills/*/SKILL.md; do head -1 \"\$skill\" | grep -q '^---' || exit 1; done"
run_test "Skill count consistency" "cd '$PLUGIN_DIR' && test \$(ls -1 skills/ | wc -l) -eq \$(grep -oE '[0-9]+ Agent Skills' README.md | grep -oE '[0-9]+')"

echo ""
echo "=== Example Validation ==="
for example in polling-hub minimal-sensor push-integration; do
    run_test "$example manifest" "cd '$PLUGIN_DIR' && python3 scripts/validate-manifest.py examples/$example/custom_components/*/manifest.json"
done

echo ""
echo "=== TypeScript Tests ==="
if [ -d "$PLUGIN_DIR/mcp-server/node_modules" ]; then
    run_test "MCP server tests" "cd '$PLUGIN_DIR/mcp-server' && npm test"
    run_test "MCP server typecheck" "cd '$PLUGIN_DIR/mcp-server' && npm run typecheck"
else
    echo -e "${YELLOW}Skipping TypeScript tests (run 'npm install' in mcp-server/)${NC}"
fi

echo ""
echo "========================================"
echo "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}"
echo "========================================"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
