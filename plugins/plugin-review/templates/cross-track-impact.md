# Cross-Track Impact Check

<!-- architectural-context
  Loaded by: commands/review.md (orchestrator) at Phase 4, before annotating each proposal.
  Not loaded by subagents — this is an orchestrator-only template.
  Output contract: the annotation format defined in the "Annotation Format" section is appended
    to each proposal in the Phase 4 output. If the format changes, the orchestrator's Phase 4
    presentation changes shape.
  Cross-file dependency: the track letters (A, B, C, D) used here must match the agent names
    in review.md Phase 2 and the track labels in pass-report.md and final-report.md.
    Adding a new track requires updating all five files simultaneously:
    cross-track-impact.md, review.md, pass-report.md, final-report.md, skills/scoped-reaudit/SKILL.md.
-->

Use this template in Phase 4 when annotating proposed changes.

## Impact Mapping

**Implementation files** (commands/, agents/, skills/, scripts/, src/, templates/):
- Track B (UX): affected if file produces user-visible output, error messages, or prompt strings
- Track C (Docs): affected if any documentation references the modified behavior
- Track D (Efficiency): affected if file contains inline content that could be referenced instead, or produces output whose verbosity may violate P2 or P6

**Templates** (templates/):
- Track A (Principles): affected if template is loaded by an agent definition
- Track B (UX): affected if orchestrator presents content from this template to the user
- Track C (Docs): affected if template is mentioned in README.md or docs/DESIGN.md
- Track D (Efficiency): affected if template duplicates content available elsewhere (P3) or is longer than its functional role requires (P1)

**Hooks** (hooks/, scripts/):
- Track A (Principles): always affected — adding/removing/modifying a hook changes enforcement layers
- Track B (UX): affected if hook produces user-visible output (stdout warnings)
- Track C (Docs): always affected — hooks are documented as enforcement mechanisms
- Track D (Efficiency): affected if hook output is verbose; mechanical enforcement layers are the most efficient form of enforcement, so adding a hook is usually a positive signal

**Documentation** (README.md, docs/DESIGN.md, CHANGELOG.md):
- Track A (Principles): affected if change touches `## Principles` section or enforcement layer descriptions
- Track B (UX): rarely affected unless docs serve as runtime help text
- Track D (Efficiency): affected if documentation duplicates inline content (P3) or contains more content than the reader needs to take the correct action (P1)

## Track A (Principles) Cross-Track Effects

- Track A → Track D: When Track A finds enforcement that relies on behavioral instructions where a mechanical layer would be more appropriate, that finding is simultaneously a Track D finding. Track A names the enforcement layer violation; Track D measures the context cost of repeating those behavioral instructions across every invocation.

## Track B (UX) Cross-Track Effects

- Track B → Track D: UX patterns involving verbose output formats or wordy error messages directly reflect P2 (Format Matches Data Type) and P6 (Output Verbosity) compliance. A UX finding about over-reporting is also a Track D finding.

## Track C (Docs) Cross-Track Effects

- Track C → Track D: Documentation verbosity and duplication are direct P1 (Imperative Minimalism) and P3 (Reference Over Repetition) signals. If Track C finds doc bloat, Track D will likely flag the same content as an efficiency violation.

## Track D (Efficiency) Cross-Track Effects

- Track D → Track A: Efficiency violations often expose behavioral-only enforcement where a mechanical layer would be more appropriate. Track D findings about repeated inline instructions are candidates for Track A's enforcement layer analysis.
- Track D → Track B: P6 violations (output verbosity) surface in the same user-facing touchpoints that Track B monitors. A Track D finding about excessive output is likely a Track B UX issue as well.
- Track D → Track C: P1 and P3 violations manifest as documentation duplication and verbosity. Track C will encounter the same findings framed as documentation quality issues.

## Annotation Format

For each proposal, append the annotation as an indented block to visually distinguish it from the proposal body:
```
  > **Cross-track impact**: <Track(s) affected> — <brief reason>
```

If no cross-track impact, explicitly state `None` — don't omit the annotation:
```
  > **Cross-track impact**: None
```
