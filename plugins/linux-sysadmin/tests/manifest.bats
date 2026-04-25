#!/usr/bin/env bats
# manifest.bats — Marketplace-wide Zod-strict guard.
bats_require_minimum_version 1.5.0
load test_helper

@test "plugin.json passes Zod-strict allow-list (M1)" {
  invalid=$(python3 -c "
import json
allowed = {'name', 'version', 'description', 'author', 'homepage'}
keys = set(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')).keys())
print(','.join(sorted(keys - allowed)))
")
  [ -z "$invalid" ]
}

@test "plugin.json has all required fields (M2)" {
  result=$(python3 -c "
import json
required = {'name', 'version', 'description'}
keys = set(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')).keys())
missing = required - keys
print(','.join(sorted(missing)) if missing else 'OK')
")
  [ "$result" = "OK" ]
}

@test "hooks.json keys SessionStart in record form (M3)" {
  type=$(python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
print(type(d['hooks']).__name__, 'SessionStart' in d['hooks'])
")
  [ "$type" = "dict True" ]
}
