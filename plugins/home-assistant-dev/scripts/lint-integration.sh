#!/bin/bash
# lint-integration.sh - Run linters on Home Assistant integration
#
# Usage: lint-integration.sh [path/to/integration]
#
# Runs:
#   - ruff check (fast Python linter)
#   - ruff format --check (formatting check)
#   - mypy (type checking, if configured)
#   - Custom pattern checks

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default to current directory or custom_components
if [ -n "$1" ]; then
    TARGET="$1"
elif [ -d "custom_components" ]; then
    TARGET="custom_components"
else
    TARGET="."
fi

echo "=========================================="
echo "Home Assistant Integration Linter"
echo "=========================================="
echo "Target: $TARGET"
echo ""

ERRORS=0
WARNINGS=0

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Run ruff check
echo "----------------------------------------"
echo "Running ruff check..."
echo "----------------------------------------"
if command_exists ruff; then
    if ruff check "$TARGET" --select=E,F,W,I,UP,B,C4,SIM; then
        echo -e "${GREEN}✓ ruff check passed${NC}"
    else
        echo -e "${RED}✗ ruff check failed${NC}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠ ruff not installed. Install with: pip install ruff${NC}"
    WARNINGS=$((WARNINGS + 1))
fi
echo ""

# Run ruff format check
echo "----------------------------------------"
echo "Running ruff format check..."
echo "----------------------------------------"
if command_exists ruff; then
    if ruff format --check "$TARGET" 2>/dev/null; then
        echo -e "${GREEN}✓ ruff format check passed${NC}"
    else
        echo -e "${YELLOW}⚠ Code is not formatted. Run: ruff format $TARGET${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}⚠ ruff not installed${NC}"
fi
echo ""

# Run mypy if pyproject.toml or mypy.ini exists
echo "----------------------------------------"
echo "Running mypy type check..."
echo "----------------------------------------"
if command_exists mypy; then
    if [ -f "pyproject.toml" ] || [ -f "mypy.ini" ] || [ -f "setup.cfg" ]; then
        if mypy "$TARGET" --ignore-missing-imports 2>/dev/null; then
            echo -e "${GREEN}✓ mypy check passed${NC}"
        else
            echo -e "${YELLOW}⚠ mypy found type errors${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        echo -e "${YELLOW}⚠ No mypy configuration found. Running with defaults...${NC}"
        mypy "$TARGET" --ignore-missing-imports --no-error-summary 2>/dev/null || true
    fi
else
    echo -e "${YELLOW}⚠ mypy not installed. Install with: pip install mypy${NC}"
fi
echo ""

# Run custom pattern checks
echo "----------------------------------------"
echo "Running anti-pattern check..."
echo "----------------------------------------"
SCRIPT_DIR="$(dirname "$0")"
if [ -f "$SCRIPT_DIR/check-patterns.py" ]; then
    if python3 "$SCRIPT_DIR/check-patterns.py" "$TARGET"; then
        echo -e "${GREEN}✓ Anti-pattern check passed${NC}"
    else
        echo -e "${YELLOW}⚠ Anti-patterns detected${NC}"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo -e "${YELLOW}⚠ check-patterns.py not found${NC}"
fi
echo ""

# Validate manifest.json
echo "----------------------------------------"
echo "Validating manifest.json..."
echo "----------------------------------------"
MANIFEST=$(find "$TARGET" -name "manifest.json" -type f | head -1)
if [ -n "$MANIFEST" ]; then
    if [ -f "$SCRIPT_DIR/validate-manifest.py" ]; then
        if python3 "$SCRIPT_DIR/validate-manifest.py" "$MANIFEST"; then
            echo -e "${GREEN}✓ manifest.json is valid${NC}"
        else
            echo -e "${RED}✗ manifest.json validation failed${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        # Basic JSON validation
        if python3 -c "import json; json.load(open('$MANIFEST'))" 2>/dev/null; then
            echo -e "${GREEN}✓ manifest.json is valid JSON${NC}"
        else
            echo -e "${RED}✗ manifest.json is invalid JSON${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    echo -e "${YELLOW}⚠ No manifest.json found${NC}"
fi
echo ""

# Validate strings.json
echo "----------------------------------------"
echo "Validating strings.json..."
echo "----------------------------------------"
STRINGS=$(find "$TARGET" -name "strings.json" -type f | head -1)
if [ -n "$STRINGS" ]; then
    if [ -f "$SCRIPT_DIR/validate-strings.py" ]; then
        if python3 "$SCRIPT_DIR/validate-strings.py" "$STRINGS"; then
            echo -e "${GREEN}✓ strings.json is valid${NC}"
        else
            echo -e "${YELLOW}⚠ strings.json has issues${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
    else
        # Basic JSON validation
        if python3 -c "import json; json.load(open('$STRINGS'))" 2>/dev/null; then
            echo -e "${GREEN}✓ strings.json is valid JSON${NC}"
        else
            echo -e "${RED}✗ strings.json is invalid JSON${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    fi
else
    echo -e "${YELLOW}⚠ No strings.json found${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}✗ $ERRORS error(s), $WARNINGS warning(s)${NC}"
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}✓ All checks passed!${NC}"
    exit 0
fi
