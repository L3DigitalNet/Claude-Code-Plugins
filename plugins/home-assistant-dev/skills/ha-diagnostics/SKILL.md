---
name: ha-diagnostics
description: Implement diagnostics for a Home Assistant integration. Required for Gold tier on the Integration Quality Scale. Use when asked about diagnostics.py, debug information, troubleshooting data, or redacting sensitive info.
---

# Home Assistant Diagnostics Implementation

Diagnostics provide users and developers with structured debug information while protecting sensitive data. **Required for Gold tier** on the Integration Quality Scale.

## File Structure

```
custom_components/{domain}/
├── __init__.py
├── diagnostics.py    # Diagnostics implementation
└── ...
```

## Basic diagnostics.py Template

```python
"""Diagnostics support for {Name}."""
from __future__ import annotations

from typing import Any

from homeassistant.components.diagnostics import async_redact_data
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant

# Keys to redact from diagnostics output
TO_REDACT = {
    # Authentication
    "password",
    "token",
    "api_key",
    "access_token",
    "refresh_token",
    "secret",
    "credentials",
    # Personal information
    "email",
    "username",
    "serial",
    "serial_number",
    "unique_id",
    "mac",
    "mac_address",
    # Location
    "latitude",
    "longitude",
    "location",
    "address",
}


async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry
) -> dict[str, Any]:
    """Return diagnostics for a config entry."""
    coordinator = entry.runtime_data

    return {
        "config_entry": async_redact_data(entry.as_dict(), TO_REDACT),
        "coordinator_data": async_redact_data(
            coordinator.data if coordinator.data else {}, TO_REDACT
        ),
    }
```

## Redaction Guidelines

**Always redact** — Auth (`password`, `token`, `api_key`, `access_token`, `refresh_token`, `secret`, `credentials`), Personal (`email`, `username`, `user_id`), Device IDs (`serial`, `mac`, `unique_id`), Location (`latitude`, `longitude`, `address`).

**Never redact** — Model numbers, firmware versions, feature flags, error messages, timestamps.

**Full redaction decision table and `async_redact_data` behavior** — see [references/redaction-reference.md](references/redaction-reference.md)

## Advanced Patterns

**Advanced diagnostics with device registry + entity registry, per-device diagnostics, custom URL redaction, and testing** — see [references/advanced-patterns.md](references/advanced-patterns.md)

## Related Skills

- Config entries → `ha-config-flow`
- Coordinator → `ha-coordinator`
- Quality scale → `ha-quality-review`
