# History Query Patterns

## Querying State History

For features that need raw historical states — runs on the recorder instance's executor thread pool to avoid blocking the event loop.

```python
from homeassistant.components.recorder import get_instance, history

async def get_entity_history(
    hass: HomeAssistant,
    entity_id: str,
    hours: int = 24,
) -> list[dict]:
    """Get historical states for an entity."""
    start_time = dt_util.utcnow() - timedelta(hours=hours)
    end_time = dt_util.utcnow()

    # Use the recorder instance
    instance = get_instance(hass)

    # Query history
    states = await instance.async_add_executor_job(
        history.state_changes_during_period,
        hass,
        start_time,
        end_time,
        entity_id,
    )

    return [
        {"state": state.state, "last_changed": state.last_changed}
        for state in states.get(entity_id, [])
    ]
```

## Checking Recorder Availability

The recorder is optional — users may disable it. Always guard before calling recorder APIs.

```python
from homeassistant.components.recorder import DOMAIN as RECORDER_DOMAIN

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up integration."""
    # Check if recorder is available
    if RECORDER_DOMAIN not in hass.config.components:
        _LOGGER.warning("Recorder not available, statistics disabled")
        return True

    # Recorder is available, set up statistics
    await async_import_historical_data(hass, entry)
    return True
```
