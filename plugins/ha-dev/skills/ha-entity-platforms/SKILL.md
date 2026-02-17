---
name: ha-entity-platforms
description: Create Home Assistant entity platforms (sensor, binary_sensor, switch, light, cover, climate, button, number, select, etc.). Use when creating entities, adding platforms, implementing switches or sensors, or working with any HA entity type.
---

# Home Assistant Entity Platforms

## Platform Setup Pattern

Every platform implements `async_setup_entry`:

```python
"""Sensor platform for {Name}."""
from __future__ import annotations

from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import {Name}ConfigEntry
from .coordinator import {Name}Coordinator


async def async_setup_entry(
    hass: HomeAssistant,
    entry: {Name}ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up sensors from a config entry."""
    coordinator = entry.runtime_data

    entities = []
    for device_id in coordinator.get_device_ids():
        for description in SENSOR_DESCRIPTIONS:
            entities.append({Name}Sensor(coordinator, description, device_id))

    async_add_entities(entities)
```

## Entity Description Pattern

Use `EntityDescription` dataclasses for declarative definitions:

```python
from dataclasses import dataclass
from collections.abc import Callable
from typing import Any

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import PERCENTAGE, UnitOfTemperature


@dataclass(frozen=True, kw_only=True)
class {Name}SensorDescription(SensorEntityDescription):
    """Describe a {Name} sensor."""
    value_fn: Callable[[dict[str, Any]], Any]


SENSOR_DESCRIPTIONS: tuple[{Name}SensorDescription, ...] = (
    {Name}SensorDescription(
        key="temperature",
        translation_key="temperature",
        device_class=SensorDeviceClass.TEMPERATURE,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        value_fn=lambda data: data.get("temperature"),
    ),
    {Name}SensorDescription(
        key="humidity",
        translation_key="humidity",
        device_class=SensorDeviceClass.HUMIDITY,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=PERCENTAGE,
        value_fn=lambda data: data.get("humidity"),
    ),
)
```

## Base Entity Class

```python
"""Base entity for {Name}."""
from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from .const import DOMAIN
from .coordinator import {Name}Coordinator


class {Name}Entity(CoordinatorEntity[{Name}Coordinator]):
    """Base class for {Name} entities."""

    _attr_has_entity_name = True

    def __init__(self, coordinator: {Name}Coordinator, device_id: str) -> None:
        super().__init__(coordinator)
        self._device_id = device_id

    @property
    def device_info(self) -> DeviceInfo:
        device = self.coordinator.get_device_data(self._device_id)
        return DeviceInfo(
            identifiers={(DOMAIN, self._device_id)},
            name=device.get("name") if device else self._device_id,
            manufacturer="Manufacturer",
            model=device.get("model") if device else None,
            sw_version=device.get("firmware") if device else None,
        )

    @property
    def available(self) -> bool:
        return super().available and self.coordinator.get_device_data(self._device_id) is not None
```

## Sensor Entity

```python
class {Name}Sensor({Name}Entity, SensorEntity):
    entity_description: {Name}SensorDescription

    def __init__(self, coordinator, description, device_id):
        super().__init__(coordinator, device_id)
        self.entity_description = description
        self._attr_unique_id = f"{DOMAIN}_{device_id}_{description.key}"

    @property
    def native_value(self) -> float | str | None:
        if (data := self.coordinator.get_device_data(self._device_id)) is None:
            return None
        return self.entity_description.value_fn(data)
```

## Switch Entity

```python
from homeassistant.components.switch import SwitchDeviceClass, SwitchEntity

class {Name}Switch({Name}Entity, SwitchEntity):
    _attr_device_class = SwitchDeviceClass.SWITCH

    def __init__(self, coordinator, key, device_id):
        super().__init__(coordinator, device_id)
        self._key = key
        self._attr_unique_id = f"{DOMAIN}_{device_id}_{key}"
        self._attr_translation_key = key

    @property
    def is_on(self) -> bool | None:
        if (data := self.coordinator.get_device_data(self._device_id)) is None:
            return None
        return data.get(self._key)

    async def async_turn_on(self, **kwargs) -> None:
        await self.coordinator.client.async_set_switch(self._device_id, self._key, True)
        await self.coordinator.async_request_refresh()

    async def async_turn_off(self, **kwargs) -> None:
        await self.coordinator.client.async_set_switch(self._device_id, self._key, False)
        await self.coordinator.async_request_refresh()
```

## Platform Quick Reference

| Platform | Base Class | Key Property | Device Classes |
|---|---|---|---|
| `sensor` | `SensorEntity` | `native_value` | TEMPERATURE, HUMIDITY, POWER, ENERGY, BATTERY... |
| `binary_sensor` | `BinarySensorEntity` | `is_on` | MOTION, DOOR, WINDOW, SMOKE, MOISTURE... |
| `switch` | `SwitchEntity` | `is_on` + `turn_on/off` | SWITCH, OUTLET |
| `light` | `LightEntity` | `is_on` + `brightness` | — |
| `cover` | `CoverEntity` | `is_closed` + `open/close` | BLIND, GARAGE, SHUTTER... |
| `climate` | `ClimateEntity` | `hvac_mode` + temps | — |
| `button` | `ButtonEntity` | `async_press()` | RESTART, UPDATE, IDENTIFY |
| `number` | `NumberEntity` | `native_value` + `set_value` | — |
| `select` | `SelectEntity` | `current_option` + `select_option` | — |

## Additional Resources

For complete device class reference, see [reference/device-classes.md](reference/device-classes.md).

## Critical Rules

1. Always set `_attr_has_entity_name = True`
2. Always provide stable `unique_id`
3. Always provide `device_info` with stable `identifiers`
4. Use `translation_key` for names, not hardcoded `_attr_name`
5. Add `state_class` to numeric sensors (MEASUREMENT, TOTAL, TOTAL_INCREASING)
6. Use `native_unit_of_measurement` not `unit_of_measurement`
7. Call `async_request_refresh()` after commands
