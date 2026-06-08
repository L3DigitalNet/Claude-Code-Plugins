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

@test "plugin.json version matches the marketplace.json up-docs entry (M3)" {
  # both manifests carry the version independently; they must never drift.
  result=$(python3 -c "
import json
pv = json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json'))['version']
mkt = json.load(open('$PLUGIN_ROOT/../../.claude-plugin/marketplace.json'))['plugins']
mv = next(p['version'] for p in mkt if p['name'] == 'up-docs')
print('OK' if pv == mv else pv + ' != ' + mv)
")
  [ "$result" = "OK" ]
}
