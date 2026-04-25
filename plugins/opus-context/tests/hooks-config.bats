#!/usr/bin/env bats
# hooks-config.bats — Structural sibling to the SessionStart contract.
# Cheap insurance against the marketplace-wide hooks.json record-vs-array gotcha.
load test_helper

@test "hooks.json is valid JSON (HC1)" {
  python3 -c "import json; json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))"
}

@test "hooks.json keys SessionStart in record form, not array (HC2)" {
  type=$(python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
print(type(d['hooks']).__name__)
")
  [ "$type" = "dict" ]
  has_event=$(python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
print('SessionStart' in d['hooks'])
")
  [ "$has_event" = "True" ]
}

@test "hooks.json command references CLAUDE_PLUGIN_ROOT (HC3)" {
  cmd=$(python3 -c "
import json
d = json.load(open('$PLUGIN_ROOT/hooks/hooks.json'))
print(d['hooks']['SessionStart'][0]['hooks'][0]['command'])
")
  [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'* ]]
  [[ "$cmd" == *"session-start.sh"* ]]
}

@test "plugin.json passes Zod-strict allow-list (HC4)" {
  # Marketplace-wide guard: only name, version, description, author, homepage allowed.
  invalid=$(python3 -c "
import json
allowed = {'name', 'version', 'description', 'author', 'homepage'}
keys = set(json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')).keys())
print(','.join(keys - allowed))
")
  [ -z "$invalid" ]
}
