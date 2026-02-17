# End-to-End Test Checklist

Manual tests to verify the plugin works correctly with Claude Code.

## Prerequisites

- Claude Code installed
- Plugin loaded (copy to `~/.claude/plugins/home-assistant-dev/`)
- (Optional) Home Assistant instance for MCP server tests

---

## 1. Skill Trigger Tests

### 1.1 Architecture Skill
**Prompt:** "Explain how the Home Assistant event bus works"  
**Expected:** Response uses ha-architecture skill, mentions event bus, state machine

### 1.2 Scaffold Skill
**Prompt:** "Create a new integration called my_thermostat"  
**Expected:** Generates complete integration structure with:
- [ ] `__init__.py` with runtime_data pattern
- [ ] `manifest.json` with all required fields
- [ ] `config_flow.py` with user step
- [ ] `strings.json` with data_description
- [ ] `const.py` with DOMAIN

### 1.3 Config Flow Skill
**Prompt:** "Add a reauth flow to my integration"  
**Expected:** Response includes:
- [ ] `async_step_reauth` method
- [ ] `async_step_reauth_confirm` method
- [ ] `_get_reauth_entry()` usage
- [ ] `async_update_reload_and_abort()` pattern

### 1.4 Coordinator Skill
**Prompt:** "How should I handle errors in DataUpdateCoordinator?"  
**Expected:** Response mentions:
- [ ] `UpdateFailed` for recoverable errors
- [ ] `ConfigEntryAuthFailed` for auth issues triggering reauth
- [ ] `_async_setup` for one-time initialization

### 1.5 Quality Review Skill
**Prompt:** "Review examples/polling-hub for IQS compliance"  
**Expected:** Response includes:
- [ ] Bronze tier checklist
- [ ] Silver tier checklist  
- [ ] Gold tier checklist
- [ ] Specific pass/fail for each rule

### 1.6 HACS Skill
**Prompt:** "Prepare my integration for HACS submission"  
**Expected:** Response covers:
- [ ] hacs.json requirements
- [ ] manifest.json requirements (version, issue_tracker)
- [ ] Repository structure
- [ ] Brand images

### 1.7 Testing Skill
**Prompt:** "Write tests for my config flow"  
**Expected:** Response includes:
- [ ] MockConfigEntry usage
- [ ] Test for successful flow
- [ ] Test for connection error
- [ ] Test for already configured

---

## 2. Hook Tests

### 2.1 Manifest Validation Hook
**Action:** Edit `manifest.json`, remove required field  
**Expected:** Hook warns about missing field

### 2.2 Strings Validation Hook
**Action:** Add new step to `config_flow.py` without updating `strings.json`  
**Expected:** Hook warns about missing step translation

### 2.3 Pattern Check Hook
**Action:** Add `hass.data[DOMAIN]` to a Python file  
**Expected:** Hook suggests using `entry.runtime_data`

---

## 3. Script Tests

### 3.1 validate-manifest.py
```bash
python scripts/validate-manifest.py examples/polling-hub/custom_components/example_hub/manifest.json
```
**Expected:** No errors, possibly warnings

### 3.2 validate-strings.py
```bash
python scripts/validate-strings.py examples/polling-hub/custom_components/example_hub/strings.json
```
**Expected:** Valid output, steps synced

### 3.3 check-patterns.py
```bash
python scripts/check-patterns.py examples/polling-hub/custom_components/example_hub/
```
**Expected:** No errors (examples should be clean)

### 3.4 generate-docs.py
```bash
python scripts/generate-docs.py examples/polling-hub/custom_components/example_hub/
```
**Expected:** Generates README.md and info.md

---

## 4. MCP Server Tests (Requires Home Assistant)

### 4.1 Connection Test
**Setup:** Configure HA_DEV_MCP_URL and HA_DEV_MCP_TOKEN
**Prompt:** "Connect to my Home Assistant"
**Expected:** Shows HA version and location

### 4.2 State Query
**Prompt:** "Show me all sensor entities"
**Expected:** Lists sensors with states

### 4.3 Service Query
**Prompt:** "What services are available for the light domain?"
**Expected:** Lists light services with parameters

### 4.4 Dry Run Service Call
**Prompt:** "Turn on light.living_room (dry run)"
**Expected:** Validates call without executing

### 4.5 Documentation Search
**Prompt:** "Search HA docs for DataUpdateCoordinator"
**Expected:** Returns relevant documentation links

### 4.6 Validation via MCP
**Prompt:** "Validate my manifest.json using MCP tools"
**Expected:** Returns validation results

---

## 5. Agent Tests

### 5.1 ha-integration-dev Agent
**Prompt:** "I want to create an integration for my smart thermostat that uses a REST API"
**Expected:** Guides through complete development process

### 5.2 ha-integration-reviewer Agent
**Prompt:** "Review my integration for quality and best practices"
**Expected:** Comprehensive code review with specific suggestions

### 5.3 ha-integration-debugger Agent
**Prompt:** "My integration isn't loading, help me debug"
**Expected:** Systematic debugging approach

---

## 6. Example Integration Tests

### 6.1 polling-hub
```bash
cd examples/polling-hub
pytest tests/ -v
```
**Expected:** All tests pass

### 6.2 Validate All Examples
```bash
./tests/integration/test_scripts_against_examples.sh
```
**Expected:** All validations pass

---

## Test Results Log

| Test | Date | Result | Notes |
|------|------|--------|-------|
| | | | |
| | | | |
| | | | |
