---
name: ha-websocket-api
description: Implement WebSocket API commands for Home Assistant integrations. Use when asked about WebSocket API, custom API endpoints, frontend integration, custom panels, or real-time data to frontend.
---

# Home Assistant WebSocket API

Create custom WebSocket API commands for frontend integration, custom panels, or third-party tools.

## When to Use WebSocket API

Use WebSocket API for:
- Custom frontend panels needing real-time data
- Complex queries not covered by standard APIs
- Integration-specific configuration UIs
- Streaming data to clients
- Third-party tool integration

## Basic WebSocket Command

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

## Registering the API

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

## Subscription Commands

For real-time updates to the frontend:

```python
@websocket_api.websocket_command(
    {
        vol.Required("type"): f"{DOMAIN}/subscribe",
        vol.Optional("device_id"): str,
    }
)
@websocket_api.async_response
async def websocket_subscribe_updates(
    hass: HomeAssistant,
    connection: websocket_api.ActiveConnection,
    msg: dict[str, Any],
) -> None:
    """Subscribe to updates."""
    device_id = msg.get("device_id")

    @callback
    def async_handle_update() -> None:
        """Handle coordinator update."""
        # Send update to client
        connection.send_message(
            websocket_api.event_message(
                msg["id"],
                {"event": "update", "device_id": device_id},
            )
        )

    # Subscribe to coordinator updates
    for coordinator in hass.data.get(DOMAIN, {}).values():
        if device_id is None or device_id in coordinator.devices:
            unsub = coordinator.async_add_listener(async_handle_update)
            # Unsubscribe when connection closes
            connection.subscriptions[msg["id"]] = unsub

    # Send initial confirmation
    connection.send_result(msg["id"])
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

## Requiring Authentication

By default, WebSocket commands require authentication. For admin-only commands:

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

## Frontend Usage

From a custom panel or card:

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

## Best Practices

1. **Prefix commands with domain**: `my_integration/action`
2. **Use async_response for I/O**: Prevents blocking
3. **Validate input with voluptuous**: Type safety
4. **Handle errors gracefully**: Use appropriate error codes
5. **Clean up subscriptions**: Prevent memory leaks
6. **Document your API**: For frontend developers

## Related Skills

- Frontend panels → See Home Assistant docs
- Service actions → `ha-service-actions`
- Coordinator → `ha-coordinator`
