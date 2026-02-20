# Cross-Track Impact Check

<!-- architectural-context
  Loaded by: commands/review.md (orchestrator) at Phase 4, before annotating each proposal.
  Not loaded by subagents — this is an orchestrator-only template.
  Output contract: the annotation format defined in the "Annotation Format" section is appended
    to each proposal in the Phase 4 output. If the format changes, the orchestrator's Phase 4
    presentation changes shape.
  Cross-file dependency: the track letters (A, B, C) used here must match the agent names
    in review.md Phase 2 and the track labels in pass-report.md and final-report.md.
    Adding a new track requires updating all four files simultaneously.
-->

Use this template in Phase 4 when annotating proposed changes.

## Impact Mapping

**Implementation files** (commands/, agents/, skills/, scripts/, src/, templates/):
- Track B (UX): affected if file produces user-visible output, error messages, or prompt strings
- Track C (Docs): affected if any documentation references the modified behavior

**Templates** (templates/):
- Track A (Principles): affected if template is loaded by an agent definition
- Track B (UX): affected if orchestrator presents content from this template to the user
- Track C (Docs): affected if template is mentioned in README.md or docs/DESIGN.md

**Hooks** (hooks/, scripts/):
- Track A (Principles): always affected — adding/removing/modifying a hook changes enforcement layers
- Track B (UX): affected if hook produces user-visible output (stdout warnings)
- Track C (Docs): always affected — hooks are documented as enforcement mechanisms

**Documentation** (README.md, docs/DESIGN.md, CHANGELOG.md):
- Track A (Principles): affected if change touches `## Principles` section or enforcement layer descriptions
- Track B (UX): rarely affected unless docs serve as runtime help text

## Annotation Format

For each proposal, append the annotation as an indented block to visually distinguish it from the proposal body:
```
  > **Cross-track impact**: <Track(s) affected> — <brief reason>
```

If no cross-track impact, explicitly state `None` — don't omit the annotation:
```
  > **Cross-track impact**: None
```
