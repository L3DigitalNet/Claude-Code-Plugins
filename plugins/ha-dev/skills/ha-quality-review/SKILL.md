---
name: ha-quality-review
description: Review a Home Assistant integration against the Integration Quality Scale (IQS). Covers all 52 official rules across Bronze, Silver, Gold, and Platinum tiers. Use when asked to review, quality check, assess for core PR, HACS submission, or IQS compliance.
disable-model-invocation: true
---

# Home Assistant Integration Quality Scale Review

Run with `/home-assistant-dev:ha-quality-review` to perform a systematic review against all official IQS rules.

## Overview

The Integration Quality Scale has **4 tiers** and **52 rules**:
- **Bronze (18 rules)**: Minimum for new core integrations
- **Silver (10 rules)**: Reliability and maintainability
- **Gold (21 rules)**: Best user experience
- **Platinum (3 rules)**: Technical excellence

## Review Process

1. Locate integration: `custom_components/{domain}/` or `homeassistant/components/{domain}/`
2. Run automated checks where possible
3. Manual review against checklist
4. Generate report with findings

---

## Bronze Tier (18 Rules) — Required for Core

### Code Organization
- [ ] **action-setup**: Service actions registered in `async_setup`, not `async_setup_entry`
- [ ] **common-modules**: Common patterns in dedicated modules (coordinator.py, entity.py)
- [ ] **dependency-transparency**: All dependencies listed in manifest.json `requirements`
- [ ] **runtime-data**: Uses `entry.runtime_data` not `hass.data[DOMAIN]`

### Config Flow
- [ ] **config-flow**: Setup via UI with `config_flow: true` in manifest
  - Uses `data_description` in strings.json for field context
  - `ConfigEntry.data` for connection info, `ConfigEntry.options` for settings
- [ ] **config-flow-test-coverage**: Full test coverage for config flow
- [ ] **test-before-configure**: Validates connection during config flow
- [ ] **unique-config-entry**: Prevents duplicate config entries via `async_set_unique_id`

### Entities
- [ ] **entity-unique-id**: Every entity has stable `unique_id`
- [ ] **has-entity-name**: All entities use `_attr_has_entity_name = True`
- [ ] **entity-event-setup**: Event subscriptions in `async_added_to_hass`, cleanup in `async_will_remove_from_hass`

### Setup & Reliability
- [ ] **test-before-setup**: Validates connection in `async_setup_entry`, raises `ConfigEntryNotReady` on failure
- [ ] **appropriate-polling**: Reasonable polling interval (not too frequent)

### Documentation & Branding
- [ ] **brands**: Has logo/icon in [home-assistant/brands](https://github.com/home-assistant/brands)
- [ ] **docs-high-level-description**: Documentation describes what the integration does
- [ ] **docs-installation-instructions**: Step-by-step setup instructions
- [ ] **docs-removal-instructions**: How to remove the integration
- [ ] **docs-actions**: Documents all service actions

---

## Silver Tier (10 Rules) — Reliability

### Error Handling
- [ ] **action-exceptions**: Service actions raise `ServiceValidationError` or `HomeAssistantError` on failure
- [ ] **entity-unavailable**: Entities marked unavailable when device/service unreachable
- [ ] **log-when-unavailable**: Logs once when unavailable, once when reconnected (DataUpdateCoordinator handles this)

### Lifecycle
- [ ] **config-entry-unloading**: Implements `async_unload_entry` properly
- [ ] **reauthentication-flow**: Implements `async_step_reauth` for credential refresh

### Performance
- [ ] **parallel-updates**: Sets `PARALLEL_UPDATES` constant to limit concurrent entity updates

### Maintenance
- [ ] **integration-owner**: Has active codeowner in manifest.json
- [ ] **test-coverage**: ≥95% test coverage

### Documentation
- [ ] **docs-configuration-parameters**: Documents all options flow parameters
- [ ] **docs-installation-parameters**: Documents all config flow parameters

---

## Gold Tier (21 Rules) — Best Experience

### Devices & Entities
- [ ] **devices**: Creates device entries with `DeviceInfo`
- [ ] **entity-category**: Uses `EntityCategory.CONFIG` or `EntityCategory.DIAGNOSTIC` appropriately
- [ ] **entity-device-class**: Uses appropriate device classes
- [ ] **entity-disabled-by-default**: Disables noisy/rarely-used entities by default
- [ ] **entity-translations**: Entity names use `translation_key`
- [ ] **dynamic-devices**: Handles devices appearing/disappearing after setup
- [ ] **stale-devices**: Removes devices that are no longer present

### Discovery
- [ ] **discovery**: Supports Zeroconf/SSDP/DHCP/USB/Bluetooth discovery
- [ ] **discovery-update-info**: Updates device network info from discovery

### Advanced Flows
- [ ] **reconfiguration-flow**: Implements `async_step_reconfigure` for changing settings
- [ ] **repair-issues**: Uses repair registry for actionable user notifications

### Diagnostics
- [ ] **diagnostics**: Implements `diagnostics.py` with sensitive data redaction

### Translations
- [ ] **exception-translations**: Exception messages are translatable
- [ ] **icon-translations**: Uses icon translations in `icons.json`

### Documentation
- [ ] **docs-data-update**: Documents polling interval and update method
- [ ] **docs-examples**: Provides automation examples
- [ ] **docs-known-limitations**: Documents limitations
- [ ] **docs-supported-devices**: Lists supported devices/models
- [ ] **docs-supported-functions**: Documents supported features
- [ ] **docs-troubleshooting**: Provides troubleshooting guide
- [ ] **docs-use-cases**: Shows example use cases

---

## Platinum Tier (3 Rules) — Excellence

- [ ] **async-dependency**: Third-party library is fully async (no executor wrapping needed)
- [ ] **inject-websession**: Library accepts Home Assistant's aiohttp session
- [ ] **strict-typing**: Full type annotations, passes `mypy --strict`

---

## Quick Validation Commands

```bash
# Validate JSON files
python3 -c "import json; json.load(open('manifest.json'))"
python3 -c "import json; json.load(open('strings.json'))"

# Check for common issues
grep -r "hass.data\[DOMAIN\]" .  # Should use runtime_data
grep -r "requests\." .           # Should use aiohttp
grep -r "time.sleep" .           # Should use asyncio.sleep

# Run linters
ruff check .
mypy .
```

## Output Format

```markdown
## Integration Quality Review: {domain}

### Tier Assessment
- Bronze: {X}/18 ✅/❌
- Silver: {X}/10 ✅/❌
- Gold: {X}/21 ✅/❌
- Platinum: {X}/3 ✅/❌

**Current Tier:** {highest fully passing tier}

### Critical Issues (Must Fix for Bronze)
1. [Rule]: [Issue] — [File:line]
   Fix: [code example]

### Warnings (Should Fix)
1. [Rule]: [Issue]

### Recommendations for Next Tier
1. [Prioritized improvements]

### Positive Findings
- [What's done well]
```

## Related Skills

- Config flow issues → `ha-config-flow`
- Coordinator issues → `ha-coordinator`
- Entity issues → `ha-entity-platforms`
- Async issues → `ha-async-patterns`
- Diagnostics → `ha-diagnostics`
- HACS compliance → `ha-hacs`
