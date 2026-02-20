---
name: ha-entity-lifecycle
description: Entity lifecycle and device/entity registries in Home Assistant. Use when asking about entity registration, async_added_to_hass, async_will_remove_from_hass, device_info, identifiers, or restoring previous state.
---

# Home Assistant — Entity Lifecycle and Registries

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

`identifiers` must be stable across restarts — this is how HA knows entities belong together and avoids creating duplicate device entries.
