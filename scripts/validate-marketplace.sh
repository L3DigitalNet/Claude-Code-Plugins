#!/bin/bash
# Marketplace validation script
# Validates against the actual Claude Code Zod schema (not community docs)
# Reference: ~/.claude/plugins/marketplaces/claude-plugins-official/.claude-plugin/marketplace.json

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

echo -e "${BLUE}Validating Claude Code Plugin Marketplace${NC}"
echo ""

# Check for required tools
for CMD in jq git; do
    if ! command -v $CMD &> /dev/null; then
        echo -e "${RED}x Required tool not found: $CMD${NC}"
        exit 1
    fi
done

MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"

# 1. Validate marketplace.json exists
echo "Checking marketplace structure..."
if [ ! -f "$MARKETPLACE_FILE" ]; then
    echo -e "${RED}x marketplace.json not found at .claude-plugin/marketplace.json${NC}"
    exit 1
fi
echo -e "${GREEN}OK marketplace.json exists${NC}"

# 2. Validate JSON syntax
echo ""
echo "Validating JSON syntax..."
if ! jq empty "$MARKETPLACE_FILE" 2>/dev/null; then
    echo -e "${RED}x Invalid JSON syntax in marketplace.json${NC}"
    exit 1
fi
echo -e "${GREEN}OK Valid JSON${NC}"

# 3. Validate required root fields: name, owner (object), plugins (array)
# NOTE: The Zod schema does NOT allow root-level version, homepage, repository, or license
echo ""
echo "Checking required root fields..."
for FIELD in name owner plugins; do
    if ! jq -e ".$FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
        echo -e "${RED}x Missing required root field: $FIELD${NC}"
        ERRORS=$((ERRORS + 1))
    else
        if [ "$FIELD" = "plugins" ]; then
            COUNT=$(jq -r '.plugins | length' "$MARKETPLACE_FILE")
            echo -e "${GREEN}OK $FIELD ($COUNT plugins)${NC}"
        elif [ "$FIELD" = "owner" ]; then
            OWNER_NAME=$(jq -r '.owner.name // "MISSING"' "$MARKETPLACE_FILE")
            echo -e "${GREEN}OK $FIELD: $OWNER_NAME${NC}"
        else
            VALUE=$(jq -r ".$FIELD" "$MARKETPLACE_FILE")
            echo -e "${GREEN}OK $FIELD: $VALUE${NC}"
        fi
    fi
done

# Validate owner is an object with name (required) + url or email
OWNER_TYPE=$(jq -r '.owner | type' "$MARKETPLACE_FILE")
if [ "$OWNER_TYPE" != "object" ]; then
    echo -e "${RED}x owner must be an object {name, url/email}, not a $OWNER_TYPE${NC}"
    ERRORS=$((ERRORS + 1))
else
    if ! jq -e '.owner.name' "$MARKETPLACE_FILE" > /dev/null 2>&1; then
        echo -e "${RED}x owner.name is required${NC}"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Warn about invalid root-level fields
for INVALID_FIELD in version homepage repository license; do
    if jq -e ".$INVALID_FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
        echo -e "${RED}x Root-level '$INVALID_FIELD' is not allowed by the Zod schema${NC}"
        ERRORS=$((ERRORS + 1))
    fi
done

# 4. Validate each plugin entry
echo ""
echo "Validating plugin entries..."
PLUGIN_COUNT=$(jq -r '.plugins | length' "$MARKETPLACE_FILE")

if [ "$PLUGIN_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}! No plugins in marketplace${NC}"
    WARNINGS=$((WARNINGS + 1))
fi

for i in $(seq 0 $((PLUGIN_COUNT - 1))); do
    echo ""
    PLUGIN_NAME=$(jq -r ".plugins[$i].name" "$MARKETPLACE_FILE")
    echo -e "${BLUE}  Plugin $((i+1)): $PLUGIN_NAME${NC}"

    # Required plugin fields: name, description, source
    # Optional valid fields: version, author (object), category, homepage, tags, strict
    # INVALID fields: displayName, keywords, license
    for FIELD in name description source; do
        if ! jq -e ".plugins[$i].$FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
            echo -e "${RED}    x Missing required field: $FIELD${NC}"
            ERRORS=$((ERRORS + 1))
        else
            if [ "$FIELD" = "source" ]; then
                SOURCE_TYPE=$(jq -r ".plugins[$i].source | type" "$MARKETPLACE_FILE")
                if [ "$SOURCE_TYPE" = "string" ]; then
                    echo -e "${GREEN}    OK source (relative path)${NC}"
                else
                    # External source uses {"source": "url", "url": "https://..."}
                    EXT_SOURCE=$(jq -r ".plugins[$i].source.source // \"unknown\"" "$MARKETPLACE_FILE")
                    echo -e "${GREEN}    OK source (external: $EXT_SOURCE)${NC}"
                fi
            else
                echo -e "${GREEN}    OK $FIELD${NC}"
            fi
        fi
    done

    # Validate author is object if present
    if jq -e ".plugins[$i].author" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
        AUTHOR_TYPE=$(jq -r ".plugins[$i].author | type" "$MARKETPLACE_FILE")
        if [ "$AUTHOR_TYPE" != "object" ]; then
            echo -e "${RED}    x author must be an object {name, url/email}, not a $AUTHOR_TYPE${NC}"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${GREEN}    OK author (object)${NC}"
        fi
    fi

    # Warn about invalid plugin-level fields
    for INVALID_FIELD in displayName keywords license; do
        if jq -e ".plugins[$i].$INVALID_FIELD" "$MARKETPLACE_FILE" > /dev/null 2>&1; then
            echo -e "${RED}    x '$INVALID_FIELD' is not allowed by the Zod schema${NC}"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # Check if source is relative path and plugin directory exists
    SOURCE_VALUE_TYPE=$(jq -r ".plugins[$i].source | type" "$MARKETPLACE_FILE")
    if [ "$SOURCE_VALUE_TYPE" = "string" ]; then
        SOURCE_PATH=$(jq -r ".plugins[$i].source" "$MARKETPLACE_FILE")
        PLUGIN_DIR="$REPO_ROOT/${SOURCE_PATH#./}"
        if [ ! -d "$PLUGIN_DIR" ]; then
            echo -e "${YELLOW}    ! Plugin directory not found: $SOURCE_PATH${NC}"
            WARNINGS=$((WARNINGS + 1))
        else
            echo -e "${GREEN}    OK Plugin directory exists${NC}"

            # Validate plugin manifest exists
            if [ -f "$PLUGIN_DIR/.claude-plugin/plugin.json" ]; then
                echo -e "${GREEN}    OK Manifest exists${NC}"

                # Check version consistency (if both have versions)
                MARKETPLACE_VER=$(jq -r ".plugins[$i].version // \"none\"" "$MARKETPLACE_FILE")
                PLUGIN_VER=$(jq -r '.version // "none"' "$PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null || echo "none")

                if [ "$MARKETPLACE_VER" != "none" ] && [ "$PLUGIN_VER" != "none" ] && [ "$MARKETPLACE_VER" != "$PLUGIN_VER" ]; then
                    echo -e "${RED}    x Version mismatch: marketplace=$MARKETPLACE_VER, plugin=$PLUGIN_VER${NC}"
                    ERRORS=$((ERRORS + 1))
                elif [ "$MARKETPLACE_VER" != "none" ] && [ "$PLUGIN_VER" != "none" ]; then
                    echo -e "${GREEN}    OK Versions match: $MARKETPLACE_VER${NC}"
                fi

                # Check name consistency
                MANIFEST_NAME=$(jq -r '.name // "unknown"' "$PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null || echo "unknown")
                if [ "$PLUGIN_NAME" != "$MANIFEST_NAME" ]; then
                    echo -e "${YELLOW}    ! Name mismatch: marketplace=$PLUGIN_NAME, plugin=$MANIFEST_NAME${NC}"
                    WARNINGS=$((WARNINGS + 1))
                fi
            elif [ -f "$PLUGIN_DIR/.claude-plugin/manifest.json" ]; then
                echo -e "${GREEN}    OK Manifest exists (manifest.json)${NC}"
            else
                echo -e "${RED}    x No manifest found in .claude-plugin/${NC}"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi
done

# 5. Check for duplicate plugin names
echo ""
echo "Checking for duplicate plugins..."
DUPLICATES=$(jq -r '.plugins[].name' "$MARKETPLACE_FILE" | sort | uniq -d)
if [ -n "$DUPLICATES" ]; then
    echo -e "${RED}x Duplicate plugin names found:${NC}"
    echo "$DUPLICATES" | while read -r DUP; do
        echo -e "${RED}  - $DUP${NC}"
    done
    ERRORS=$((ERRORS + 1))
else
    echo -e "${GREEN}OK No duplicates${NC}"
fi

# 6. Git status check
echo ""
echo "Checking git status..."
if git -C "$REPO_ROOT" rev-parse --git-dir > /dev/null 2>&1; then
    if [ -n "$(git -C "$REPO_ROOT" status --porcelain .claude-plugin/marketplace.json)" ]; then
        echo -e "${YELLOW}! marketplace.json has uncommitted changes${NC}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "${GREEN}OK marketplace.json is committed${NC}"
    fi
fi

# Summary
echo ""
echo "======================================="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All validations passed!${NC}"
    echo ""
    echo "Marketplace ready for distribution:"
    echo "  /plugin marketplace add L3DigitalNet/Claude-Code-Plugins"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Validation passed with $WARNINGS warning(s)${NC}"
    echo "Review warnings above before publishing"
    exit 0
else
    echo -e "${RED}Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Fix errors above before committing"
    exit 1
fi
