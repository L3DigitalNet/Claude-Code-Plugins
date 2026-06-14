---
name: ha-integration-scaffold
description: Scaffold a new Home Assistant integration with correct file structure, manifest, and boilerplate. Use when creating a new custom component, custom integration, or when asked to scaffold, create, or start a Home Assistant integration.
---

# Home Assistant Integration Scaffolding

## Required File Structure

```text
custom_components/{domain}/
├── __init__.py           # Entry point: async_setup_entry, async_unload_entry
├── manifest.json         # Integration metadata (REQUIRED)
├── config_flow.py        # UI-based configuration (REQUIRED)
├── const.py              # Domain constant, platform list
├── coordinator.py        # DataUpdateCoordinator subclass
├── entity.py             # Base entity class (recommended)
├── strings.json          # Config flow strings
├── services.yaml         # Service action definitions (if registering services)
├── icons.json            # Entity and service icons (optional)
├── translations/
│   └── en.json           # English translations
└── [platform].py         # One per entity platform (sensor.py, switch.py, etc.)
```

**For HACS distribution, also include at repository root:**

```text
/
├── custom_components/{domain}/   # Integration files
├── hacs.json                     # HACS metadata (REQUIRED for HACS)
├── README.md                     # Documentation
└── LICENSE                       # License file
```

## manifest.json (2025 Requirements)

```json
{
	"domain": "{domain_name}",
	"name": "{Human Readable Name}",
	"version": "1.0.0",
	"codeowners": ["@{github_username}"],
	"config_flow": true,
	"dependencies": [],
	"documentation": "https://github.com/{user}/{repo}",
	"integration_type": "hub",
	"iot_class": "local_polling",
	"issue_tracker": "https://github.com/{user}/{repo}/issues",
	"requirements": []
}
```

**Always required:**

- `domain`: lowercase, underscores only, matches folder name
- `name`: human-readable
- `codeowners`: GitHub usernames with `@` prefix
- `documentation`: URL to integration docs
- `iot_class`: `local_polling`, `local_push`, `cloud_polling`, `cloud_push`, `calculated`
- `integration_type`: most common values are `hub` (gateway/multiple devices), `device` (single device), `service` (cloud service); full set is `device`, `entity` (single entity), `hardware`, `helper` (logic-only helper), `hub`, `service`, `system`, `virtual`; defaults to `hub` when omitted

**Required for custom/HACS distribution:**

- `version`: SemVer (required for custom integrations)
- `issue_tracker`: URL for bug reports

The hard HACS requirements are `domain`, `name`, `codeowners`, `documentation`, `issue_tracker`, and `version`.

**Optional:**

- `config_flow`: set `true` for new integrations (omit for YAML-only legacy)
- `dependencies`: may be an empty array, but the key is not mandatory
- `requirements`: may be an empty array, but the key is not mandatory

## **init**.py Template (2025 Pattern)

```python
"""The {Name} integration."""
from __future__ import annotations

import logging

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant

from .const import DOMAIN
from .coordinator import {Name}Coordinator

_LOGGER = logging.getLogger(__name__)

PLATFORMS: list[Platform] = [Platform.SENSOR]

# Type alias for config entry with typed runtime_data
type {Name}ConfigEntry = ConfigEntry[{Name}Coordinator]


async def async_setup_entry(hass: HomeAssistant, entry: {Name}ConfigEntry) -> bool:
    """Set up {Name} from a config entry."""
    coordinator = {Name}Coordinator(hass, entry)
    await coordinator.async_config_entry_first_refresh()

    # Store coordinator in runtime_data (modern pattern, not hass.data)
    entry.runtime_data = coordinator

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True


async def async_unload_entry(hass: HomeAssistant, entry: {Name}ConfigEntry) -> bool:
    """Unload a config entry."""
    if unload_ok := await hass.config_entries.async_unload_platforms(entry, PLATFORMS):
        # Listeners registered via entry.async_on_unload(...) are cleaned automatically;
        # any client/session must be closed explicitly here to avoid leaking connections.
        await entry.runtime_data.client.async_close()
    return unload_ok
```

## const.py Template

```python
"""Constants for the {Name} integration."""
from typing import Final

DOMAIN: Final = "{domain}"
DEFAULT_SCAN_INTERVAL: Final = 30
```

## Python Version Requirements

- HA 2025.2+ ships on **Python 3.13**; develop and test against 3.13
- Use modern type syntax: `list[str]` not `List[str]`
- Use `from __future__ import annotations` in every file
- All I/O must be async

## Critical Rules

1. **Config flow is mandatory** — YAML-only configuration is not permitted
2. **Library separation** — device communication in a separate PyPI package (required for core, recommended for custom)
3. **DataUpdateCoordinator** — always use for polling integrations
4. **Unique IDs** — every entity must have stable `unique_id`
5. **Device info** — group entities under devices using `DeviceInfo`
6. **runtime_data** — store coordinator in `entry.runtime_data`, not `hass.data`

## Additional Resources

- Config flow patterns: `ha-config-flow` skill
- Coordinator implementation: `ha-coordinator` skill
- Entity platforms: `ha-entity-platforms` skill
- Testing: `ha-testing` skill
