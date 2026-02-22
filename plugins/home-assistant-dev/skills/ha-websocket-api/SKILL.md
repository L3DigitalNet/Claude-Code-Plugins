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

## Basic WebSocket Command Structure

Three decorators define a command:

1. `@websocket_api.websocket_command({...})` — declares the message schema using voluptuous
2. `@callback` (sync) or `@websocket_api.async_response` (async) — marks execution model
3. Function signature: `(hass, connection, msg) -> None`

Always prefix command `type` with your domain: `f"{DOMAIN}/action_name"`.

Use `@callback` for pure in-memory reads. Use `@websocket_api.async_response` for any I/O.

## Registering Commands

```python
# __init__.py
from .api import async_setup_api

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    # Register WebSocket API (only once per HA startup)
    if DOMAIN not in hass.data:
        await async_setup_api(hass)
```

```python
# api.py
async def async_setup_api(hass: HomeAssistant) -> None:
    """Set up WebSocket API."""
    websocket_api.async_register_command(hass, websocket_get_devices)
    websocket_api.async_register_command(hass, websocket_get_device_data)
    websocket_api.async_register_command(hass, websocket_subscribe_updates)
```

## Best Practices

1. **Prefix commands with domain**: `my_integration/action`
2. **Use async_response for I/O**: Prevents blocking
3. **Validate input with voluptuous**: Type safety
4. **Handle errors gracefully**: Use `ERR_INVALID_FORMAT`, `ERR_NOT_FOUND`, `ERR_UNKNOWN_ERROR`
5. **Clean up subscriptions**: Store unsub in `connection.subscriptions[msg["id"]]`
6. **Document your API**: For frontend developers

## Detailed Patterns

**Full command implementations, error handling, admin-only commands, frontend JS usage, and testing** — see [references/command-patterns.md](references/command-patterns.md)

**Real-time subscription pattern with coordinator listener and connection cleanup** — see [references/subscription-patterns.md](references/subscription-patterns.md)

## Related Skills

- Frontend panels → See Home Assistant docs
- Service actions → `ha-service-actions`
- Coordinator → `ha-coordinator`
