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

@test "drift-finding template layer enum stays in sync with the audit schema (layout)" {
  # validate_output.py Finding.layer accepts 'layout'; the output-contract
  # template the auditor cites must list it too, or the two specs drift (Bug #6).
  run grep -F '"layout"' "$PLUGIN_ROOT/templates/drift-finding.md"
  [ "$status" -eq 0 ]
}

@test "propagate-repo audits for retired V1/V2 layout-detection language" {
  # v0.9.1: the propagator must EXPLICITLY scan AGENTS.md/AGENTS.reviews.md (prose
  # conditionals) and conventions.md (version labels) for pre-v3 layout-detection
  # language, so the relabel is reliable rather than luck-of-the-Haiku-draw — the
  # /up-docs:repo run that shipped v0.9.0 missed exactly these stragglers.
  run grep -iF 'retired V1/V2 layout-detection' "$PROPAGATE_REPO"
  [ "$status" -eq 0 ]
  run grep -iF 'retired handoff-version label' "$PROPAGATE_REPO"
  [ "$status" -eq 0 ]
}

AUDIT_DRIFT="$PLUGIN_ROOT/agents/up-docs-audit-drift.md"

@test "audit-drift narrows pass N+1 to prior-pass touched_pages + one-hop related" {
  run grep -iF 'touched_pages' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
  run grep -iF 'one-hop' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
  run grep -iF 'pass 1' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
}

@test "convergence-tracking defers the narrowing rule to the auditor task step" {
  run grep -iF 'touched_pages' "$PLUGIN_ROOT/skills/drift/references/convergence-tracking.md"
  [ "$status" -eq 0 ]
}
