# Subscription Patterns

## Real-Time Update Subscriptions

Subscriptions push events to the frontend as coordinator data changes. The connection stores an `unsub` callable keyed by message ID — HA calls it automatically when the connection closes, preventing memory leaks.

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

## Key Constraints

- `connection.subscriptions[msg["id"]]` must hold the unsub callable — HA's connection cleanup calls it on disconnect.
- Only one subscription per message ID — registering a second overwrites the first unsub and leaks the original listener.
- Use `@callback` (not `async def`) for the inner update handler — coordinator listeners are called synchronously in the event loop.
