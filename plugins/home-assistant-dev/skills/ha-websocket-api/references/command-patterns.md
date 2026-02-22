# WebSocket Command Patterns

## Full Command Implementation Example

Complete `api.py` with sync and async command variants, plus the registration setup in `__init__.py`.

```python
# api.py
"""WebSocket API for {Name}."""
from __future__ import annotations

from typing import Any

import voluptuous as vol

from homeassistant.components import websocket_api
from homeassistant.core import HomeAssistant, callback

from .const import DOMAIN


async def async_setup_api(hass: HomeAssistant) -> None:
    """Set up WebSocket API."""
    websocket_api.async_register_command(hass, websocket_get_devices)
    websocket_api.async_register_command(hass, websocket_get_device_data)
    websocket_api.async_register_command(hass, websocket_subscribe_updates)


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/devices",
    }
)
@callback
def websocket_get_devices(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> None:
    """Return list of devices."""
    # Get data from your integration
    devices = []
    for entry_id, coordinator in hass.data.get(DOMAIN, {}).items():
        for device_id, device in coordinator.devices.items():
            devices.append({
                "id": device_id,
                "name": device.get("name"),
                "online": device.get("online", False),
            })

    connection.send_result(msg["id"], {"devices": devices})


@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/device/data",
        vol.Required("device_id"): str,
    }
)
@websocket_api.async_response
async def websocket_get_device_data(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> None:
    """Return data for a specific device."""
    device_id = msg["device_id"]

    # Find device data
    device_data = None
    for coordinator in hass.data.get(DOMAIN, {}).values():
        if device_id in coordinator.devices:
            device_data = coordinator.devices[device_id]
            break

    if device_data is None:
        connection.send_error(msg["id"], "not_found", f"Device {device_id} not found")
        return

    connection.send_result(msg["id"], device_data)
```

```python
# __init__.py
from .api import async_setup_api

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up integration."""
    # ... your setup code ...

    # Register WebSocket API (only once)
    if DOMAIN not in hass.data:
        await async_setup_api(hass)

    # ... rest of setup ...
```

## Error Handling

```python
from homeassistant.components.websocket_api import (
    ERR_INVALID_FORMAT,
    ERR_NOT_FOUND,
    ERR_UNKNOWN_ERROR,
)

@websocket_api.websocket_command({...})
@websocket_api.async_response
async def websocket_command(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> None:
    """Handle command."""
    try:
        result = await do_something()
        connection.send_result(msg["id"], result)
    except ValueError as err:
        connection.send_error(msg["id"], ERR_INVALID_FORMAT, str(err))
    except KeyError:
        connection.send_error(msg["id"], ERR_NOT_FOUND, "Resource not found")
    except Exception as err:
        connection.send_error(msg["id"], ERR_UNKNOWN_ERROR, str(err))
```

## Admin-Only Commands

```python
@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/admin/config",
    }
)
@websocket_api.require_admin
@websocket_api.async_response
async def websocket_admin_config(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> None:
    """Admin-only command."""
    # Only admins can call this
    pass
```

## Frontend Usage (JavaScript)

```javascript
// JavaScript example
const conn = await hass.connection;

// Simple command
const result = await conn.sendMessagePromise({
  type: "my_integration/devices",
});
console.log(result.devices);

// Command with parameters
const deviceData = await conn.sendMessagePromise({
  type: "my_integration/device/data",
  device_id: "device_123",
});

// Subscription
const unsub = conn.subscribeMessage(
  (message) => {
    console.log("Update received:", message);
  },
  { type: "my_integration/subscribe" }
);

// Later: unsub() to stop subscription
```

## Testing WebSocket Commands

```python
from homeassistant.components.websocket_api import TYPE_RESULT

async def test_websocket_get_devices(
    hass: HomeAssistant,
    hass_ws_client,
) -> None:
    """Test get devices command."""
    client = await hass_ws_client(hass)

    await client.send_json({"id": 1, "type": f"{DOMAIN}/devices"})
    msg = await client.receive_json()

    assert msg["id"] == 1
    assert msg["type"] == TYPE_RESULT
    assert msg["success"] is True
    assert "devices" in msg["result"]
```
