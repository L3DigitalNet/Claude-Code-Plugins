# Plan: linux-sysadmin

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 3 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 1 (`scripts/sysadmin-context.sh`) |
| Existing tests | 0 |
| Framework | None (introduce bats) |
| Skills | 1 dispatcher (`sysadmin`) backed by 163 guide files |
| Hooks | Yes |

Principles: `[P1] Knowledge Over Tooling`, `[P2] One Guide, One Service`, `[P3] Complete Config References`, `[P4] Task-Organized, Not Alphabetical`.

The mechanical surface is tiny: one shell script + plugin manifest + a content tree of 163 guides. The bulk of the plugin is markdown content that's behavioral by design (P1's whole point is that the value is in *Claude reading the guides*, not in tools).

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Knowledge Over Tooling | Behavioral — out of scope | n/a | Whether Claude reasons better with the guides is a behavioral evaluation. |
| [P2] One Guide, One Service | Structural | `tests/guides-shape.bats` — every directory under `guides/` contains exactly one `guide.md`; no two `guide.md` files describe the same service (deduce from frontmatter `service:` field if present, else dir-name uniqueness). | Mechanical encoding of "one guide, one service." |
| [P3] Complete Config References | Structural | `tests/guides-shape.bats` — every `guide.md` referencing a config file in `references/<service>/` has the corresponding reference file present. (Skip if no reference is mentioned.) | Mechanical encoding of "complete reference" — flags broken cross-links cheaply. |
| [P4] Task-Organized, Not Alphabetical | Behavioral — out of scope | n/a | Cheatsheet ordering quality is a content judgment. |
| Cross-cutting (script) | Mechanical | `tests/sysadmin-context.bats` — script exits 0 with deterministic output for a known input; non-zero exit for malformed input emits raw error to stderr. (Test scope depends on what the script actually does — see Risks.) | Establishes the script's contract as a baseline so future edits don't drift silently. |
| Cross-cutting (manifest) | Structural | `tests/manifest.bats` — `plugin.json` parses, has the five valid fields only (no `category`/`keywords`/`license`). | Marketplace-wide mechanical guard; trivial to add and catches Zod-strict drift. |

## Files to create

```
plugins/linux-sysadmin/tests/
├── guides-shape.bats
├── sysadmin-context.bats
└── manifest.bats
```

## Fixtures needed

- None for `guides-shape.bats` — operates over the real `guides/` tree.
- `sysadmin-context.bats` may need a fake guide tree in `BATS_TMPDIR` — depends on what the script reads. Resolve at execution time.

## Runtime estimate

- 3 bats files × ~3 cases = 9 cases. Sub-second suite.
- `guides-shape.bats` iterates all 163 guides — still well under 1 s in pure-bash glob loops.

## Risks (flag, do not fix)

1. **`sysadmin-context.sh` may not have a stable text contract.** Per the README, the plugin is mostly content; the script may just output a debug banner. If so, the script-test reduces to "exit code 0, stable banner" and the principle coverage stays Behavioral. **Flag** if there's no real contract worth asserting beyond exit code.
2. **163 guides means broken-link checking surface is large.** If `guides-shape.bats` discovers existing broken cross-links, **report them without fixing** in the plan execution summary. The user decides whether to address content gaps.
3. **`hooks/` exists but the README mentions no hook scripts.** Inspect on execution; if hook scripts exist without docs, add a plain "exit 0 / stable JSON" test and flag the doc gap.

## What this plan does NOT do

- Validate the *content* of any guide. Content correctness is behavioral.
- Test the `/sysadmin` interactive command flow. Behavioral.
- Modify the script or any guide file.
