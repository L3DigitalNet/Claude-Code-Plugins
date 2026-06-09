# Claude Code Instructions

Follow `AGENTS.md` or the resolved canonical instruction source as the primary implementation contract.

## Claude-specific behavior

- If `CLAUDE.md` or `AGENTS.md` is a pointer, resolve the referenced session memory or handoff source before editing.
- Read `pyproject.toml`, the resolved agent instructions, and the relevant tests before editing.
- Prefer small, reviewable changes.
- Preserve the existing architecture unless asked to refactor.
- Use types to clarify intent before adding comments.
- Add or update tests with every behavior change.
- Run the verification gate before reporting completion.
- Report any command failures honestly with the relevant error summary.

## Do not

- Do not add dependencies without a clear reason.
- Do not weaken type checking to make errors disappear.
- Do not remove tests because they fail.
- Do not create parallel tooling systems.
- Do not add personal VS Code preferences.
