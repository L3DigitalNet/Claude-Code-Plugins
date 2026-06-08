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

# Behavioral check (manual): a repo-only routed summary must dispatch NO wiki/notion Agent call while the auditor still covers all three layers. Verified by transcript inspection on the next /up-docs:all run.
ALL_SKILL="$PLUGIN_ROOT/skills/all/SKILL.md"

@test "all-skill has a routing matrix with a fail-open ambiguous rule" {
  run grep -iF 'Routing matrix' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'ambiguous' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'all candidate layers' "$ALL_SKILL"
  [ "$status" -eq 0 ]
}

@test "all-skill dispatches only propagators with routed items and logs skips" {
  run grep -iF 'only the propagators with' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'skipped (0 items routed' "$ALL_SKILL"
  [ "$status" -eq 0 ]
}

@test "audit still covers all layers even when a propagator is skipped" {
  run grep -iF 'audits all three layers' "$ALL_SKILL"
  [ "$status" -eq 0 ]
}

@test "routing fixtures cover the system-of-record edge cases (CR-002/003)" {
  F="$PLUGIN_ROOT/tests/fixtures/routing-cases.md"
  [ -f "$F" ]
  run grep -iF 'OpenBao listener rebind' "$F"; [ "$status" -eq 0 ]
  run grep -iF 'Secret VALUE' "$F"; [ "$status" -eq 0 ]
  run grep -iF 'Ambiguous' "$F"; [ "$status" -eq 0 ]
}

POST_PROP="$PLUGIN_ROOT/templates/post-propagation-steps.md"

@test "post-propagation part (c) is consent-gated, baseline-safe, no-push" {
  run grep -iF 'commit-candidates.sh' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'changed since baseline' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'per-path' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 're-check' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'fingerprint' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'no-index' "$POST_PROP"   # untracked candidate content disclosure (CR-001)
  [ "$status" -eq 0 ]
  run grep -iF 'never push' "$POST_PROP"
  [ "$status" -eq 0 ]
}

@test "repo-skill also captures a pre-propagation baseline (CR-NEW-003)" {
  run grep -iF 'commit-candidates.sh snapshot' "$PLUGIN_ROOT/skills/repo/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "post-propagation commit offer degrades to report-only when non-interactive" {
  run grep -iF 'non-interactive' "$POST_PROP"
  [ "$status" -eq 0 ]
  run grep -iF 'commit nothing' "$POST_PROP"
  [ "$status" -eq 0 ]
}

@test "all-skill captures a pre-propagation baseline for committable repos" {
  run grep -iF 'commit-candidates.sh snapshot' "$PLUGIN_ROOT/skills/all/SKILL.md"
  [ "$status" -eq 0 ]
}

@test "skills surface the part (c) commit offer in their post-propagation dispatch (not silently skipped)" {
  run grep -iF 'Commit offer (part (c))' "$ALL_SKILL"
  [ "$status" -eq 0 ]
  run grep -iF 'Commit offer (part (c))' "$PLUGIN_ROOT/skills/repo/SKILL.md"
  [ "$status" -eq 0 ]
}

PROPAGATE_WIKI="$PLUGIN_ROOT/agents/up-docs-propagate-wiki.md"

@test "propagate-wiki declares remote SSH access constants, not a local wiki path (0.12.0)" {
  # The wiki repo moved off the workstation into CT 103; the propagator addresses
  # it over SSH. The old local default ~/projects/llm-wiki must be fully gone.
  run grep -F 'LLM_WIKI_SSH' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
  run grep -F '/srv/workspaces/llm-wiki' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
  run grep -F 'projects/llm-wiki' "$PROPAGATE_WIKI"
  [ "$status" -ne 0 ]
}

@test "propagate-wiki pre-flight probes reachability over ssh, not a local directory (0.12.0)" {
  run grep -Ei 'ConnectTimeout|ssh[^\n]*test -d' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
  run grep -iF 'unreachable' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
}

@test "propagate-wiki runs all repo I/O + validators over ssh, no local FS verbs on the wiki (0.12.0)" {
  run grep -F 'validate-frontmatter' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
  run grep -F 'resolve_links' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
  # no local Read/Edit/Write tool verbs pointed at the wiki path remain
  run grep -E '(Read|Edit|Write) "\$LLM_WIKI_ROOT' "$PROPAGATE_WIKI"
  [ "$status" -ne 0 ]
}

@test "propagate-wiki tools field is Bash-only (remote repo, no local FS tools) (0.12.0)" {
  run grep -E '^tools:[[:space:]]*Bash[[:space:]]*$' "$PROPAGATE_WIKI"
  [ "$status" -eq 0 ]
}

@test "audit-drift wiki phase reads over ssh, skips on unreachable host (0.12.0)" {
  run grep -F 'LLM_WIKI_SSH' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
  run grep -F '/srv/workspaces/llm-wiki' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
  # local default gone, and no local-tool Read against the remote wiki path
  run grep -F 'projects/llm-wiki' "$AUDIT_DRIFT"
  [ "$status" -ne 0 ]
  run grep -E 'Read\("?\$LLM_WIKI_ROOT' "$AUDIT_DRIFT"
  [ "$status" -ne 0 ]
  run grep -iF 'unreachable' "$AUDIT_DRIFT"
  [ "$status" -eq 0 ]
}
