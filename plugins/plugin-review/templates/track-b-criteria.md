# Track B: Terminal UX Criteria

Load this template when performing terminal UX analysis. It defines the four evaluation categories and their specific criteria for Claude Code plugin interfaces.

## Category 1: Information Density & Readability

**No walls of text.** Any output longer than ~8–10 lines should be restructured. Techniques: progressive disclosure, summaries with drill-down, chunked output with headers, or tabular layout. If a tool dumps 20+ lines of undifferentiated text, that's a finding.

**Lead with the answer.** The most important information should appear in the first 1–2 lines. If the user has to read through background to find the actual result, that's a finding.

**Use visual hierarchy.** Markdown headers for sections, bold for key terms, consistent indentation. Don't over-format — scannable, not decorative. If every other word is bold or every line has an emoji prefix, that's also a finding.

**Consistent formatting patterns.** Similar outputs should look similar every time. If a tool formats success differently in different code paths, that's a finding.

## Category 2: User Input & Interaction

**Prefer structured choice questions over free-text prompts.** Whenever input can be scoped to bounded choices, present numbered options or yes/no questions rather than open-ended text prompts. If a prompt asks the user to type one of several known options instead of presenting them as choices, that's a finding.

**Minimize round-trips.** Related inputs should be collected in a single interaction. If a workflow asks three sequential yes/no questions that could be a multi-select, that's a finding.

**Smart defaults.** When a reasonable default exists, pre-select it or offer it as the first option. If the user has to specify something inferable from context, that's a finding.

**Confirm destructive actions (but don't over-confirm).** Irreversible operations get confirmation. Routine low-risk operations should not. If a plugin confirms non-destructive actions or skips confirmation on destructive ones, that's a finding.

## Category 3: Progress & Feedback

**Show progress for long operations.** Any operation taking more than a couple seconds should indicate what's happening. If a tool goes silent for several seconds, that's a finding.

**Clear success/failure signals.** After any operation the user should immediately know the outcome. Use concise messages ("✓ Created 3 files"). If the user must infer success from absence of error, that's a finding.

**Actionable error messages.** Errors should say what went wrong AND what the user can do about it. Raw API responses or stack traces without guidance are findings.

## Category 4: Terminal-Specific Considerations

**Respect terminal width.** Lines shouldn't wrap awkwardly at 80–120 columns. Tables should degrade gracefully.

**Color and emoji usage.** Good: ✓ for success, ✗ for failure, ⚠ for warning. Bad: decorative emoji on every line, color for emphasis rather than semantics.

**Copy-paste friendliness.** Copyable content (paths, commands, IDs) should be easy to select without surrounding punctuation noise.

## Severity Classification

**🔴 High impact**: Confusing, broken, or unusable. The user cannot complete their action or is actively misled.

**🟡 Medium impact**: Works but creates unnecessary friction. Takes more effort than it should, or messaging causes hesitation.

**🟢 Low impact**: Functional and clear but could be more polished. Nice-to-haves that improve without fixing a problem.
