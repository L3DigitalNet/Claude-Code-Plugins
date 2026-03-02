<!--
Entry point for the context efficiency review workflow.
Loads ${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-reference/SKILL.md (P1-P12 definitions) and ${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-workflow/SKILL.md (workflow).
Both skills are required; the review workflow references principles by ID from the reference skill.
If either skill file path changes, update this command to match.
-->

# Context Efficiency Review

Audits a plugin against twelve context efficiency principles across five approval-gated stages. No changes are made without explicit user approval at each stage.

Read `${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-reference/SKILL.md` in full.
Read `${CLAUDE_PLUGIN_ROOT}/skills/context-efficiency-workflow/SKILL.md` in full.

Use `AskUserQuestion` to ask which plugin to review. Provide one option for entering a root directory path (e.g., `plugins/my-plugin`) and one for pasting a file list. If the provided path does not exist or cannot be read, stop immediately and report the exact path and error — do not guess an alternative.

Execute the five-stage review process as specified. Do not skip stages, combine stages, or begin implementation without explicit approval at each checkpoint.
