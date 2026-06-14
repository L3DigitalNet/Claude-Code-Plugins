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
from homeassistant.helpers.restore_state import RestoreEntity


# async_get_last_state() comes from RestoreEntity — it is NOT on CoordinatorEntity
# or the base Entity, so the restore mixin must be added.
class MyEntity(CoordinatorEntity, RestoreEntity):
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

## Entity Registry

The entity registry tracks each entity by its `unique_id` — set it via `_attr_unique_id` (or the `unique_id` property). This value is the entity's permanent identity: it must be stable across restarts and unique within the platform, and it is what lets HA persist user customizations (rename, disable, area) and recognize the same entity on reload. Entities without a `unique_id` are not registered and cannot be customized via the UI.

```python
class MyEntity(CoordinatorEntity):
    _attr_has_entity_name = True  # Modern naming: HA composes "<Device name> <entity name>"

    def __init__(self, coordinator, serial: str) -> None:
        super().__init__(coordinator)
        self._attr_unique_id = serial  # Drives entity-registry identity
        self._attr_name = "Temperature"  # Entity-specific part only, not the device name
```

HA derives the initial `entity_id` (e.g. `sensor.my_device_temperature`) from the platform and name at first registration. After that the registry owns it: the `entity_id` is persisted and only changes if the user renames it in the UI — your code must not assume a particular `entity_id`, only `unique_id` is stable. To inspect or react to registry entries, use `entity_registry.async_get(hass)`.
