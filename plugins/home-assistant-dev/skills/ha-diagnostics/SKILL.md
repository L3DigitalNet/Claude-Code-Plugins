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

## Advanced Diagnostics with Device Info

```python
"""Diagnostics support for {Name}."""
from __future__ import annotations

from typing import Any

from homeassistant.components.diagnostics import async_redact_data
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers import device_registry as dr, entity_registry as er

TO_REDACT = {
    "password",
    "token",
    "api_key",
    "access_token",
    "refresh_token",
    "secret",
    "email",
    "username",
    "serial",
    "mac",
    "latitude",
    "longitude",
}

# Additional keys in nested structures
TO_REDACT_NESTED = TO_REDACT | {"ip_address", "host", "ssid"}


async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry
) -> dict[str, Any]:
    """Return diagnostics for a config entry."""
    coordinator = entry.runtime_data

    # Get device and entity info
    device_registry = dr.async_get(hass)
    entity_registry = er.async_get(hass)

    devices = []
    for device in dr.async_entries_for_config_entry(device_registry, entry.entry_id):
        entities = []
        for entity in er.async_entries_for_device(
            entity_registry, device.id, include_disabled_entities=True
        ):
            entities.append({
                "entity_id": entity.entity_id,
                "disabled": entity.disabled,
                "disabled_by": entity.disabled_by,
                "platform": entity.platform,
            })
        
        devices.append({
            "name": device.name,
            "model": device.model,
            "manufacturer": device.manufacturer,
            "sw_version": device.sw_version,
            "hw_version": device.hw_version,
            "entities": entities,
        })

    return {
        "config_entry": {
            "entry_id": entry.entry_id,
            "version": entry.version,
            "domain": entry.domain,
            "title": entry.title,
            "data": async_redact_data(dict(entry.data), TO_REDACT),
            "options": async_redact_data(dict(entry.options), TO_REDACT),
        },
        "devices": devices,
        "coordinator": {
            "last_update_success": coordinator.last_update_success,
            "last_exception": str(coordinator.last_exception) if coordinator.last_exception else None,
            "update_interval": str(coordinator.update_interval),
            "data": async_redact_data(coordinator.data, TO_REDACT_NESTED) if coordinator.data else None,
        },
    }
```

## Device Diagnostics (Optional)

For per-device diagnostics (useful for hub integrations):

```python
async def async_get_device_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry, device: dr.DeviceEntry
) -> dict[str, Any]:
    """Return diagnostics for a device."""
    coordinator = entry.runtime_data
    
    # Find device data from coordinator
    device_id = next(
        (identifier[1] for identifier in device.identifiers if identifier[0] == DOMAIN),
        None
    )
    
    device_data = coordinator.data.get(device_id, {}) if device_id else {}
    
    return {
        "device": {
            "name": device.name,
            "model": device.model,
            "sw_version": device.sw_version,
        },
        "data": async_redact_data(device_data, TO_REDACT),
    }
```

## Redaction Guidelines

### Always Redact

| Category | Keys to Redact |
|----------|---------------|
| **Auth** | password, token, api_key, access_token, refresh_token, secret, credentials, auth |
| **Personal** | email, username, user_id, account_id |
| **Device IDs** | serial, serial_number, unique_id, mac, mac_address |
| **Location** | latitude, longitude, lat, lon, location, address, coordinates |
| **Network** | ip_address, ip, ssid (consider context) |

### Consider Redacting

- Phone numbers
- Names (if personally identifiable)
- URLs with auth tokens
- Custom identifiers specific to your integration

### Never Redact

- Model numbers
- Firmware versions
- Feature flags
- Error messages
- Timestamps
- Entity states (unless containing PII)

## Using async_redact_data

The helper recursively redacts matching keys:

```python
from homeassistant.components.diagnostics import async_redact_data

data = {
    "device": {
        "name": "Living Room",
        "serial": "ABC123",  # Will be redacted
        "firmware": "1.2.3",
    },
    "auth": {
        "token": "secret123",  # Will be redacted
        "expires": 3600,
    }
}

redacted = async_redact_data(data, {"serial", "token"})
# Result:
# {
#     "device": {"name": "Living Room", "serial": "**REDACTED**", "firmware": "1.2.3"},
#     "auth": {"token": "**REDACTED**", "expires": 3600}
# }
```

## Custom Redaction

For complex redaction needs:

```python
def redact_url(url: str) -> str:
    """Redact auth tokens from URLs."""
    import re
    return re.sub(r'(token=)[^&]+', r'\1**REDACTED**', url)

async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry
) -> dict[str, Any]:
    coordinator = entry.runtime_data
    
    # Custom redaction for URLs
    api_url = redact_url(coordinator.client.base_url)
    
    return {
        "api_url": api_url,
        "data": async_redact_data(coordinator.data, TO_REDACT),
    }
```

## Testing Diagnostics

```python
"""Test diagnostics."""
from homeassistant.components.diagnostics import async_get_config_entry_diagnostics
from homeassistant.core import HomeAssistant

from custom_components.{domain} import DOMAIN


async def test_diagnostics(hass: HomeAssistant, mock_client) -> None:
    """Test diagnostics output."""
    entry = MockConfigEntry(domain=DOMAIN, data=MOCK_CONFIG)
    entry.add_to_hass(hass)
    await hass.config_entries.async_setup(entry.entry_id)
    await hass.async_block_till_done()

    diagnostics = await async_get_config_entry_diagnostics(hass, entry)
    
    # Verify structure
    assert "config_entry" in diagnostics
    assert "coordinator_data" in diagnostics
    
    # Verify sensitive data is redacted
    assert diagnostics["config_entry"]["data"]["password"] == "**REDACTED**"
```

## Related Skills

- Config entries → `ha-config-flow`
- Coordinator → `ha-coordinator`
- Quality scale → `ha-quality-review`
