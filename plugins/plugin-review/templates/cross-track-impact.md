# Cross-Track Impact Check

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

For each proposal, append:
```
**Cross-track impact**: <Track(s) affected> — <brief reason>
```

If no cross-track impact, explicitly state "None" — don't omit the annotation.
