# HA Dev Plugin Self-Test Results

**Date:** 2026-02-17 (Categories 1-4), 2026-02-18 (Category 5)
**Claude Code Model:** Claude Opus 4.6
**Plugin Version:** 2.2.1

## Summary

- Skill Trigger Tests: **19/19 passed**
- Code Generation Tests: **7/7 passed**
- Validation Script Tests: **5/5 passed** (after fix)
- Agent Tests: **3/3 passed**
- MCP REST API Tests: **24/24 passed**
- MCP WebSocket Tests: **38/39 passed** (1 test expectation issue, not a bug)

**Total: 96/97 passed (99%)**

## Test Environment

- **HA Instance:** v2026.2.2 (Docker via podman, `demo` integration enabled)
- **Entities:** 116 across 15+ domains
- **Devices:** 52
- **Services:** 232 across 58 domains
- **MCP Config:** `~/.config/ha-dev-mcp/config.json` (LLAT auth, safety enabled)

---

## Skill Trigger Tests (19/19 PASS)

All 19 skills have well-defined descriptions that match their test prompts:

| Skill | Test Prompt | Result |
|-------|-------------|--------|
| ha-architecture | "Explain how the Home Assistant event bus works" | PASS |
| ha-integration-scaffold | "Create a new integration called test_device" | PASS |
| ha-config-flow | "Add a reauth flow to my integration" | PASS |
| ha-coordinator | "How do I handle errors in DataUpdateCoordinator?" | PASS |
| ha-entity-platforms | "Create a sensor entity for temperature" | PASS |
| ha-service-actions | "Add a custom service to my integration" | PASS |
| ha-async-patterns | "How do I make async HTTP requests in HA?" | PASS |
| ha-testing | "Write tests for my config flow" | PASS |
| ha-debugging | "My integration won't load, help me debug" | PASS |
| ha-yaml-automations | "Create an automation that turns on lights at sunset" | PASS |
| ha-quality-review | "Review this integration for IQS compliance" | PASS* |
| ha-hacs | "Prepare my integration for HACS" | PASS |
| ha-diagnostics | "Add diagnostics support to my integration" | PASS |
| ha-migration | "Update my integration for HA 2025" | PASS |
| ha-documentation | "Generate README for my integration" | PASS |
| ha-repairs | "Add repair issues to my integration" | PASS |
| ha-device-triggers | "Add device triggers to my integration" | PASS |
| ha-websocket-api | "Add a custom websocket command" | PASS |
| ha-recorder | "Add long-term statistics to my sensor" | PASS |

*Note: `ha-quality-review` has `disable-model-invocation: true` — requires explicit invocation, which is intentional.

---

## Code Generation Quality Tests (7/7 PASS)

### Scaffold Integration

**Prompt:** "Create a new Home Assistant integration called my_weather that polls a REST API every 5 minutes for weather data"

| Check | Result |
|-------|--------|
| validate-manifest.py passes | PASS |
| validate-strings.py passes | PASS |
| check-patterns.py passes | PASS (after fix) |
| Uses `entry.runtime_data` not `hass.data[DOMAIN]` | PASS |
| Has `_attr_has_entity_name = True` | PASS |
| Coordinator has generic type parameter `DataUpdateCoordinator[dict[str, Any]]` | PASS |
| Uses modern imports (no deprecated ServiceInfo) | PASS |

---

## Validation Script Tests (5/5 PASS)

| Test | Script | Expected | Result |
|------|--------|----------|--------|
| Missing manifest fields | validate-manifest.py | Report 6 missing fields | PASS (found 6 errors + 1 bonus) |
| Deprecated patterns | check-patterns.py | Catch 3 issues | PASS (1 error, 2 warnings) |
| Missing strings step | validate-strings.py | Report missing "confirm" | PASS (found + 3 bonus warnings) |
| Missing future annotations (positive) | check-patterns.py | Flag file without import | PASS |
| Has future annotations (negative) | check-patterns.py | No false positive | PASS (after fix) |

---

## Agent Tests (3/3 PASS)

| Agent | Structure | Skills | Tools | Description | Result |
|-------|-----------|--------|-------|-------------|--------|
| ha-integration-dev | Valid frontmatter | 7 skills | Read, Write, Edit, Bash, Grep, Glob | PROACTIVE trigger | PASS |
| ha-integration-reviewer | Valid frontmatter | 3 skills | Read, Grep, Glob, Bash (read-focused) | PROACTIVE trigger | PASS |
| ha-integration-debugger | Valid frontmatter | 3 skills | Read, Edit, Bash, Grep, Glob | PROACTIVE trigger | PASS |

---

## MCP REST API Tests (24/24 PASS)

| Test | Result | Detail |
|------|--------|--------|
| HA Connection: version | PASS | v2026.2.2 |
| HA Connection: location | PASS | HA Dev Plugin Test |
| HA Connection: components loaded | PASS | 153 components |
| HA Connection: demo integration | PASS | |
| Entity Query: total entities | PASS | 116 entities |
| Entity Query: sensors | PASS | 20 sensors |
| Entity Query: lights | PASS | 6 lights |
| Entity Query: switches | PASS | 2 switches |
| Entity Query: light.bed_light | PASS | |
| Entity Query: light.ceiling_lights | PASS | |
| Entity Query: sensor.outside_temperature | PASS | |
| Service Discovery: domains returned | PASS | 58 domains |
| Service Discovery: light domain | PASS | |
| Service Discovery: light.turn_on | PASS | |
| Service Discovery: light.turn_off | PASS | |
| Service Discovery: light.toggle | PASS | |
| Dry Run: service light.turn_on exists | PASS | |
| Dry Run: target light.bed_light exists | PASS | |
| Dry Run: validation passed | PASS | Would call light.turn_on on light.bed_light (state: off) |
| Dry Run: non-existent entity rejected | PASS | light.nonexistent correctly not found |
| Entity Attributes: has attributes | PASS | |
| Entity Attributes: has friendly_name | PASS | Bed Light |
| Entity Attributes: has supported_features | PASS | features: 4 |
| Logs: accessible | PASS | 355 lines |

---

## MCP Server WebSocket Tests (38/39 PASS)

| Test | Result | Detail |
|------|--------|--------|
| WS Connect: connected | PASS | |
| WS Connect: version | PASS | v2026.2.2 |
| WS Connect: location | PASS | HA Dev Plugin Test |
| WS Connect: components | PASS | 153 components |
| WS Connect: demo loaded | PASS | |
| WS Connect: isConnected() | PASS | |
| getStates: all entities | PASS | 116 entities |
| getStates: has entity_id | PASS | |
| getStates: has state | PASS | |
| getStates: has attributes | PASS | |
| getStates: has last_changed | PASS | |
| getStates: domain=sensor | PASS | 20 sensors |
| getStates: domain filter correct | PASS | |
| getStates: entity=light.bed_light | PASS | state: off |
| getStates: entity attributes | PASS | Bed Light |
| getServices: all | PASS | 232 services |
| getServices: light.turn_on found | PASS | |
| getServices: has description | FAIL | empty string (HA 2026.2 uses name, not description) |
| getServices: has fields | PASS | |
| getServices: domain=light | PASS | turn_on, turn_off, toggle |
| getServices: domain filter correct | PASS | |
| validateServiceCall: valid call | PASS | |
| validateServiceCall: invalid entity | PASS | Entity light.nonexistent not found |
| validateServiceCall: fake service | PASS | Service fake.missing not found |
| Safety: homeassistant.stop blocked | PASS | |
| Safety: light.turn_on allowed (dry_run) | PASS | |
| Safety: getSafetyInfo() | PASS | calls=true, dryRun=false, blocked=6 |
| Safety: input_boolean is safe | PASS | |
| Safety: homeassistant is not safe | PASS | |
| Safety: redacts api_key | PASS | |
| Safety: redacts password | PASS | |
| Safety: preserves brightness | PASS | |
| getDevices: accessible | PASS | 52 devices |
| getDevices: has id | PASS | |
| getDevices: has name | PASS | |
| getLogs: accessible | PASS | 3 log entries |
| getConnectionInfo: returns data | PASS | |
| getConnectionInfo: matches connect | PASS | |
| Disconnect: clean | PASS | |

---

## Issues Found and Fixed

### Issue 1: `check-patterns.py` false positive on `from __future__ import annotations`

- **Test:** Code Generation Quality Test — check-patterns.py
- **Expected:** No warnings for files that already have `from __future__ import annotations`
- **Actual:** Every function with type annotations flagged as missing the import
- **Root Cause:** The regex `^(?!.*from __future__ import annotations).*\bdef\s+\w+\s*\([^)]*:\s*\w+` uses a per-line negative lookahead, but the import is at the file level. Since function definitions are never on the same line as the import, it always matches.
- **Fix:** Moved to file-level check using a lambda that checks the entire file content for the import before flagging.
- **File:** `plugins/home-assistant-dev/scripts/check-patterns.py` (lines 186-198 replaced)
- **Fixed in:** v2.0.1

### Issue 2: `check-patterns.py` false positive on base entity classes missing `unique_id`

- **Test:** Code Generation Quality Test — check-patterns.py
- **Expected:** No warning for base entity classes (unique_id set in subclasses by design)
- **Actual:** `entity.py` flagged for missing `unique_id` even though it's a base class
- **Root Cause:** The regex `class\s+\w+Entity[^:]*:` with `MULTILINE|DOTALL` was run per-line, always matching entity class declarations. Also, the check didn't distinguish base entity classes from concrete entity classes.
- **Fix:** Moved to file-level check that only flags concrete entity classes (those inheriting from `SensorEntity`, `SwitchEntity`, etc.) rather than base classes (inheriting from `CoordinatorEntity`).
- **File:** `plugins/home-assistant-dev/scripts/check-patterns.py` (unique_id pattern restructured)
- **Fixed in:** v2.0.1

### Issue 3: `HaClient.connect()` converts http:// to ws:// before passing to library

- **Test:** WS Connect
- **Expected:** Successful connection to HA
- **Actual:** `TypeError: Invalid URL`
- **Root Cause:** `createLongLivedTokenAuth()` from `home-assistant-js-websocket` expects an HTTP URL. It handles the WebSocket URL conversion internally. The `HaClient.connect()` method was incorrectly converting `http://` to `ws://` before passing to the library.
- **Fix:** Removed the `http://` → `ws://` URL transformation. Now passes the URL as-is (with trailing slash stripped).
- **File:** `plugins/home-assistant-dev/mcp-server/src/ha-client.ts` (line 46)
- **Fixed in:** v2.0.2

### Issue 4: MCP server TypeScript build failures (5 type errors)

- **Test:** `npx tsc` build
- **Root Cause:** Multiple type issues accumulated:
  1. Missing type declarations for `home-assistant-js-websocket` (no bundled types)
  2. `deepMerge` generic function losing type info through merge chain
  3. MCP SDK `args` typed as `Record<string, unknown>` not overlapping with input types
  4. Callback parameters in `ha-client.ts` lacking explicit types
  5. Property name mismatch `lastUpdated` vs `last_updated` in `docs-fetch.ts`
- **Fix:** Created `ha-ws.d.ts` declaration file, fixed `deepMerge` to use `ServerConfig` directly, added double-cast `as unknown as T` pattern, explicit field mapping in `getServices()`, fixed property name in `docs-fetch.ts`
- **Files:** 5 files in `plugins/home-assistant-dev/mcp-server/src/`
- **Fixed in:** v2.0.2

### Note: `getServices: has description` test failure

This is a **test expectation issue**, not an MCP server bug. In HA 2026.2.2, `light.turn_on` has an empty description string — services now use `name` for display purposes. The MCP server correctly returns the service data as provided by HA.

---

## Recommendations

1. **Add `missing-future-annotations` file-level test** to the plugin's own test suite to prevent regression
2. **Consider cross-file unique_id validation** — the current per-file approach can't verify that subclasses set unique_id when the base class doesn't
3. **Add severity escalation option** to `validate-strings.py` — missing steps are currently warnings (exit 0), which means CI won't fail on missing translations
4. **Consider adding `ha-quality-review` to a command** since it has `disable-model-invocation: true` and requires explicit invocation — a `/review-integration` command would make it more discoverable
5. **Add HA WebSocket connection test to CI** — the URL conversion bug (#3) would have been caught by any integration test against a real HA instance
6. **Pin `home-assistant-js-websocket` types** — the d.ts file should be updated if the library API changes
7. **Update `getServices: has description` test** to check for `name` field instead (HA 2026.2+ behavior)
