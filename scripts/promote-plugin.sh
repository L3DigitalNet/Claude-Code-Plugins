#!/bin/bash
# Script to promote a plugin from development to production

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <plugin-name> [--version VERSION]"
    echo ""
    echo "Promotes a plugin from plugins-dev/ to plugins/ and adds it to the marketplace."
    echo ""
    echo "Options:"
    echo "  --version VERSION    Set initial version (default: 1.0.0)"
    echo ""
    echo "Example:"
    echo "  $0 my-new-plugin --version 0.1.0"
    exit 1
}

# Parse arguments
PLUGIN_NAME=""
VERSION="1.0.0"

while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$PLUGIN_NAME" ]; then
                PLUGIN_NAME="$1"
            else
                echo -e "${RED}Error: Unknown argument '$1'${NC}"
                usage
            fi
            shift
            ;;
    esac
done

if [ -z "$PLUGIN_NAME" ]; then
    echo -e "${RED}Error: Plugin name required${NC}"
    usage
fi

DEV_DIR="$REPO_ROOT/plugins-dev/$PLUGIN_NAME"
PROD_DIR="$REPO_ROOT/plugins/$PLUGIN_NAME"
MARKETPLACE_FILE="$REPO_ROOT/.claude-plugin/marketplace.json"

# Validation
if [ ! -d "$DEV_DIR" ]; then
    echo -e "${RED}Error: Development plugin not found: $DEV_DIR${NC}"
    exit 1
fi

if [ -d "$PROD_DIR" ]; then
    echo -e "${RED}Error: Plugin already exists in production: $PROD_DIR${NC}"
    exit 1
fi

MANIFEST_FILE=$(find "$DEV_DIR/.claude-plugin" -name "*.json" -type f | head -1)
if [ -z "$MANIFEST_FILE" ]; then
    echo -e "${RED}Error: No manifest file found in $DEV_DIR/.claude-plugin/${NC}"
    exit 1
fi

echo -e "${BLUE}🚀 Promoting plugin: $PLUGIN_NAME${NC}"
echo ""

# Step 1: Validate plugin structure
echo "📋 Validating plugin structure..."
if ! jq -e '.name and .version and .description' "$MANIFEST_FILE" > /dev/null; then
    echo -e "${RED}Error: Invalid manifest file${NC}"
    exit 1
fi

MANIFEST_NAME=$(jq -r '.name' "$MANIFEST_FILE")
if [ "$MANIFEST_NAME" != "$PLUGIN_NAME" ]; then
    echo -e "${YELLOW}⚠ Warning: Directory name ($PLUGIN_NAME) != manifest name ($MANIFEST_NAME)${NC}"
    echo -e "${YELLOW}  Using manifest name: $MANIFEST_NAME${NC}"
    PLUGIN_NAME="$MANIFEST_NAME"
    PROD_DIR="$REPO_ROOT/plugins/$PLUGIN_NAME"
fi

# Step 2: Set version
echo "📝 Setting version to $VERSION..."
jq --arg version "$VERSION" '.version = $version' "$MANIFEST_FILE" > "$MANIFEST_FILE.tmp"
mv "$MANIFEST_FILE.tmp" "$MANIFEST_FILE"

# Step 3: Copy to production
echo "📦 Copying to production directory..."
cp -r "$DEV_DIR" "$PROD_DIR"

# Step 4: Update marketplace
echo "🏪 Adding to marketplace catalog..."

DISPLAY_NAME=$(jq -r '.displayName // .name' "$MANIFEST_FILE")
DESCRIPTION=$(jq -r '.description' "$MANIFEST_FILE")
AUTHOR=$(jq -r '.author // "L3DigitalNet"' "$MANIFEST_FILE")
LICENSE=$(jq -r '.license // "MIT"' "$MANIFEST_FILE")

# Create marketplace entry
MARKETPLACE_ENTRY=$(cat <<EOF
{
  "name": "$PLUGIN_NAME",
  "displayName": "$DISPLAY_NAME",
  "description": "$DESCRIPTION",
  "version": "$VERSION",
  "author": "$AUTHOR",
  "license": "$LICENSE",
  "keywords": [],
  "homepage": "https://github.com/L3DigitalNet/Claude-Code-Plugins/tree/main/plugins/$PLUGIN_NAME",
  "repository": "https://github.com/L3DigitalNet/Claude-Code-Plugins",
  "source": {
    "type": "github",
    "owner": "L3DigitalNet",
    "repo": "Claude-Code-Plugins",
    "ref": "main"
  }
}
EOF
)

# Add to marketplace.json
jq --argjson entry "$MARKETPLACE_ENTRY" '.plugins += [$entry]' "$MARKETPLACE_FILE" > "$MARKETPLACE_FILE.tmp"
mv "$MARKETPLACE_FILE.tmp" "$MARKETPLACE_FILE"

# Bump marketplace version (minor)
CURRENT_VERSION=$(jq -r '.version' "$MARKETPLACE_FILE")
MAJOR=$(echo "$CURRENT_VERSION" | cut -d. -f1)
MINOR=$(echo "$CURRENT_VERSION" | cut -d. -f2)
PATCH=$(echo "$CURRENT_VERSION" | cut -d. -f3)
NEW_MINOR=$((MINOR + 1))
NEW_MARKETPLACE_VERSION="$MAJOR.$NEW_MINOR.0"

jq --arg version "$NEW_MARKETPLACE_VERSION" '.version = $version' "$MARKETPLACE_FILE" > "$MARKETPLACE_FILE.tmp"
mv "$MARKETPLACE_FILE.tmp" "$MARKETPLACE_FILE"

echo ""
echo -e "${GREEN}✓ Plugin promoted successfully!${NC}"
echo ""
echo "Summary:"
echo "  Plugin name: $PLUGIN_NAME"
echo "  Version: $VERSION"
echo "  Location: plugins/$PLUGIN_NAME"
echo "  Marketplace version: $CURRENT_VERSION → $NEW_MARKETPLACE_VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff"
echo "  2. Update README.md with plugin description"
echo "  3. Add keywords to marketplace entry for discoverability"
echo "  4. Commit changes: git add . && git commit -m 'Add $PLUGIN_NAME plugin v$VERSION'"
echo "  5. Push to GitHub: git push origin main"
echo ""
echo "Optional: Keep development version for future work"
echo "  To remove dev version: rm -rf plugins-dev/$PLUGIN_NAME"
echo "  To keep it: git add plugins-dev/ (will be in both locations)"
