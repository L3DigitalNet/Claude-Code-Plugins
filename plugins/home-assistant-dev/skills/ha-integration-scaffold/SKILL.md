---
name: ha-integration-scaffold
description: Scaffold a new Home Assistant integration with correct file structure, manifest, and boilerplate. Use when creating a new custom component, custom integration, or when asked to scaffold, create, or start a Home Assistant integration.
---

# Home Assistant Integration Scaffolding

## Required File Structure

```
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
```
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

**Required fields (Core + HACS):**
- `domain`: lowercase, underscores only, matches folder name
- `name`: human-readable (omit for core integrations)
- `version`: SemVer (required for custom integrations)
- `codeowners`: GitHub usernames with `@` prefix
- `config_flow`: always `true` for new integrations
- `documentation`: URL to integration docs
- `integration_type`: `hub` (gateway), `device` (single device), `service` (cloud)
- `iot_class`: `local_polling`, `local_push`, `cloud_polling`, `cloud_push`, `calculated`
- `issue_tracker`: URL for bug reports (**required for HACS**)

## __init__.py Template (2025 Pattern)

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
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
```

## const.py Template

```python
"""Constants for the {Name} integration."""
from typing import Final

DOMAIN: Final = "{domain}"
DEFAULT_SCAN_INTERVAL: Final = 30
```

## Python Version Requirements

- Home Assistant 2025.2+ requires **Python 3.13**
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
