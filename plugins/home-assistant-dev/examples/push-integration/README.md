# Push Example Integration

A **Silver-tier** example demonstrating push-based (non-polling) integrations.

## When to Use Push Pattern

Use this pattern when your device:
- Sends updates proactively (WebSocket, MQTT, callbacks)
- Has real-time state changes (motion sensors, doorbell events)
- Should not be polled (API rate limits, battery devices)

## Key Concepts

### No DataUpdateCoordinator

Unlike polling integrations, push integrations don't use `DataUpdateCoordinator`. Instead:

1. **Coordinator** maintains connection and receives updates
2. **Dispatcher** broadcasts updates to all entities
3. **Entities** subscribe to dispatcher signals

### Entity Subscription Pattern

```python
async def async_added_to_hass(self) -> None:
    """Subscribe to updates when added to hass."""
    self.async_on_remove(
        async_dispatcher_connect(
            self.hass,
            SIGNAL_UPDATE,
            self._handle_update,
        )
    )

@callback
def _handle_update(self) -> None:
    """Handle pushed update."""
    self.async_write_ha_state()
```

### Reconnection Handling

The coordinator handles:
- Initial connection
- Automatic reconnection on disconnect
- Graceful shutdown on unload

## Structure

```
push_example/
├── __init__.py      # Setup with async_connect/disconnect
├── coordinator.py   # Push connection manager
├── sensor.py        # Entity with dispatcher subscription
├── config_flow.py
├── const.py
├── manifest.json    # iot_class: local_push
└── strings.json
```

## Differences from Polling

| Aspect | Polling (DataUpdateCoordinator) | Push |
|--------|--------------------------------|------|
| Updates | Interval-based | Event-driven |
| iot_class | `local_polling` | `local_push` |
| Coordinator | DataUpdateCoordinator | Custom |
| Entity base | CoordinatorEntity | SensorEntity + dispatcher |

## License

MIT
