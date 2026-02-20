<!--
Entry point for the markdown tightening workflow.
Loads MARKDOWN_TIGHTEN.md which contains all five-step behavioral logic.
If the skill file path changes, update this command to match.
-->

# Tighten Markdown

Rewrites instruction markdown files for token efficiency via a five-step, approval-gated process. Operates on one file at a time.

Read `.claude/skills/MARKDOWN_TIGHTEN.md` in full.

Use `AskUserQuestion` to ask for the target — a specific file path (e.g., `plugins/my-plugin/skills/SKILL.md`) or a directory path. If they provide a directory, list the markdown files within it as a numbered list and ask them to reply with the numbers of the files to process, in order. If the provided path does not exist or cannot be read, stop immediately and report the exact path and error — do not guess an alternative.

Execute the five-step process as specified for each file. Do not skip steps or write changes without explicit approval at each checkpoint.
