# Track C: Documentation Freshness Criteria

Load this template when performing documentation freshness analysis. It defines the five drift categories and the methodology for detecting each one.

## Drift Category 1: Accuracy

Do documented behaviors, tool names, parameter descriptions, and examples match what the code actually does? For each claim in the documentation, locate the implementation it references. If the implementation differs from the documentation, that's a finding. Flag threshold: any description that would mislead a user or future developer.

## Drift Category 2: Completeness

Are all user-facing tools, commands, hooks, and configuration options documented? Compare the directory listing against the documentation's table of contents, architecture description, and usage sections. Any implementation component with no documentation mention is a finding. Undocumented internal utilities are findings only if they represent architectural decisions a future developer would need to understand.

## Drift Category 3: Orphaned References

Does the documentation describe features, flags, or behaviors that no longer exist? For each named component in the documentation, verify it exists in the directory listing. This includes partially removed features where some references were cleaned up but others weren't.

## Drift Category 4: Principle–Implementation Consistency

Do the `## Principles` entries in the README accurately describe the enforcement mechanisms in use? If the Principles Analyst (Track A) found that a principle's enforcement layer differs from what's stated, the documentation must be updated to reflect the actual layer. Cross-reference Track A findings with README principle descriptions.

## Drift Category 5: Examples and Usage Sections

Do code examples or usage instructions still work given the current implementation? Trace each example through the current implementation: does the described trigger activate the described command? Does the workflow sequence match the actual phase order? Would configuration examples be valid input?

## Trigger Classification

For each finding, classify the cause:

**Pre-existing drift**: The documentation was already stale before this review. The implementation was changed at some prior point without updating docs.

**Introduced by Pass N changes**: Drift introduced by changes made during this review session. Cite the specific pass and file change. This classification is especially important because the review process itself should never introduce doc drift — if it does, the orchestrator must address it immediately.
