#!/bin/bash
# Comprehensive marketplace validation script

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

echo -e "${BLUE}🔍 Validating Claude Code Plugin Marketplace${NC}"
echo ""

# Check for required tools
for CMD in jq git; do
    if ! command -v $CMD &> /dev/null; then
        echo -e "${RED}✗ Required tool not found: $CMD${NC}"
        exit 1
    fi
done

MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"

# 1. Validate marketplace.json exists
echo "📋 Checking marketplace structure..."
if [ ! -f "$MARKETPLACE_FILE" ]; then
    echo -e "${RED}✗ marketplace.json not found at .claude-plugin/marketplace.json${NC}"
    exit 1
fi
echo -e "${GREEN}✓ marketplace.json exists${NC}"

# 2. Validate JSON syntax
echo ""
echo "🔤 Validating JSON syntax..."
if ! jq empty "$MARKETPLACE_FILE" 2>/dev/null; then
    echo -e "${RED}✗ Invalid JSON syntax in marketplace.json${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Valid JSON${NC}"

# 3. Validate required marketplace fields
echo ""
echo "📝 Checking required marketplace fields..."
REQUIRED_FIELDS=("name" "version" "description" "plugins")
for FIELD in "${REQUIRED_FIELDS[@]}"; do
    if ! jq -e ".$FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
        echo -e "${RED}✗ Missing required field: $FIELD${NC}"
        ((ERRORS++))
    else
        VALUE=$(jq -r ".$FIELD" "$MARKETPLACE_FILE")
        if [ "$FIELD" = "plugins" ]; then
            COUNT=$(jq -r '.plugins | length' "$MARKETPLACE_FILE")
            echo -e "${GREEN}✓ $FIELD ($COUNT plugins)${NC}"
        else
            echo -e "${GREEN}✓ $FIELD: $VALUE${NC}"
        fi
    fi
done

# 4. Validate semver format
echo ""
echo "🔢 Validating version format..."
VERSION=$(jq -r '.version' "$MARKETPLACE_FILE")
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}✗ Invalid semver format: $VERSION${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✓ Valid semver: $VERSION${NC}"
fi

# 5. Validate each plugin entry
echo ""
echo "🔌 Validating plugin entries..."
PLUGIN_COUNT=$(jq -r '.plugins | length' "$MARKETPLACE_FILE")

if [ "$PLUGIN_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ No plugins in marketplace${NC}"
    ((WARNINGS++))
fi

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
    echo ""
    PLUGIN_NAME=$(jq -r ".plugins[$i].name" "$MARKETPLACE_FILE")
    echo -e "${BLUE}  Plugin $((i+1)): $PLUGIN_NAME${NC}"

    # Required plugin fields
    PLUGIN_REQUIRED=("name" "displayName" "description" "version" "author" "source")
    for FIELD in "${PLUGIN_REQUIRED[@]}"; do
        if ! jq -e ".plugins[$i].$FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
            echo -e "${RED}    ✗ Missing required field: $FIELD${NC}"
            ((ERRORS++))
        else
            if [ "$FIELD" = "source" ]; then
                SOURCE_TYPE=$(jq -r ".plugins[$i].source.type" "$MARKETPLACE_FILE")
                echo -e "${GREEN}    ✓ source (type: $SOURCE_TYPE)${NC}"
            else
                echo -e "${GREEN}    ✓ $FIELD${NC}"
            fi
        fi
    done

    # Validate source structure
    SOURCE_TYPE=$(jq -r ".plugins[$i].source.type" "$MARKETPLACE_FILE")
    case "$SOURCE_TYPE" in
        github)
            REQUIRED_SOURCE=("owner" "repo")
            for FIELD in "${REQUIRED_SOURCE[@]}"; do
                if ! jq -e ".plugins[$i].source.$FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
                    echo -e "${RED}    ✗ Missing source.$FIELD for GitHub source${NC}"
                    ((ERRORS++))
                fi
            done
            ;;
        git)
            if ! jq -e ".plugins[$i].source.url" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
                echo -e "${RED}    ✗ Missing source.url for git source${NC}"
                ((ERRORS++))
            fi
            ;;
    esac

    # Check if plugin directory exists
    PLUGIN_DIR="$REPO_ROOT/plugins/$PLUGIN_NAME"
    if [ ! -d "$PLUGIN_DIR" ]; then
        echo -e "${YELLOW}    ⚠ Plugin directory not found: plugins/$PLUGIN_NAME${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}    ✓ Plugin directory exists${NC}"

        # Validate plugin manifest exists
        MANIFEST=$(find "$PLUGIN_DIR/.claude-plugin" -name "*.json" -type f 2>/dev/null | head -1)
        if [ -z "$MANIFEST" ]; then
            echo -e "${RED}    ✗ No manifest found in .claude-plugin/${NC}"
            ((ERRORS++))
        else
            echo -e "${GREEN}    ✓ Manifest exists${NC}"

            # Check version consistency
            MARKETPLACE_VER=$(jq -r ".plugins[$i].version" "$MARKETPLACE_FILE")
            PLUGIN_VER=$(jq -r '.version' "$MANIFEST" 2>/dev/null || echo "unknown")

            if [ "$MARKETPLACE_VER" != "$PLUGIN_VER" ]; then
                echo -e "${RED}    ✗ Version mismatch: marketplace=$MARKETPLACE_VER, plugin=$PLUGIN_VER${NC}"
                ((ERRORS++))
            else
                echo -e "${GREEN}    ✓ Versions match: $MARKETPLACE_VER${NC}"
            fi

            # Check name consistency
            MANIFEST_NAME=$(jq -r '.name' "$MANIFEST" 2>/dev/null || echo "unknown")
            if [ "$PLUGIN_NAME" != "$MANIFEST_NAME" ]; then
                echo -e "${YELLOW}    ⚠ Name mismatch: marketplace=$PLUGIN_NAME, plugin=$MANIFEST_NAME${NC}"
                ((WARNINGS++))
            fi
        fi
    fi
done

# 6. Check for duplicate plugin names
echo ""
echo "🔍 Checking for duplicate plugins..."
DUPLICATES=$(jq -r '.plugins[].name' "$MARKETPLACE_FILE" | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
    echo -e "${RED}✗ Duplicate plugin names found:${NC}"
    echo "$DUPLICATES" | while read -r DUP; do
        echo -e "${RED}  - $DUP${NC}"
    done
    ((ERRORS++))
else
    echo -e "${GREEN}✓ No duplicates${NC}"
fi

# 7. Git status check
echo ""
echo "📦 Checking git status..."
if git rev-parse --git-dir > /dev/null 2>&1; then
    if [ -n "$(git status --porcelain .claude-plugin/marketplace.json)" ]; then
        echo -e "${YELLOW}⚠ marketplace.json has uncommitted changes${NC}"
        ((WARNINGS++))
    else
        echo -e "${GREEN}✓ marketplace.json is committed${NC}"
    fi
fi

# Summary
echo ""
echo "═══════════════════════════════════════"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Marketplace ready for distribution:"
    echo "  /plugin marketplace add L3DigitalNet/Claude-Code-Plugins"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation passed with $WARNINGS warning(s)${NC}"
    echo "Review warnings above before publishing"
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Fix errors above before committing"
    exit 1
fi
