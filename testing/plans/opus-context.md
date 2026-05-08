# Plan: opus-context

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 2 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 1 (`scripts/session-start.sh`) |
| Existing tests | 0 |
| Framework | None (introduce bats) |
| Hooks | Yes — SessionStart |
| Agents | No |

Principles: `[P1] Read More, Not Less`, `[P2] Own Your Context`, `[P3] Load Before You Leap`, `[P4] Budget Awareness`. All four are behavioral instructions injected into baseline context — the *only* mechanical surface is the SessionStart hook script that emits SKILL.md as `additionalContext` JSON.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| All [P1]–[P4] | Behavioral — out of scope | n/a | Rules are interpreted by the model, not by the script. Coverage = behavioral evaluation in a session, not a unit test. |
| Cross-cutting (hook contract) | Mechanical | `tests/session-start.bats` — given `SKILL.md` exists, hook stdout is valid JSON with `hookSpecificOutput.additionalContext` containing the SKILL.md body **with frontmatter stripped**. | The README explicitly states this contract. Without it, the rules don't reach Claude. Highest-value mechanical assertion in the plugin. |
| Cross-cutting (hook contract) | Mechanical | `tests/session-start.bats` — given `SKILL.md` is missing, hook exits non-zero and emits an error to stderr (not silent). | Failure transparency at the hook seam. |
| Cross-cutting (hook contract) | Mechanical | `tests/session-start.bats` — frontmatter delimiters (`---`) are not present in emitted body. | Prevents stale frontmatter from leaking into context, which would break behavioral rules with prefix YAML noise. |
| Cross-cutting (hook contract) | Structural | `tests/hooks-config.bats` — `hooks/hooks.json` has `SessionStart` event keyed in record form, not array. | Repeats the marketplace-wide hooks.json gotcha; cheap insurance. |

## Files to create

```
plugins/opus-context/tests/
├── session-start.bats
└── hooks-config.bats
```

No fixtures directory — bats `setup()` writes a temporary fake `SKILL.md` and points the script at it via the plugin-root variable used by the hook.

## Fixtures needed

- Inline in `setup()`: a minimal valid `SKILL.md` with frontmatter and body; an "absent SKILL.md" variant (delete file in setup).

## Runtime estimate

- 2 bats files × ~4 cases = 8 cases. Sub-second suite.

## Risks (flag, do not fix)

1. **`session-start.sh` may use a `${CLAUDE_PLUGIN_ROOT}` reference that's not overridable in tests.** If the script hardcodes the plugin path, flag it. Workaround: bats tests run from a temp dir with `${CLAUDE_PLUGIN_ROOT}` exported. If the script also does `cd "$(dirname "$0")"` and that breaks the override, flag and pend the test. **Do not refactor the script.**
2. **Frontmatter-stripping logic** may be regex-fragile. Test with both `---\n` and `---\r\n` line endings — if the script handles only one, document the discrepancy.

## What this plan does NOT do

- Test that the rules in `SKILL.md` actually change Claude's behavior. That's a behavioral evaluation problem, not a unit test.
- Add a CI workflow.
- Modify the hook script.
