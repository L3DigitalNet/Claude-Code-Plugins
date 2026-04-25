# Plan: handoff

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 4 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 2 (`scripts/find-latest-handoff.sh`, `scripts/gather-context.sh`) |
| Existing tests | 2 bats files (`tests/find-latest-handoff.bats`, `tests/gather-context.bats`) |
| Framework | bats |
| Coverage ratio | 1 test file per script (nominal) |

Principles: `[P1] Complete Context`, `[P2] Actionable Next Steps`. Both target the *content of handoff files* generated/consumed by Claude — neither is about the scripts. Existing bats files cover happy-path script mechanics.

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Complete Context | Behavioral — out of scope | n/a | The principle constrains what Claude writes to a handoff file, not how the script gathers context. Coverage = template review or PTH session, not unit. |
| [P2] Actionable Next Steps | Behavioral — out of scope | n/a | Same. |
| Cross-cutting (script — `find-latest-handoff`) | Mechanical | Extend existing `tests/find-latest-handoff.bats` — given a directory with multiple handoff files (different mtimes + lexical timestamps), returns the latest by **timestamp in filename**, not mtime. | Filename-timestamp ordering is the load-bearing claim; mtime-order would silently misbehave on copy/move. |
| Cross-cutting (script — `find-latest-handoff`) | Mechanical | Extend — empty directory returns non-zero exit and a single-line "no handoffs found" message; no stack trace. | Quiet-fail-transparent contract for `/handoff:load` UX. |
| Cross-cutting (script — `find-latest-handoff`) | Mechanical | Extend — symlinked share path (`/mnt/share/instructions/`) is followed correctly; broken symlink fails loudly, not silently. | Real shared-mount edge case. |
| Cross-cutting (script — `gather-context`) | Mechanical | Extend existing `tests/gather-context.bats` — handoff name with spaces is sanitized to a safe filename (no shell-injection of the name into a path). | Security boundary on user-controlled input. |
| Cross-cutting (script — `gather-context`) | Mechanical | Extend — git-status section is included when in a git repo; absent (not erroring) when not in a git repo. | Robustness across machine contexts (not all infra hosts are git repos). |
| Cross-cutting (manifest) | Structural | `tests/manifest.bats` (new) — `plugin.json` schema sanity check (Zod-strict allow-list). | Marketplace-wide guard. |

## Files to create / modify

```
plugins/handoff/tests/
├── find-latest-handoff.bats   (extend with 3 cases)
├── gather-context.bats        (extend with 2 cases)
└── manifest.bats              (new)
```

## Fixtures needed

- Inline `setup()`: temporary handoff dir with three sample files at known timestamps.
- Inline `setup()`: temp git repo for the gather-context git-section assertion.

## Runtime estimate

- 5–6 added bats cases + 2 in new manifest file. Sub-second.

## Risks (flag, do not fix)

1. **`gather-context.sh` may shell-interpolate the name argument directly.** If shell-injection sanitization isn't present, the test will reveal it. **Report the finding**, do not fix the script in Phase 2 — escalate via the per-plugin completion report.
2. **`/mnt/share/instructions/` is referenced as the share path.** Tests must use `BATS_TMPDIR`-rooted fakes; `find-latest-handoff` should accept an override variable. If it hardcodes the path, flag the un-overridable seam.

## What this plan does NOT do

- Test handoff *file content* quality. That's behavioral.
- Test the `/handoff:save` or `/handoff:load` command markdown. Behavioral.
- Modify the scripts.
