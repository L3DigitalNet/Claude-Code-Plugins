# Plan: home-assistant-dev

> **Status: Phase 1 plan — execute only after STRATEGY.md is approved.**
> **Phase 2 priority: 14 of 15.**

## Current state

| Field | Value |
|---|---|
| Source files | 5 Python scripts in `scripts/` + 12 TS files in `mcp-server/src/` (entry + 2 utils + 8 tools + 1 docs-index) |
| Existing tests | 7 pytest (across `tests/scripts/`, `tests/validation/`, `tests/integration/`, `tests/test_plugin_structure.py`, examples' tests) + 3 Jest in `mcp-server/__tests__/` + 2 e2e .mjs |
| Framework | pytest (Python) + Jest (TS) |
| CI | **YES** — `ha-dev-plugin-tests.yml` runs unit/integration/structural/typescript and gated e2e |
| Markers | `unit`, `integration`, `validation` |

This is the **most-tested plugin in the marketplace**. Plan is fine-grained gap-fill.

Principles (from README): `Act on Intent`, `Scope Fidelity`, `Use the Full Toolkit`, `Succeed Quietly, Fail Transparently`. (Match CLAUDE.md global P1, P2, P4, P3 — no plugin-specific principles introduced.)

## Gap table

| Principle | Layer | Proposed test | Rationale |
|---|---|---|---|
| [P1] Act on Intent | Behavioral — out of scope | n/a | Command flow gating; covered by user invocation. |
| [P2] Scope Fidelity | Mechanical | New `tests/scripts/test_generate_integration.py` (or extend if exists) — generating a Silver-tier integration produces every required file (manifest, coordinator, config_flow, entity, translations) in one pass. Inspect generated tree on tmp_path. | Full-tier-output completeness check. |
| [P3] Succeed Quietly, Fail Transparently | Mechanical | Extend existing `mcp-server/__tests__/safety.test.ts` — service-call to `homeassistant.restart` returns `isError: true` with structured error; allowed service returns success quietly. | Already partially covered; verify completeness. |
| [P4] Use the Full Toolkit | Behavioral — out of scope | n/a | `AskUserQuestion` use is in command markdown. |
| Cross-cutting (validation hooks) | Mechanical | Extend `tests/scripts/test_validate_manifest.py` — covers all 52 IQS rules called out in README; spot-check 5 most common rule violations have explicit tests. | IQS coverage is the plugin's headline claim — need to confirm rule-level tests exist. |
| Cross-cutting (validation hooks) | Mechanical | New `tests/scripts/test_validate_strings.py` (extend existing if present) — translations.json missing → flagged; `service_calls.<service>.name` mismatch with strings → flagged. | strings.json validation is fragile. |
| Cross-cutting (post-write-hook) | Mechanical | New `tests/scripts/test_post_write_hook.py` — given a Write to a manifest.json path, hook dispatches to `validate-manifest.py`; given Write to a strings.json, dispatches to `validate-strings.py`; given Write to a non-HA file, no-op. | Hook dispatcher routing. |
| Cross-cutting (MCP `ha_connect`) | Mechanical | Extend `mcp-server/__tests__/` — connection failure (bad URL/token) returns structured error; success returns connection metadata; subsequent calls reuse connection (no double-handshake). | Connection lifecycle. |
| Cross-cutting (MCP `docs_search`) | Mechanical | New `mcp-server/__tests__/docs-search.test.ts` (or extend `docs-index.test.ts`) — query returns ranked results; query with no matches returns empty with the message; search index built from on-disk docs at startup. | Docs search is the most-used tool by users. |

## Files to create / modify

```
plugins/home-assistant-dev/
├── tests/scripts/
│   ├── test_check_patterns.py        (existing)
│   ├── test_validate_manifest.py     (extend — IQS rule coverage)
│   ├── test_validate_strings.py      (new or extend)
│   ├── test_post_write_hook.py       (new)
│   └── test_generate_integration.py  (new — tier completeness)
├── tests/validation/test_iqs_accuracy.py  (existing)
├── tests/integration/                (existing — script-against-examples)
├── tests/test_plugin_structure.py    (existing)
└── mcp-server/__tests__/
    ├── docs-index.test.ts            (existing)
    ├── safety.test.ts                (extend — error shape)
    ├── validate-manifest.test.ts     (existing)
    ├── ha-connect.test.ts            (new)
    └── docs-search.test.ts           (new)
```

## Fixtures needed

- `tests/fixtures/iqs-rule-cases/` — 52 minimal manifest fixtures triggering each IQS rule; spot-check the 5 most-violated.
- `tests/fixtures/post-write-hook-inputs/` — JSON inputs for each routing branch.
- `mcp-server/test/fixtures/ha-responses/` — canned HA REST responses for `ha-connect.test.ts`.

## Runtime estimate

- ~5 new + ~3 extended Python tests × ~4 cases = ~30 cases.
- ~2 new + ~1 extended Jest tests × ~4 cases = ~12 cases.
- Total ~40 cases. ~30–60 s (Python pytest startup + Jest ESM startup).

## Risks (flag, do not fix)

1. **IQS rule coverage may already be exhaustive** in `test_iqs_accuracy.py`. On execution, audit existing test names against the 52 rules; only add tests for genuinely missing rules. Avoid duplication.
2. **`post-write-hook.sh` is a bash dispatcher** but tests are in pytest. Tests must `subprocess.run` the hook with stdin JSON. If `bash` isn't on the test runner's PATH (CI Ubuntu has it), no issue.
3. **The MCP server is bundled into `mcp-server/dist/server.bundle.cjs`**; tests run against `src/` directly. Bundle drift between `src/` and `dist/` is possible. **Flag** if a test against `src/` passes but the bundle is broken — surface to user.
4. **e2e tests in `tests/e2e/test-mcp-{rest,websocket}.mjs`** require a live HA container. Phase 2 does not extend these — gated by `run-e2e` PR label per workflow config.

## What this plan does NOT do

- Test the agents (`ha-integration-dev`, `ha-integration-reviewer`, `ha-integration-debugger`). Behavioral.
- Test the 27 skills' auto-activation. Behavioral.
- Extend e2e suite. Out of scope (CI changes).
- Modify scripts or MCP server source.
