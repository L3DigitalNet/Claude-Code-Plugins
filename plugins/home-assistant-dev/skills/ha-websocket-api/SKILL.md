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


# Plain `def`, not a coroutine: async_register_command is synchronous, so there
# is no async work to await here.
@callback
def async_setup_api(hass: HomeAssistant) -> None:
    """Register WebSocket API commands."""
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


# A command decorated with only @callback (like the one above) must be fully
# synchronous and non-blocking: it must do no awaiting and no blocking I/O. Any
# I/O requires @websocket_api.async_response and an `async def` handler.


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

`async_register_command` is global (it registers on `hass`, not per config entry) and raises if the same command type is registered twice, so it must run exactly once. Register WebSocket commands in the integration's top-level `async_setup` (called once globally) rather than in `async_setup_entry` (called per entry). If you can only register from `async_setup_entry`, gate it with an explicit one-time flag that is independent of the per-entry `hass.data[DOMAIN]` store — do not reuse `DOMAIN not in hass.data` for this, since populating that store before or after the check makes registration either never happen or double-register.

```python
# __init__.py
from .api import async_setup_api
from .const import DOMAIN

# Dedicated one-time guard key, independent of the per-entry hass.data[DOMAIN] store.
WS_REGISTERED = f"{DOMAIN}_ws_registered"


async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Set up integration (runs once, globally)."""
    # Register WebSocket commands exactly once.
    async_setup_api(hass)
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up a config entry."""
    # ... your setup code ...

    # If commands can only be registered here, use the dedicated guard — not
    # `DOMAIN not in hass.data` — so a second entry cannot double-register.
    if not hass.data.get(WS_REGISTERED):
        async_setup_api(hass)
        hass.data[WS_REGISTERED] = True

    # ... rest of setup ...
    return True
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

    # Subscribe to every matching coordinator and collect their unsub callables.
    # Storing only the last one would leak every other listener — exactly the
    # memory leak Best Practice #5 warns against.
    unsubs = []
    for coordinator in hass.data.get(DOMAIN, {}).values():
        if device_id is None or device_id in coordinator.devices:
            unsubs.append(coordinator.async_add_listener(async_handle_update))

    @callback
    def _unsub_all() -> None:
        """Unsubscribe from all matching coordinators."""
        for unsub in unsubs:
            unsub()

    # Register the combined unsubscribe before sending the result so it is in
    # place before any event can fire.
    connection.subscriptions[msg["id"]] = _unsub_all

    # Send initial confirmation
    connection.send_result(msg["id"])
```

## Error Handling

Catch only the specific exceptions you can map to a meaningful client error code. For the catch-all branch, log the exception server-side with `_LOGGER.exception` and send a generic, non-leaking message — never `str(err)`, which can expose sensitive internals to the WS client. In practice you usually do not need the catch-all at all: `websocket_api` already wraps unhandled exceptions and reports `ERR_UNKNOWN_ERROR` for you.

```python
import logging

from homeassistant.components.websocket_api import (
    ERR_INVALID_FORMAT,
    ERR_NOT_FOUND,
    ERR_UNKNOWN_ERROR,
)

_LOGGER = logging.getLogger(__name__)

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
    except Exception:
        # Log the real error server-side; return a generic message so internals
        # never leak to the WS client. (Often unnecessary: websocket_api already
        # wraps unhandled exceptions as ERR_UNKNOWN_ERROR.)
        _LOGGER.exception("Unexpected error handling %s", msg["type"])
        connection.send_error(
            msg["id"], ERR_UNKNOWN_ERROR, "An unexpected error occurred"
        )
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
const conn = await hass.connection

// Simple command
const result = await conn.sendMessagePromise({ type: 'my_integration/devices' })
console.log(result.devices)

// Command with parameters
const deviceData = await conn.sendMessagePromise({
	type: 'my_integration/device/data',
	device_id: 'device_123',
})

// Subscription
const unsub = conn.subscribeMessage(
	(message) => {
		console.log('Update received:', message)
	},
	{ type: 'my_integration/subscribe' }
)

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

- Data source for commands → `ha-coordinator`
- Entity platforms → `ha-entity-platforms`
- Service actions → `ha-service-actions`
