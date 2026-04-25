#!/usr/bin/env bats
# manifest.bats — Marketplace-wide Zod-strict guard.
bats_require_minimum_version 1.5.0
PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "plugin.json passes Zod-strict allow-list (M1)" {
  invalid=$(python3 -c "
import json
allowed = {'name', 'version', 'description', 'author', 'homepage'}
keys = set(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')).keys())
print(','.join(sorted(keys - allowed)))
")
  [ -z "$invalid" ]
}

@test ".mcp.json exists for Qt Pilot MCP server (M2)" {
  [ -f "$PLUGIN_ROOT/.mcp.json" ] || [ -f "$PLUGIN_ROOT/.claude-plugin/.mcp.json" ] || [ -d "$PLUGIN_ROOT/mcp/qt-pilot" ]
}
