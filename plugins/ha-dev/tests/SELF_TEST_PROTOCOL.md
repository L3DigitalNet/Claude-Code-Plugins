# Claude Code Self-Test Protocol

## Overview

This document describes how to test the HA Dev Plugin using Claude Code itself as the test harness. Claude Code should have:

1. The plugin installed (symlinked to source for live updates)
2. Access to the plugin source code for modifications
3. A test workspace for generating test integrations

## Setup Instructions

```bash
# Create symlink so plugin changes are immediately active
ln -s ~/projects/ha-dev-plugin-v2 ~/.claude/plugins/home-assistant-dev

# Create test workspace
mkdir -p ~/ha-plugin-test-workspace
cd ~/ha-plugin-test-workspace
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

**Prompt:** "Create a new Home Assistant integration called my_weather that polls a REST API every 5 minutes for weather data"

**Validation:**
- [ ] Run: `python scripts/validate-manifest.py test_workspace/custom_components/my_weather/manifest.json`
- [ ] Run: `python scripts/validate-strings.py test_workspace/custom_components/my_weather/strings.json`  
- [ ] Run: `python scripts/check-patterns.py test_workspace/custom_components/my_weather/`
- [ ] Verify: Uses `entry.runtime_data` not `hass.data[DOMAIN]`
- [ ] Verify: Has `_attr_has_entity_name = True`
- [ ] Verify: Coordinator has generic type parameter
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
```

---

### 4. Agent Tests

Test the specialized agents provide appropriate guidance.

#### Test Cases

```markdown
## Test: ha-integration-dev Agent

**Prompt:** "I want to create an integration for my Acme smart thermostat. It has a REST API that requires OAuth2 authentication and supports reading temperature, setting target temperature, and switching between modes."

**Expected Behavior:**
- Asks clarifying questions about device capabilities
- Recommends appropriate iot_class (cloud_polling or cloud_push)
- Suggests config flow with OAuth2
- Plans entity platforms (climate, sensor)
- Mentions IQS requirements

**Validation:** Response is comprehensive and actionable
```

```markdown
## Test: ha-integration-reviewer Agent

**Setup:** Provide example integration code

**Prompt:** "Review this integration for quality and best practices"

**Expected Behavior:**
- Checks against IQS rules
- Identifies specific issues with file:line references
- Provides fix examples
- Prioritizes recommendations

**Validation:** Finds real issues, doesn't report false positives
```

---

### 5. MCP Server Tests (If Connected to HA)

If Claude Code has MCP server connected to a Home Assistant instance:

```markdown
## Test: HA Connection

**Prompt:** "Connect to my Home Assistant and show the version"

**Expected:** Returns HA version, location, components

## Test: Entity Query

**Prompt:** "List all sensor entities"

**Expected:** Returns list of sensors with states

## Test: Service Discovery

**Prompt:** "What services are available for the light domain?"

**Expected:** Returns light services with parameters

## Test: Dry Run

**Prompt:** "Turn on light.living_room (dry run only)"

**Expected:** Validates service call without executing
```

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
```

### 2. Fix
```
Edit the source file directly:
- ~/.claude/plugins/home-assistant-dev/skills/*/SKILL.md
- ~/.claude/plugins/home-assistant-dev/scripts/*.py
- ~/.claude/plugins/home-assistant-dev/mcp-server/src/tools/*.ts
```

### 3. Retest
```
Run the same test again to verify fix.
If symlinked, changes are immediately active.
```

### 4. Document
```
Update this protocol with:
- What failed
- What was fixed
- New test case if needed
```

---

## Test Results Template

```markdown
# HA Dev Plugin Self-Test Results

**Date:** YYYY-MM-DD
**Claude Code Version:** X.X.X
**Plugin Version:** 2.0.0

## Summary
- Skill Trigger Tests: X/19 passed
- Code Generation Tests: X/X passed
- Validator Tests: X/X passed
- Agent Tests: X/3 passed
- MCP Tests: X/X passed (or N/A)

## Issues Found

### Issue 1: [Title]
- **Test:** [Which test failed]
- **Expected:** [What should happen]
- **Actual:** [What happened]
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

Please run through the Skill Trigger Tests first, documenting pass/fail for each.
Then move to Code Generation Quality Tests.
Report any issues found and suggest fixes.
```
