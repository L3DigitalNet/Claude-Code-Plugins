"""Sensor platform for Example Hub.

Demonstrates:
- SensorEntityDescription pattern
- Translation keys for entity names
- Device classes and state classes
- Entity categories
- Dynamic entity creation from coordinator data
"""
from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorEntityDescription,
    SensorStateClass,
)
from homeassistant.const import PERCENTAGE, UnitOfTemperature
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import ExampleHubConfigEntry
from .coordinator import ExampleHubCoordinator
from .entity import ExampleHubEntity


@dataclass(frozen=True, kw_only=True)
class ExampleHubSensorEntityDescription(SensorEntityDescription):
    """Describes Example Hub sensor entity.

    Extends base description with a value function to extract data.
    """

    value_fn: Callable[[dict[str, Any]], float | int | str | None]


SENSOR_DESCRIPTIONS: tuple[ExampleHubSensorEntityDescription, ...] = (
    ExampleHubSensorEntityDescription(
        key="temperature",
        translation_key="temperature",
        device_class=SensorDeviceClass.TEMPERATURE,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=UnitOfTemperature.CELSIUS,
        value_fn=lambda data: data.get("temperature"),
    ),
    ExampleHubSensorEntityDescription(
        key="humidity",
        translation_key="humidity",
        device_class=SensorDeviceClass.HUMIDITY,
        state_class=SensorStateClass.MEASUREMENT,
        native_unit_of_measurement=PERCENTAGE,
        value_fn=lambda data: data.get("humidity"),
    ),
)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ExampleHubConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up sensor platform."""
    coordinator = entry.runtime_data

    # Track which devices already have entities so the listener only adds new ones
    added_device_ids: set[str] = set()

    def _add_new_entities() -> None:
        """Create sensors for devices that appeared since the last add.

        Registered as a coordinator listener so devices discovered on a later
        poll get entities, not just those present at setup.
        """
        new_entities: list[ExampleHubSensor] = []
        for device_id, device_data in coordinator.devices.items():
            if device_id in added_device_ids:
                continue
            added_device_ids.add(device_id)
            for description in SENSOR_DESCRIPTIONS:
                # Only create sensor if device has this data
                if description.value_fn(device_data) is not None:
                    new_entities.append(
                        ExampleHubSensor(coordinator, device_id, description)
                    )
        async_add_entities(new_entities)

    # Add entities for the devices present at setup, then keep listening for more
    _add_new_entities()
    entry.async_on_unload(coordinator.async_add_listener(_add_new_entities))


class ExampleHubSensor(ExampleHubEntity, SensorEntity):
    """Sensor for Example Hub."""

    entity_description: ExampleHubSensorEntityDescription

    def __init__(
        self,
        coordinator: ExampleHubCoordinator,
        device_id: str,
        description: ExampleHubSensorEntityDescription,
    ) -> None:
        """Initialize the sensor."""
        super().__init__(coordinator, device_id)
        self.entity_description = description

        # Unique ID includes sensor type
        self._attr_unique_id = f"{self._attr_unique_id}_{description.key}"

    @property
    def native_value(self) -> float | int | str | None:
        """Return the sensor value."""
        device_data = self.coordinator.devices.get(self._device_id, {})
        return self.entity_description.value_fn(device_data)
