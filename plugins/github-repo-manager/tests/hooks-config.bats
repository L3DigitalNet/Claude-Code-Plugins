#!/usr/bin/env bats
# hooks-config.bats — Structural sibling: hooks.json shape correct.
bats_require_minimum_version 1.5.0
PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "hooks.json is valid JSON (HC1)" {
  python3 -c "import json; json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))"
}

@test "hooks.json keys PreToolUse and PostToolUse in record form (HC2)" {
  python3 -c "
import json, sys
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
assert isinstance(d['hooks'], dict), 'hooks must be a dict'
assert 'PreToolUse' in d['hooks']
assert 'PostToolUse' in d['hooks']
"
}

@test "hooks.json matches Bash tool only (HC3 scope)" {
  matcher=$(python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
print(d['hooks']['PreToolUse'][0]['matcher'])
")
  [ "$matcher" = "Bash" ]
}

@test "plugin.json passes Zod-strict allow-list (M1)" {
  invalid=$(python3 -c "
import json
allowed = {'name', 'version', 'description', 'author', 'homepage'}
keys = set(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')).keys())
print(','.join(sorted(keys - allowed)))
")
  [ -z "$invalid" ]
}
