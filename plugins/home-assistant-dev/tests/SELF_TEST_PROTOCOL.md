# Claude Code Self-Test Protocol

## Overview

This document describes how to test the HA Dev Plugin using Claude Code itself as the
test harness. The protocol covers 5 test categories: skill triggers, code generation
quality, validation scripts, agent structure, and MCP server integration (against a
live Home Assistant instance).

**Prerequisites:**

1. The plugin installed (symlinked to source for live updates)
2. Access to the plugin source code for modifications
3. A test workspace for generating test integrations
4. (Category 5) A Home Assistant instance with the `demo` integration enabled

## Setup Instructions

### Plugin Setup

```bash
# Create symlink so plugin changes are immediately active
ln -s ~/projects/Claude-Code-Plugins/plugins/home-assistant-dev ~/.claude/plugins/home-assistant-dev

# Create test workspace
mkdir -p ~/ha-plugin-test-workspace
cd ~/ha-plugin-test-workspace
```

### Home Assistant Test Server Setup (Required for Category 5)

Category 5 (MCP Server Tests) requires a running Home Assistant instance. The
recommended approach uses Docker/podman with the `demo` integration, which provides
~116 test entities across 15+ domains without requiring real hardware.

#### Step 1: Create Docker Compose Configuration

```bash
mkdir -p ~/ha-plugin-test-workspace/ha-config

cat > ~/ha-plugin-test-workspace/docker-compose.yml << 'EOF'
services:
  homeassistant:
    container_name: ha-plugin-test
    image: ghcr.io/home-assistant/home-assistant:stable
    volumes:
      - ./ha-config:/config
    ports:
      - "8123:8123"
    restart: unless-stopped
EOF
```

#### Step 2: Configure Home Assistant

```bash
cat > ~/ha-plugin-test-workspace/ha-config/configuration.yaml << 'EOF'
homeassistant:
  name: HA Dev Plugin Test
  unit_system: metric
  time_zone: America/New_York

# Enable demo integration for test entities
demo:

# Enable API access
api:

# Enable default config (frontend, system health, etc.)
default_config:

# Logging
logger:
  default: info
  logs:
    homeassistant.components.demo: debug
EOF
```

#### Step 3: Start the Container

```bash
cd ~/ha-plugin-test-workspace

# Using Docker:
docker compose up -d

# OR using Podman (recommended if Docker has IPv6 pull issues):
podman compose up -d
```

**Gotcha — Docker IPv6 pull failures:** On some systems, `docker pull` fails with
connection resets over IPv6. Setting `"ipv6": false` in `/etc/docker/daemon.json` only
affects container networking, not the daemon's own image pulls. If this happens, use
podman instead, which handles IPv6 fallback gracefully.

#### Step 4: Complete HA Onboarding (Programmatic)

HA requires onboarding before the API is usable. Complete it programmatically:

```bash
# Wait for HA to finish starting (check http://localhost:8123/api/ returns 401)
# This can take 60-120 seconds on first boot.

# Step 1: Create owner account
curl -s -X POST http://localhost:8123/api/onboarding/users \
  -H "Content-Type: application/json" \
  -d '{"client_id":"http://localhost:8123/","name":"Test","username":"test","password":"test1234","language":"en"}' \
  > /tmp/ha-onboard.json

# Extract auth code from response
AUTH_CODE=$(python3 -c "import json; print(json.load(open('/tmp/ha-onboard.json'))['auth_code'])")

# Step 2: Exchange auth code for tokens
curl -s -X POST http://localhost:8123/auth/token \
  -d "grant_type=authorization_code&code=$AUTH_CODE&client_id=http://localhost:8123/" \
  > /tmp/ha-tokens.json

ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('/tmp/ha-tokens.json'))['access_token'])")

# Step 3: Complete remaining onboarding steps
curl -s -X POST http://localhost:8123/api/onboarding/core_config \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" -d '{}'

curl -s -X POST http://localhost:8123/api/onboarding/analytics \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" -d '{}'

curl -s -X POST http://localhost:8123/api/onboarding/integration \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"client_id":"http://localhost:8123/","redirect_uri":"http://localhost:8123/"}'

# Step 4: Create long-lived access token (LLAT) via WebSocket
# The REST API does not support LLAT creation. Use this Python script:
python3 << 'PYEOF'
import asyncio, aiohttp, json

async def create_llat():
    async with aiohttp.ClientSession() as session:
        async with session.ws_connect("ws://localhost:8123/api/websocket") as ws:
            msg = await ws.receive_json()  # auth_required
            access_token = json.load(open("/tmp/ha-tokens.json"))["access_token"]
            await ws.send_json({"type": "auth", "access_token": access_token})
            msg = await ws.receive_json()  # auth_ok
            await ws.send_json({
                "id": 1,
                "type": "auth/long_lived_access_token",
                "client_name": "HA Dev Plugin Test",
                "lifespan": 365
            })
            msg = await ws.receive_json()
            print(msg["result"])

asyncio.run(create_llat())
PYEOF
```

**Save the LLAT** — copy the printed token to the MCP config:

```bash
mkdir -p ~/.config/ha-dev-mcp

cat > ~/.config/ha-dev-mcp/config.json << EOF
{
  "homeAssistant": {
    "url": "http://localhost:8123",
    "token": "<PASTE_LLAT_HERE>"
  },
  "safety": {
    "allowServiceCalls": true,
    "requireDryRun": false,
    "blockedServices": [
      "homeassistant.restart", "homeassistant.stop",
      "homeassistant.reload_all",
      "recorder.purge", "recorder.disable",
      "hassio.host_shutdown"
    ]
  },
  "features": {
    "docs": true,
    "validation": true
  }
}
EOF
```

#### Step 5: Verify Setup

```bash
# Check HA is responding
curl -s http://localhost:8123/api/config \
  -H "Authorization: Bearer <LLAT>" | python3 -m json.tool | head -5

# Expected: {"components": [...], "version": "2026.x.x", ...}
```

#### Teardown

```bash
cd ~/ha-plugin-test-workspace

# Stop the container
docker compose down    # or: podman compose down

# Remove data (optional, for clean re-test)
rm -rf ha-config/.storage ha-config/home-assistant_v2.db
```

---

## Test Categories

### 1. Skill Trigger Tests

For each skill, verify it activates on the expected prompts.

#### Test Protocol

1. Start fresh conversation
2. Use test prompt
3. Verify skill triggered (check if response uses skill content)
4. Document result
5. If failed: examine skill's `description` field and adjust triggers

#### Test Cases

| Skill | Test Prompt | Expected Behavior | Pass/Fail |
|-------|-------------|-------------------|-----------|
| ha-architecture | "Explain how the Home Assistant event bus works" | Uses event bus terminology from skill | |
| ha-integration-scaffold | "Create a new integration called test_device" | Generates proper file structure | |
| ha-config-flow | "Add a reauth flow to my integration" | Includes `async_step_reauth` pattern | |
| ha-coordinator | "How do I handle errors in DataUpdateCoordinator?" | Mentions UpdateFailed, ConfigEntryAuthFailed | |
| ha-entity-platforms | "Create a sensor entity for temperature" | Uses modern patterns (_attr_*, has_entity_name) | |
| ha-service-actions | "Add a custom service to my integration" | Shows async_setup service registration | |
| ha-async-patterns | "How do I make async HTTP requests in HA?" | Recommends aiohttp, shows executor pattern | |
| ha-testing | "Write tests for my config flow" | Uses MockConfigEntry, pytest patterns | |
| ha-debugging | "My integration won't load, help me debug" | Systematic debugging approach | |
| ha-yaml-automations | "Create an automation that turns on lights at sunset" | Valid YAML automation | |
| ha-quality-review | "Review this integration for IQS compliance" | Runs through Bronze/Silver/Gold checklist | |
| ha-hacs | "Prepare my integration for HACS" | Covers hacs.json, manifest requirements | |
| ha-diagnostics | "Add diagnostics support to my integration" | Shows diagnostics.py pattern with redaction | |
| ha-migration | "Update my integration for HA 2025" | Mentions runtime_data, ServiceInfo changes | |
| ha-documentation | "Generate README for my integration" | Creates structured documentation | |
| ha-repairs | "Add repair issues to my integration" | Shows async_create_issue pattern | |
| ha-device-triggers | "Add device triggers to my integration" | Shows trigger schema and handler | |
| ha-websocket-api | "Add a custom websocket command" | Shows websocket_api.async_register_command | |
| ha-recorder | "Add long-term statistics to my sensor" | Shows state_class, statistics pattern | |

**Note:** `ha-quality-review` has `disable-model-invocation: true` — it requires
explicit invocation (e.g., via `/ha-quality-review`), which is intentional.

---

### 2. Code Generation Quality Tests

Test that generated code is correct and follows best practices.

#### Protocol

1. Request code generation
2. Save generated code to test workspace
3. Run validators against generated code
4. Check for anti-patterns
5. If issues found: update skill with fixes

#### Test Cases

```markdown
## Test: Scaffold Integration

**Prompt:** "Create a new Home Assistant integration called my_weather that polls a REST
API every 5 minutes for weather data"

**Validation:**
- [ ] Run: `python scripts/validate-manifest.py test_workspace/custom_components/my_weather/manifest.json`
- [ ] Run: `python scripts/validate-strings.py test_workspace/custom_components/my_weather/strings.json`
- [ ] Run: `python scripts/check-patterns.py test_workspace/custom_components/my_weather/`
- [ ] Verify: Uses `entry.runtime_data` not `hass.data[DOMAIN]`
- [ ] Verify: Has `_attr_has_entity_name = True`
- [ ] Verify: Coordinator has generic type parameter `DataUpdateCoordinator[dict[str, Any]]`
- [ ] Verify: Uses modern imports (no deprecated ServiceInfo location)

**Expected Result:** All validators pass with no errors, only optional warnings.
```

```markdown
## Test: Add Reauth Flow

**Setup:** Use generated my_weather integration from previous test

**Prompt:** "Add a reauthentication flow to handle expired API tokens"

**Validation:**
- [ ] Has `async_step_reauth` method
- [ ] Has `async_step_reauth_confirm` method
- [ ] Uses `self._get_reauth_entry()`
- [ ] Calls `self.async_update_reload_and_abort()`
- [ ] strings.json has `reauth_confirm` step

**Expected Result:** Reauth flow matches IQS Silver requirements.
```

```markdown
## Test: Add Diagnostics

**Prompt:** "Add diagnostics support to my_weather"

**Validation:**
- [ ] Creates `diagnostics.py`
- [ ] Has `async_get_config_entry_diagnostics` function
- [ ] Redacts sensitive data (API keys, tokens)
- [ ] Includes coordinator data
- [ ] Includes device info

**Expected Result:** Diagnostics matches IQS Gold requirements.
```

---

### 3. Validation Script Tests

Test that the validation scripts correctly identify issues.

#### Protocol

1. Create intentionally broken code
2. Run validator
3. Verify it catches the issue
4. If missed: update validator

#### Test Cases

```python
# test_validators.py - Run in Claude Code

# Test 1: Missing required manifest field
broken_manifest = {
    "domain": "test",
    "name": "Test"
    # Missing: version, codeowners, documentation, etc.
}
# Expected: Validator reports missing fields

# Test 2: Deprecated pattern detection
broken_code = '''
from homeassistant.components.zeroconf import ZeroconfServiceInfo
coordinator = hass.data[DOMAIN][entry.entry_id]
response = requests.get(url)
'''
# Expected: check-patterns.py catches all 3 issues

# Test 3: strings.json sync
# Create config_flow.py with async_step_confirm
# Create strings.json without "confirm" step
# Expected: validate-strings.py reports missing step

# Test 4: Missing future annotations (positive)
# Create file WITHOUT `from __future__ import annotations` that has typed defs
# Expected: check-patterns.py flags the file

# Test 5: Has future annotations (negative — no false positive)
# Create file WITH `from __future__ import annotations` that has typed defs
# Expected: check-patterns.py does NOT flag it
```

---

### 4. Agent Tests

Test the specialized agents provide appropriate guidance.

#### Test Cases

| Agent | What to Verify | Expected |
|-------|---------------|----------|
| ha-integration-dev | Valid frontmatter, 7+ skills, CRUD tools (Read/Write/Edit/Bash/Grep/Glob) | PROACTIVE trigger, comprehensive development workflow |
| ha-integration-reviewer | Valid frontmatter, 3 skills, read-focused tools (Read/Grep/Glob/Bash) | PROACTIVE trigger, IQS checklist review output |
| ha-integration-debugger | Valid frontmatter, 3 skills, debug tools (Read/Edit/Bash/Grep/Glob) | PROACTIVE trigger, systematic debugging approach |

Verify each agent:
1. Has valid YAML frontmatter
2. Lists appropriate skills
3. Has correct tool restrictions
4. Has a clear workflow description
5. Triggers on expected prompts

---

### 5. MCP Server Tests (Requires HA Instance)

**Prerequisites:** Home Assistant running with `demo` integration (see setup above).
MCP server must be built first:

```bash
cd plugins/home-assistant-dev/mcp-server
npm install
npx tsc
```

#### 5A. REST API Tests

These tests validate the same capabilities the MCP server tools use, via the HA REST
API directly. Run with `node test-mcp-tools.mjs` from the test workspace.

| Test | Expected | Validates |
|------|----------|-----------|
| HA Connection: version | Returns HA version string | API auth works |
| HA Connection: location | Returns configured location name | Config accessible |
| HA Connection: components loaded | >0 components array | System health |
| HA Connection: demo integration | `demo` in components | Test entities available |
| Entity Query: total entities | >100 entities | Demo platform loaded |
| Entity Query: sensors | >0 sensor entities | Domain filtering |
| Entity Query: lights | >0 light entities | Domain filtering |
| Entity Query: switches | >0 switch entities | Domain filtering |
| Entity Query: light.bed_light | Entity exists | Specific entity lookup |
| Entity Query: light.ceiling_lights | Entity exists | Specific entity lookup |
| Entity Query: sensor.outside_temperature | Entity exists | Specific entity lookup |
| Service Discovery: domains returned | >0 service domains | Services endpoint |
| Service Discovery: light domain | Light domain present | Domain lookup |
| Service Discovery: light.turn_on | Service exists | Service lookup |
| Service Discovery: light.turn_off | Service exists | Service lookup |
| Service Discovery: light.toggle | Service exists | Service lookup |
| Dry Run: service exists | light.turn_on found | Validation pre-check |
| Dry Run: target exists | light.bed_light found | Entity verification |
| Dry Run: validation passed | Both exist, no call made | Dry run logic |
| Dry Run: non-existent entity rejected | light.nonexistent not found | Negative case |
| Entity Attributes: has attributes | Attributes object present | State shape |
| Entity Attributes: has friendly_name | Name returned | Attribute access |
| Entity Attributes: has supported_features | Features bitmask present | Feature flags |
| Logs: accessible | 200 response from error_log | Log endpoint |

#### 5B. MCP Server WebSocket Tests

These tests import the compiled `HaClient` and `SafetyChecker` classes directly and
test them against the live HA WebSocket API. Run with `node test-mcp-server.mjs` from
the test workspace.

| Test | Expected | Validates |
|------|----------|-----------|
| **WS Connect** | | |
| connected | `connectInfo.connected === true` | WebSocket connection |
| version | Version string returned | Config retrieval |
| location | Location name returned | Config retrieval |
| components | >0 components | Config retrieval |
| demo loaded | `demo` in components | Test readiness |
| isConnected() | Returns true | Client state |
| **getStates** | | |
| all entities | >0 states returned | State retrieval |
| has entity_id | Shape check | Response format |
| has state | Shape check | Response format |
| has attributes | Shape check | Response format |
| has last_changed | Shape check | Response format |
| domain=sensor | >0 sensors, all start with `sensor.` | Domain filter |
| domain filter correct | No non-sensor entities | Filter accuracy |
| entity=light.bed_light | Exactly 1 result | Entity filter |
| entity attributes | friendly_name present | Attribute access |
| **getServices** | | |
| all | >0 services returned | Service retrieval |
| light.turn_on found | Service exists | Lookup |
| has description | Description string (may be empty in HA 2026+) | Shape check |
| has fields | Fields object present | Shape check |
| domain=light | turn_on, turn_off, toggle present | Domain filter |
| domain filter correct | All results have domain=light | Filter accuracy |
| **validateServiceCall** | | |
| valid call | `valid === true` for light.turn_on on bed_light | Validation logic |
| invalid entity | `valid === false`, error mentions entity | Negative case |
| fake service | `valid === false`, error mentions service | Negative case |
| **SafetyChecker** | | |
| homeassistant.stop blocked | `allowed === false` | Blocked services |
| light.turn_on allowed (dry_run) | `allowed === true` | Safe services |
| getSafetyInfo() | Returns config summary | Info method |
| input_boolean is safe | `isSafeDomain` returns true | Domain classification |
| homeassistant is not safe | `isSafeDomain` returns false | Domain classification |
| redacts api_key | Value replaced with `**REDACTED**` | Data sanitization |
| redacts password | Value replaced with `**REDACTED**` | Data sanitization |
| preserves brightness | Numeric value unchanged | Selective redaction |
| **getDevices** | | |
| accessible | >0 devices returned | Device registry |
| has id | Shape check | Response format |
| has name | Shape check | Response format |
| **getLogs** | | |
| accessible | Returns log entries (may be empty) | System log access |
| **getConnectionInfo** | | |
| returns data | `connected === true` | Cached info |
| matches connect | Version matches initial connect | Consistency |
| **Disconnect** | | |
| clean | `isConnected()` returns false | Cleanup |

**Known issue:** `getServices: has description` may return an empty string in
HA 2026.2+. Services now use `name` for display purposes. The MCP server correctly
returns the data as provided by HA — this is a test expectation issue, not a bug.

---

## Self-Healing Protocol

When a test fails:

### 1. Diagnose

```
Identify which component failed:
- Skill trigger? → Check description/triggers in SKILL.md frontmatter
- Code quality? → Check templates/examples in skill content
- Validator? → Check regex patterns in scripts/
- MCP tool? → Check handler in mcp-server/src/tools/
- MCP client? → Check ha-client.ts (connection, state, service methods)
```

### 2. Fix

```
Edit the source file directly (symlink makes changes immediate):
- plugins/home-assistant-dev/skills/*/SKILL.md
- plugins/home-assistant-dev/scripts/*.py
- plugins/home-assistant-dev/mcp-server/src/*.ts
- plugins/home-assistant-dev/mcp-server/src/tools/*.ts
```

### 3. Rebuild (MCP server changes only)

```bash
cd plugins/home-assistant-dev/mcp-server
npx tsc
```

### 4. Retest

```
Run the same test again to verify fix.
If symlinked, skill/script changes are immediately active.
MCP server changes require rebuild (step 3).
```

### 5. Document

```
Update SELF_TEST_RESULTS.md with:
- What failed
- Root cause
- What was fixed
- File and line numbers
```

---

## Lessons Learned

Issues discovered during self-testing sessions. These inform what to watch for on
future runs.

### MCP Server

1. **`createLongLivedTokenAuth()` expects HTTP URLs.** The `home-assistant-js-websocket`
   library converts `http://` to `ws://` internally. Do NOT pre-convert the URL — it
   will cause `TypeError: Invalid URL`. (Fixed in v2.0.2)

2. **`home-assistant-js-websocket` ships no TypeScript types.** A custom `ha-ws.d.ts`
   declaration file is required. If the library API changes, this file must be updated
   manually. (Added in v2.0.2)

3. **MCP SDK types `args` as `Record<string, unknown>`.** This doesn't overlap with
   concrete input types. Use the double-cast pattern: `args as unknown as InputType`.
   (Fixed in v2.0.2)

4. **HA 2026.2+ uses `name` instead of `description` for services.** The `description`
   field may be empty. Tests should check for `name` as the display field.

### Validation Scripts

5. **Per-line regex cannot check file-level imports.** The `missing-future-annotations`
   pattern used a per-line negative lookahead, but `from __future__ import annotations`
   is a file-level statement. Use a file-level check (lambda reading entire content)
   instead. (Fixed in v2.0.1)

6. **Entity class regex catches base classes too.** The `missing-unique-id` pattern
   should only flag concrete entity classes (inheriting from `SensorEntity`, etc.),
   not base classes (inheriting from `CoordinatorEntity` where unique_id is set in
   subclasses by design). (Fixed in v2.0.1)

### Infrastructure

7. **Docker image pulls may fail over IPv6.** On dual-stack systems, Docker daemon may
   attempt to pull over IPv6 and get connection resets. `daemon.json` IPv6 settings
   only affect container networking, not pulls. Use **podman** as a drop-in
   replacement if this occurs.

8. **HA onboarding must be completed programmatically.** The integration onboarding
   step requires a JSON body with `client_id` and `redirect_uri` — an empty POST
   returns "Invalid JSON".

9. **Long-lived access tokens can only be created via WebSocket.** The REST API
   provides short-lived tokens. For persistent MCP server connections, create an LLAT
   via the `auth/long_lived_access_token` WebSocket command.

---

## Test Results Template

```markdown
# HA Dev Plugin Self-Test Results

**Date:** YYYY-MM-DD
**Claude Code Model:** Claude Opus X.X
**Plugin Version:** X.X.X

## Summary

- Skill Trigger Tests: X/19 passed
- Code Generation Tests: X/X passed
- Validation Script Tests: X/X passed
- Agent Tests: X/3 passed
- MCP REST API Tests: X/24 passed (or N/A)
- MCP WebSocket Tests: X/39 passed (or N/A)

## Issues Found

### Issue N: [Title]

- **Test:** [Which test failed]
- **Expected:** [What should happen]
- **Actual:** [What happened]
- **Root Cause:** [Why it failed]
- **Fix:** [What was changed]
- **File:** [Path to modified file]

## Recommendations

1. [Improvements to make]
2. [New tests to add]
```

---

## Quick Start

Copy-paste this to start testing:

```
I'm going to self-test the HA Dev Plugin. I have:
- Plugin installed at ~/.claude/plugins/home-assistant-dev (symlinked to source)
- Test workspace at ~/ha-plugin-test-workspace
- Home Assistant running in Docker/podman at http://localhost:8123

Please run through all 5 test categories:
1. Skill Trigger Tests (19 skills)
2. Code Generation Quality Tests
3. Validation Script Tests
4. Agent Tests (3 agents)
5. MCP Server Tests (REST API + WebSocket)

Document pass/fail for each test. Report any issues found with root cause and fix.
```

For Categories 1-4 only (no HA instance):

```
I'm going to self-test the HA Dev Plugin (Categories 1-4, no HA instance). I have:
- Plugin installed at ~/.claude/plugins/home-assistant-dev (symlinked to source)
- Test workspace at ~/ha-plugin-test-workspace

Please run through Skill Trigger Tests, Code Generation Quality Tests,
Validation Script Tests, and Agent Tests. Skip MCP Server Tests.
```
