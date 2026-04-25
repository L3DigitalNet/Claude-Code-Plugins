#!/usr/bin/env bats
# session-start.bats — Mechanical contract for the SessionStart hook.
# All four [P1]-[P4] principles are behavioral; this exercises the script seam
# that delivers them into Claude's baseline context.
bats_require_minimum_version 1.5.0
load test_helper

@test "valid SKILL.md → JSON with hookSpecificOutput.additionalContext (SS1)" {
  SCRIPT=$(make_fake_plugin "rules body content" yes)
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 0 ]
  # Parse stdout JSON and verify structure + body.
  parsed=$(python3 -c "import json,sys; d=json.loads(sys.argv[1]); print(d['hookSpecificOutput']['hookEventName'], '|', d['hookSpecificOutput']['additionalContext'])" "$output")
  [[ "$parsed" == *"SessionStart"* ]]
  [[ "$parsed" == *"rules body content"* ]]
}

@test "frontmatter is stripped from emitted body (SS2)" {
  # Critical: stale frontmatter leaking into context would prefix the rules with
  # YAML noise and degrade behavioral effect.
  SCRIPT=$(make_fake_plugin "RULES_HERE" yes)
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 0 ]
  body=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['hookSpecificOutput']['additionalContext'])" "$output")
  [[ "$body" != *"---"* ]]
  [[ "$body" != *"name: deep-context"* ]]
  [[ "$body" == *"RULES_HERE"* ]]
}

@test "missing SKILL.md → exit 0, error to stderr, no JSON to stdout (SS3 quiet-fail)" {
  SCRIPT=$(make_fake_plugin_no_skill)
  run --separate-stderr bash "$SCRIPT"
  # Script exits 0 (don't break Claude session over a missing skill file)
  # but emits no JSON to stdout (so additionalContext is empty, not garbage).
  [ "$status" -eq 0 ]
  # Output captured by `run` merges stdout+stderr by default; assert that the
  # error message is present and no hookSpecificOutput JSON was emitted.
  # Stderr should carry the diagnostic; stdout must NOT contain a JSON payload.
  [[ "$stderr" == *"not readable"* ]]
  [[ "$output" != *"hookSpecificOutput"* ]]
}

@test "SKILL.md without frontmatter is emitted as-is (SS4)" {
  # If frontmatter regex doesn't match, the body should still be delivered intact.
  SCRIPT=$(make_fake_plugin "no-frontmatter content" no)
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 0 ]
  body=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['hookSpecificOutput']['additionalContext'])" "$output")
  [[ "$body" == *"no-frontmatter content"* ]]
}

@test "stdout is valid JSON (SS5 contract for Claude Code)" {
  # Claude Code parses hook stdout as JSON; malformed JSON silently drops
  # the additionalContext. Assert valid-JSON parse succeeds.
  SCRIPT=$(make_fake_plugin "x" yes)
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 0 ]
  python3 -c "import json,sys; json.loads(sys.argv[1])" "$output"
}

@test "stderr confirmation message present on success (SS6)" {
  # Script echoes a terminal-visible confirmation to stderr — useful for users
  # debugging plugin loading, must not regress.
  SCRIPT=$(make_fake_plugin "x" yes)
  run --separate-stderr bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$stderr" == *"1M context rules injected"* ]]
}
