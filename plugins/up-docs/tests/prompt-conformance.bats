#!/usr/bin/env bats
# prompt-conformance.bats — assert agent prompts stay aligned with Agent Handoff
# System v3. These are grep-level guards: when the spec advances, a stale prompt
# fails here loudly instead of shipping non-conformant propagator output (Bug #6).
bats_require_minimum_version 1.5.0
PLUGIN_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PROPAGATE_REPO="$PLUGIN_ROOT/agents/up-docs-propagate-repo.md"

@test "propagate-repo AGENTS.md remediation cites all three handoff-v3 lines" {
  run grep -F 'Full conventions reference:' "$PROPAGATE_REPO"
  [ "$status" -eq 0 ]
  run grep -F 'Detailed review workflows:' "$PROPAGATE_REPO"
  [ "$status" -eq 0 ]
}

@test "propagate-repo bug-body template includes Cause, Fix, and Lesson" {
  for h in '## Cause' '## Fix' '## Lesson'; do
    run grep -F "$h" "$PROPAGATE_REPO"
    [ "$status" -eq 0 ]
  done
}
