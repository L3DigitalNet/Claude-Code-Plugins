# Skill: Scoped Re-audit

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
