#!/usr/bin/env bats
# manifest.bats — Marketplace-wide Zod-strict guard.
bats_require_minimum_version 1.5.0
PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

@test "plugin.json passes Zod-strict allow-list (M1)" {
  invalid=$(python3 -c "
import json
allowed = {'name', 'version', 'description', 'author', 'homepage'}
keys = set(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')).keys())
print(','.join(sorted(keys - allowed)))
")
  [ -z "$invalid" ]
}

@test "hooks.json keys events in record form (M2)" {
  python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
assert isinstance(d['hooks'], dict)
"
}
