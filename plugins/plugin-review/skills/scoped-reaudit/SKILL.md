# Skill: Scoped Re-audit

<!-- architectural-context
  Loaded by: commands/review.md (orchestrator) at Phase 2, Pass 2+ only — not on Pass 1.
  Consumer: the orchestrator reads this file and applies the mapping table manually;
    there is no programmatic parsing of this file's output.
  Output contract: the orchestrator extracts the Track A / Track B / Track C determination
    from the File-to-Track Mapping section. Track letters (A, B, C) must match the agent
    names used in review.md Phase 2's spawn instructions.
  Autonomous mode addition: the regression-guard agent is an exception to the A/B/C mapping.
    It always runs on Pass 2+ in autonomous mode regardless of which files changed. Its spawn
    decision is not derived from this skill's track table — see "Regression Guard Exception" below.
  Cross-file dependency: if the mapping table changes, review.md Phase 2 instructions
    must be re-read to verify consistency with the new track scope definitions.
  What breaks if format changes: the orchestrator reading this skill expects the mapping
    to cover commands/, agents/, skills/, hooks/, scripts/, src/, templates/ as patterns.
    Adding new plugin component types requires a corresponding mapping entry here.
-->

Determines which analysis tracks need re-running based on files modified in the previous pass. The orchestrator consults this skill before spawning subagents on Pass 2+.

## Trigger

The orchestrator has completed a batch of implementation changes and needs to determine which subagents to spawn for the re-audit pass.

## File-to-Track Mapping

**Track A (Principles Analyst)** is affected when any of these were modified: `commands/*.md`, `agents/*.md`, `skills/*/SKILL.md`, `hooks/hooks.json`, `scripts/*.sh`, `.mcp.json`, `src/**`, `templates/*.md`, or the `## Principles` section of `README.md`.

**Track B (UX Analyst)** is affected when any of these were modified: `commands/*.md`, `agents/*.md`, `templates/pass-report.md`, `templates/final-report.md`, `scripts/*.sh` (if they produce stdout), or any file in `src/` that produces formatted output or handles errors.

**Track C (Docs Analyst)** is affected when **any file was modified**. Documentation drift can be introduced by any change. Track C always runs on re-audit.

## Decision Logic

For each modified file, match against Track A and Track B patterns. Add "C" unconditionally. Deduplicate and return the affected tracks.

## Conservative Default

If uncertain whether a file change affects a track, include it. The cost of an unnecessary subagent spawn is much lower than missing a regression.

## Unchanged Finding Carryover

For tracks NOT re-audited, carry forward all findings from the previous pass as "Unchanged from Pass N." For tracks that ARE re-audited, the subagent produces a fresh analysis that the orchestrator compares against the previous pass to detect status changes, new findings, and resolutions.

## Special Case: README.md or docs/DESIGN.md Modified

Track C must re-analyze for internal consistency. Track A should be included if the `## Principles` section was modified, since principle definitions are what Track A measures against. Track B is typically unaffected by documentation changes.

## Regression Guard Exception [AUTONOMOUS MODE ONLY]

The regression-guard agent (`agents/regression-guard.md`) is not part of the A/B/C track system. It operates on a fixed spawn rule:

- **Always spawned on Pass 2+** in autonomous mode, regardless of which files changed
- **Never spawned on Pass 1** (no previously-fixed findings exist)
- **Never spawned in interactive mode** (regression guard is autonomous-only)

The regression guard does not have a track mapping because it checks previously-fixed findings across all tracks. Its input is the `fixed_findings` array from `.claude/state/plugin-review-writes.json`, not a list of modified files. Consult this exception rule before spawning to ensure the regression guard is not incorrectly treated as a track-conditional agent.
