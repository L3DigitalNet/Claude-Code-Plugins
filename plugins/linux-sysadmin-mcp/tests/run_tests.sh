#!/usr/bin/env bash
# =============================================================================
# linux-sysadmin-mcp — Self-Test Runner
#
# Orchestrates the 5-layer test suite with container lifecycle management.
#
# Usage:
#   bash tests/run_tests.sh              # Run all (auto-manage container)
#   bash tests/run_tests.sh --unit-only  # Layers 1, 4 unit, 5 only (no container)
#   bash tests/run_tests.sh --skip-container  # Skip container-dependent tests
#   bash tests/run_tests.sh --container-only  # Only container tests (layers 2, 3, 4 e2e)
#   bash tests/run_tests.sh --fresh      # Rebuild and recreate container
#   bash tests/run_tests.sh --help       # Show this help
# =============================================================================
set -euo pipefail

# ---------------------------------------------------------------------------
# Resolve paths (works whether invoked from plugin root or tests/)
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTAINER_DIR="$SCRIPT_DIR/container"
CONTAINER_NAME="linux-sysadmin-test"

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Counters (use safe arithmetic for set -e)
# ---------------------------------------------------------------------------
PASSED=0
FAILED=0
SKIPPED=0

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
MODE="all"  # all | unit-only | skip-container | container-only | fresh

show_help() {
    cat <<'HELP'
linux-sysadmin-mcp Test Runner

Usage:
  bash tests/run_tests.sh [OPTIONS]

Options:
  --unit-only         Run host-only tests (Layers 1, 4 unit, 5). No container.
  --skip-container    Run all host tests, skip container-dependent tests.
  --container-only    Run only container tests (Layers 2, 3, 4 e2e).
  --fresh             Rebuild container from scratch, then run all tests.
  --help              Show this help message.

Test Layers:
  Layer 1  Structural Validation    (pytest)    — host
  Layer 2  MCP Startup              (node e2e)  — container
  Layer 3  Tool Smoke Tests         (node e2e)  — container
  Layer 4  Safety Gate              (node unit + e2e) — host + container
  Layer 5  Knowledge Base           (node unit) — host
HELP
}

for arg in "$@"; do
    case "$arg" in
        --unit-only)
            MODE="unit-only"
            ;;
        --skip-container)
            MODE="skip-container"
            ;;
        --container-only)
            MODE="container-only"
            ;;
        --fresh)
            MODE="fresh"
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $arg${NC}"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
check_dependencies() {
    local missing=0

    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}Missing dependency: python3${NC}"
        missing=$((missing + 1))
    fi

    if ! command -v node &>/dev/null; then
        echo -e "${RED}Missing dependency: node${NC}"
        missing=$((missing + 1))
    fi

    if [[ "$MODE" != "unit-only" && "$MODE" != "skip-container" ]]; then
        if ! command -v podman &>/dev/null; then
            echo -e "${RED}Missing dependency: podman${NC}"
            missing=$((missing + 1))
        fi
    fi

    if [ "$missing" -gt 0 ]; then
        echo -e "${RED}Install missing dependencies and try again.${NC}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Container management
# ---------------------------------------------------------------------------
container_is_running() {
    podman inspect --format '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q "true"
}

wait_for_systemd() {
    local max_attempts=30
    local attempt=0
    echo -n "  Waiting for systemd... "
    while [ "$attempt" -lt "$max_attempts" ]; do
        local status
        status=$(podman exec "$CONTAINER_NAME" systemctl is-system-running 2>/dev/null || true)
        if [[ "$status" == "running" || "$status" == "degraded" ]]; then
            echo -e "${GREEN}ready${NC} ($status)"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    echo -e "${RED}timeout after ${max_attempts}s${NC}"
    return 1
}

manage_container() {
    echo -e "\n${BLUE}${BOLD}=== Container Management ===${NC}"

    # --fresh: tear down and rebuild
    if [[ "$MODE" == "fresh" ]]; then
        echo "  Tearing down existing container..."
        (cd "$CONTAINER_DIR" && podman compose down 2>/dev/null) || true
        echo "  Rebuilding with --no-cache..."
        (cd "$CONTAINER_DIR" && podman compose build --no-cache)
    fi

    # Start container if not running
    if container_is_running; then
        echo -e "  Container ${GREEN}already running${NC}"
    else
        echo "  Starting container..."
        (cd "$CONTAINER_DIR" && podman compose up -d)
    fi

    # Wait for systemd
    if ! wait_for_systemd; then
        echo -e "${RED}  Container failed to reach running state.${NC}"
        echo "  Try: bash tests/run_tests.sh --fresh"
        return 1
    fi

    # Run fixtures
    echo -n "  Running fixtures... "
    if podman exec "$CONTAINER_NAME" bash /plugin/tests/container/setup-fixtures.sh &>/dev/null; then
        echo -e "${GREEN}done${NC}"
    else
        echo -e "${YELLOW}warning: fixtures returned non-zero (may be partial)${NC}"
    fi
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------
run_test() {
    local name="$1"
    local cmd="$2"
    echo -n "  Running $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAILED${NC}"
        FAILED=$((FAILED + 1))
        echo "    Command: $cmd"
        eval "$cmd" 2>&1 | tail -20 | sed 's/^/    /' || true
    fi
}

skip_test() {
    local name="$1"
    local reason="${2:-skipped by mode}"
    echo -e "  Skipping $name... ${YELLOW}SKIPPED${NC} ($reason)"
    SKIPPED=$((SKIPPED + 1))
}

# ---------------------------------------------------------------------------
# Layer functions
# ---------------------------------------------------------------------------
run_layer1() {
    echo -e "\n${BLUE}${BOLD}=== Layer 1: Structural Validation (pytest) ===${NC}"

    # Run test class by class for granular reporting
    local classes=(
        "TestPluginManifest"
        "TestMCPConfig"
        "TestBundleExists"
        "TestTypeScriptSources"
        "TestKnowledgeProfiles"
        "TestPackageJson"
        "TestCrossReferences"
    )

    for cls in "${classes[@]}"; do
        run_test "Layer 1 :: $cls" \
            "python3 -m pytest '$PLUGIN_ROOT/tests/test_plugin_structure.py::$cls' -v --tb=short -q"
    done
}

run_layer5() {
    echo -e "\n${BLUE}${BOLD}=== Layer 5: Knowledge Base Unit Tests (node) ===${NC}"
    run_test "Layer 5 :: Knowledge Base" \
        "node '$PLUGIN_ROOT/tests/unit/test-knowledge-base.mjs'"
}

run_layer4_unit() {
    echo -e "\n${BLUE}${BOLD}=== Layer 4: Safety Gate Unit Tests (node) ===${NC}"
    run_test "Layer 4 :: Safety Gate (unit)" \
        "node '$PLUGIN_ROOT/tests/unit/test-safety-gate.mjs'"
}

run_layer2() {
    echo -e "\n${BLUE}${BOLD}=== Layer 2: MCP Startup E2E ===${NC}"
    local test_file="$PLUGIN_ROOT/tests/e2e/test-mcp-startup.mjs"
    if [ -f "$test_file" ]; then
        run_test "Layer 2 :: MCP Startup" \
            "node '$test_file'"
    else
        skip_test "Layer 2 :: MCP Startup" "test file not yet created"
    fi
}

run_layer3() {
    echo -e "\n${BLUE}${BOLD}=== Layer 3: Tool Smoke Tests E2E ===${NC}"
    local test_file="$PLUGIN_ROOT/tests/e2e/test-mcp-tools.mjs"
    if [ -f "$test_file" ]; then
        run_test "Layer 3 :: Tool Smoke Tests" \
            "node '$test_file'"
    else
        skip_test "Layer 3 :: Tool Smoke Tests" "test file not yet created"
    fi
}

run_layer4_e2e() {
    echo -e "\n${BLUE}${BOLD}=== Layer 4: Safety Gate E2E ===${NC}"
    local test_file="$PLUGIN_ROOT/tests/e2e/test-mcp-safety.mjs"
    if [ -f "$test_file" ]; then
        run_test "Layer 4 :: Safety Gate (e2e)" \
            "node '$test_file'"
    else
        skip_test "Layer 4 :: Safety Gate (e2e)" "test file not yet created"
    fi
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
print_summary() {
    local total=$((PASSED + FAILED + SKIPPED))
    echo ""
    echo -e "${BOLD}============================================================${NC}"
    echo -e "${BOLD}  Test Summary${NC}"
    echo -e "${BOLD}============================================================${NC}"
    echo -e "  ${GREEN}Passed:  $PASSED${NC}"
    echo -e "  ${RED}Failed:  $FAILED${NC}"
    echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}"
    echo -e "  Total:   $total"
    echo -e "${BOLD}============================================================${NC}"

    if [ "$FAILED" -gt 0 ]; then
        echo -e "\n${RED}${BOLD}RESULT: FAIL${NC}"
        return 1
    elif [ "$PASSED" -eq 0 ] && [ "$SKIPPED" -gt 0 ]; then
        echo -e "\n${YELLOW}${BOLD}RESULT: NO TESTS RAN${NC}"
        return 1
    else
        echo -e "\n${GREEN}${BOLD}RESULT: PASS${NC}"
        return 0
    fi
}

# ===========================================================================
# Main
# ===========================================================================
echo -e "${BOLD}linux-sysadmin-mcp Self-Test Suite${NC}"
echo -e "Mode: ${BLUE}$MODE${NC}"
echo -e "Plugin root: $PLUGIN_ROOT"

check_dependencies

# ---------------------------------------------------------------------------
# Run layers based on mode
# ---------------------------------------------------------------------------
case "$MODE" in
    all)
        # Host tests first
        run_layer1
        run_layer5
        run_layer4_unit

        # Container tests
        manage_container
        run_layer2
        run_layer3
        run_layer4_e2e
        ;;

    unit-only)
        run_layer1
        run_layer5
        run_layer4_unit
        ;;

    skip-container)
        run_layer1
        run_layer5
        run_layer4_unit

        skip_test "Layer 2 :: MCP Startup" "--skip-container"
        skip_test "Layer 3 :: Tool Smoke Tests" "--skip-container"
        skip_test "Layer 4 :: Safety Gate (e2e)" "--skip-container"
        ;;

    container-only)
        manage_container
        run_layer2
        run_layer3
        run_layer4_e2e
        ;;

    fresh)
        # --fresh implies full run with rebuilt container
        run_layer1
        run_layer5
        run_layer4_unit

        manage_container
        run_layer2
        run_layer3
        run_layer4_e2e
        ;;
esac

# ---------------------------------------------------------------------------
# Print results and exit
# ---------------------------------------------------------------------------
print_summary
