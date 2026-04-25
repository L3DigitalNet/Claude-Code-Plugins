#!/usr/bin/env bats
# manifest.bats — Marketplace-wide Zod-strict guard + hooks shape.
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

@test "hooks.json keys PostToolUse and Stop in record form (M2)" {
  python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
assert isinstance(d['hooks'], dict)
assert 'PostToolUse' in d['hooks']
assert 'Stop' in d['hooks']
"
}

@test "PostToolUse matcher restricts to Write|Edit|MultiEdit (M3 scope)" {
  matcher=$(python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
print(d['hooks']['PostToolUse'][0]['matcher'])
")
  [[ "$matcher" == *"Write"* ]]
  [[ "$matcher" == *"Edit"* ]]
}
