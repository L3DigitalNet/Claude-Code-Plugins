#!/bin/bash
# Run all tests for HA Dev Plugin
#
# Usage:
#   bash tests/run_tests.sh              # Run all (auto-detect HA)
#   bash tests/run_tests.sh --skip-ha    # Skip MCP e2e tests
#   bash tests/run_tests.sh --ha-only    # Only MCP e2e tests
#   bash tests/run_tests.sh --coverage   # Include coverage reporting
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/.."

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
SKIP_HA=false
HA_ONLY=false
COVERAGE=false
for arg in "$@"; do
    case "$arg" in
        --skip-ha)  SKIP_HA=true ;;
        --ha-only)  HA_ONLY=true ;;
        --coverage) COVERAGE=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --skip-ha    Skip MCP e2e tests (no HA required)"
            echo "  --ha-only    Only run MCP e2e tests"
            echo "  --coverage   Include coverage reporting"
            exit 0
            ;;
    esac
done

echo "========================================"
echo "  Home Assistant Dev Plugin Test Suite"
echo "========================================"
echo ""

# Track results
PASSED=0
FAILED=0
SKIPPED=0

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

skip_test() {
    local name="$1"
    local reason="$2"
    echo -e "Skipping $name... ${YELLOW}$reason${NC}"
    ((SKIPPED++))
}

# Check HA availability
check_ha_available() {
    if curl -sf http://localhost:8123/api/ > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Determine HA availability once
HA_AVAILABLE=false
if [ "$SKIP_HA" = "false" ]; then
    if check_ha_available; then
        HA_AVAILABLE=true
        echo -e "Home Assistant: ${GREEN}DETECTED${NC} (http://localhost:8123)"
    else
        echo -e "Home Assistant: ${YELLOW}NOT DETECTED${NC} (MCP e2e tests will be skipped)"
    fi
else
    echo -e "Home Assistant: ${YELLOW}SKIPPED${NC} (--skip-ha)"
fi
echo ""

# Check dependencies
echo "Checking dependencies..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 not found${NC}"
    exit 1
fi

if ! python3 -c "import pytest" 2>/dev/null; then
    echo -e "${YELLOW}Installing pytest...${NC}"
    pip install pytest pytest-asyncio pytest-cov pyyaml -q
fi

if [ "$HA_ONLY" = "true" ]; then
    # Jump straight to HA tests
    if [ "$HA_AVAILABLE" = "false" ]; then
        echo -e "${RED}HA not available. Start HA first or use: scripts/setup-test-ha.sh setup${NC}"
        exit 1
    fi
else
    # ==========================================
    # Python Unit Tests
    # ==========================================
    echo ""
    echo -e "${BLUE}=== Python Unit Tests ===${NC}"

    PYTEST_OPTS="-v -x --tb=short"
    if [ "$COVERAGE" = "true" ]; then
        PYTEST_OPTS="$PYTEST_OPTS --cov=scripts --cov-report=term-missing"
    fi

    run_test "validate-manifest tests" \
        "cd '$PLUGIN_DIR' && python3 -m pytest tests/scripts/test_validate_manifest.py $PYTEST_OPTS 2>/dev/null"
    run_test "check-patterns tests" \
        "cd '$PLUGIN_DIR' && python3 -m pytest tests/scripts/test_check_patterns.py $PYTEST_OPTS 2>/dev/null"
    run_test "IQS validation tests" \
        "cd '$PLUGIN_DIR' && python3 -m pytest tests/validation/test_iqs_accuracy.py $PYTEST_OPTS 2>/dev/null"

    # ==========================================
    # Structural Validation
    # ==========================================
    echo ""
    echo -e "${BLUE}=== Plugin Structure Validation ===${NC}"

    if [ -f "$PLUGIN_DIR/tests/test_plugin_structure.py" ]; then
        run_test "Skill structure (19 skills)" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k skill 2>/dev/null"
        run_test "Agent structure (3 agents)" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k agent 2>/dev/null"
        run_test "Hooks integrity" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k hook 2>/dev/null"
        run_test "Example integrations" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k example 2>/dev/null"
        run_test "MCP server structure" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k mcp 2>/dev/null"
    else
        # Fallback to basic checks
        run_test "YAML frontmatter" \
            "cd '$PLUGIN_DIR' && for skill in skills/*/SKILL.md; do head -1 \"\$skill\" | grep -q '^---' || exit 1; done"
        run_test "Skill count (19)" \
            "cd '$PLUGIN_DIR' && test \$(ls -1 skills/ | wc -l) -eq 19"
    fi

    # ==========================================
    # Integration Tests
    # ==========================================
    echo ""
    echo -e "${BLUE}=== Integration Tests ===${NC}"

    run_test "Scripts against examples" \
        "cd '$PLUGIN_DIR' && bash tests/integration/test_scripts_against_examples.sh"

    echo ""
    echo -e "${BLUE}=== Example Validation ===${NC}"

    for example in polling-hub minimal-sensor push-integration; do
        run_test "$example manifest" \
            "cd '$PLUGIN_DIR' && python3 scripts/validate-manifest.py examples/$example/custom_components/*/manifest.json"
    done

    # ==========================================
    # TypeScript Tests
    # ==========================================
    echo ""
    echo -e "${BLUE}=== TypeScript Tests ===${NC}"

    if [ -d "$PLUGIN_DIR/mcp-server/node_modules" ]; then
        if [ "$COVERAGE" = "true" ]; then
            run_test "MCP server tests (with coverage)" \
                "cd '$PLUGIN_DIR/mcp-server' && npm run test:coverage"
        else
            run_test "MCP server tests" \
                "cd '$PLUGIN_DIR/mcp-server' && npm test"
        fi
        run_test "MCP server typecheck" \
            "cd '$PLUGIN_DIR/mcp-server' && npm run typecheck"
    else
        skip_test "TypeScript tests" "run 'npm install' in mcp-server/"
    fi
fi

# ==========================================
# MCP E2E Tests (Requires Home Assistant)
# ==========================================
echo ""
echo -e "${BLUE}=== MCP E2E Tests ===${NC}"

if [ "$HA_AVAILABLE" = "true" ]; then
    # Ensure MCP server is built
    if [ ! -d "$PLUGIN_DIR/mcp-server/dist" ]; then
        echo -e "${YELLOW}Building MCP server...${NC}"
        (cd "$PLUGIN_DIR/mcp-server" && npx tsc) || {
            echo -e "${RED}MCP server build failed${NC}"
            ((FAILED++))
        }
    fi

    if [ -d "$PLUGIN_DIR/mcp-server/dist" ]; then
        run_test "MCP REST API tests (24 checks)" \
            "cd '$PLUGIN_DIR' && node tests/e2e/test-mcp-rest.mjs"
        run_test "MCP WebSocket tests (39 checks)" \
            "cd '$PLUGIN_DIR' && node tests/e2e/test-mcp-websocket.mjs"
    fi
else
    skip_test "MCP REST API tests" "No HA instance (use scripts/setup-test-ha.sh setup)"
    skip_test "MCP WebSocket tests" "No HA instance"
fi

# ==========================================
# Summary
# ==========================================
echo ""
echo "========================================"
TOTAL=$((PASSED + FAILED))
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$SKIPPED skipped${NC} (of $TOTAL)"
echo "========================================"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
