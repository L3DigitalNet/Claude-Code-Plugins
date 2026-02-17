---
name: ha-architecture
description: Explain Home Assistant core architecture including event bus, state machine, service registry, entity lifecycle, and how integrations hook into them. Use when asking about HA internals, event propagation, state management, hass object, entity/device registries, or how integrations work under the hood.
---

# Home Assistant Core Architecture

Home Assistant runs on a single-threaded asyncio event loop. All code shares this loop — blocking it freezes automations, the UI, and entity updates.

## The hass Object

Every integration receives `HomeAssistant` instance (`hass`) — the central hub for all core systems:

```python
from homeassistant.core import HomeAssistant

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    # hass.bus       — Event bus for pub/sub communication
    # hass.states    — State machine for entity states
    # hass.services  — Service registry for actions
    # hass.config    — System config (location, units, timezone)
    ...
```

## Event Bus

The nervous system of Home Assistant. All component communication flows through events.

```python
from homeassistant.core import callback, Event

# Fire an event
hass.bus.async_fire("my_custom_event", {"key": "value"})

# Listen for events (@callback = sync, no I/O allowed)
@callback
def handle_event(event: Event) -> None:
    entity_id = event.data.get("entity_id")
    new_state = event.data.get("new_state")

unsub = hass.bus.async_listen("state_changed", handle_event)
entry.async_on_unload(unsub)  # Always clean up on unload
```

Key events: `state_changed`, `homeassistant_start`, `homeassistant_stop`, `call_service`, `automation_triggered`.

## State Machine

Tracks current state of every entity. States are **immutable snapshots**.

```python
state = hass.states.get("sensor.temperature")
if state is not None:
    value = state.state           # Always a string
    attrs = state.attributes      # Dict of attributes
    last_changed = state.last_changed
```

Special state values: `"unavailable"` (coordinator failed/device offline), `"unknown"` (no data yet).

## Service Registry (Actions)

Services (now called "actions" in UI) control devices. Register in `async_setup`, not `async_setup_entry`:

```python
async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    async def handle_action(call: ServiceCall) -> None:
        entity_id = call.data.get("entity_id")
        await do_something(entity_id)

    hass.services.async_register(DOMAIN, "my_action", handle_action)
    return True
```

## Entity Lifecycle

1. **Platform discovery**: `async_setup_entry` called on platform
2. **Entity creation**: Entities instantiated, passed to `async_add_entities`
3. **Registration**: HA assigns `entity_id`, registers in entity registry
4. **First update**: `async_added_to_hass` called, initial state written
5. **Updates**: Coordinator triggers `_handle_coordinator_update`
6. **Removal**: `async_will_remove_from_hass` for cleanup

```python
class MyEntity(CoordinatorEntity):
    async def async_added_to_hass(self) -> None:
        await super().async_added_to_hass()
        # Restore previous state
        if (last_state := await self.async_get_last_state()) is not None:
            self._attr_native_value = last_state.state

    async def async_will_remove_from_hass(self) -> None:
        await super().async_will_remove_from_hass()
        # Cleanup resources
```

## Device and Entity Registries

Device registry groups entities under physical/logical devices:

```python
from homeassistant.helpers.device_registry import DeviceInfo

@property
def device_info(self) -> DeviceInfo:
    return DeviceInfo(
        identifiers={(DOMAIN, self._serial)},  # Stable, unique tuple
        name="My Device",
        manufacturer="Acme",
        model="Widget Pro",
        sw_version="1.2.3",
        configuration_url="http://192.168.1.100",
    )
```

`identifiers` must be stable across restarts — this is how HA knows entities belong together.

## Integration Loading Order

1. Core starts, loads `configuration.yaml`
2. Dependencies from `manifest.json` loaded first
3. `async_setup(hass, config)` called (if present)
4. For each config entry: `async_setup_entry(hass, entry)` called
5. Platform forwarding loads each platform's `async_setup_entry`
6. Entities registered and begin receiving updates

## Key Design Principles

**Single-threaded event loop**: All async code shares one loop. Never block it.

**Immutable state**: `hass.states.get()` returns a frozen snapshot.

**Integration isolation**: Each integration manages its lifecycle via config entries. Store coordinator in `entry.runtime_data` (not `hass.data`).
