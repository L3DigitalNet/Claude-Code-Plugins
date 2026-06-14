"""Binary sensor platform for Example Hub.

Demonstrates:
- BinarySensorEntity with a device class
- Deriving on/off state from coordinator data
"""
from __future__ import annotations

from homeassistant.components.binary_sensor import (
    BinarySensorDeviceClass,
    BinarySensorEntity,
)
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import ExampleHubConfigEntry
from .coordinator import ExampleHubCoordinator
from .entity import ExampleHubEntity


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ExampleHubConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up binary sensor platform."""
    coordinator = entry.runtime_data

    entities: list[ExampleHubBinarySensor] = [
        ExampleHubBinarySensor(coordinator, device_id)
        for device_id, device_data in coordinator.devices.items()
        if "online" in device_data
    ]

    async_add_entities(entities)


class ExampleHubBinarySensor(ExampleHubEntity, BinarySensorEntity):
    """Binary sensor reporting device connectivity."""

    _attr_translation_key = "online"
    _attr_device_class = BinarySensorDeviceClass.CONNECTIVITY

    def __init__(
        self,
        coordinator: ExampleHubCoordinator,
        device_id: str,
    ) -> None:
        """Initialize the binary sensor."""
        super().__init__(coordinator, device_id)
        self._attr_unique_id = f"{self._attr_unique_id}_online"

    @property
    def is_on(self) -> bool | None:
        """Return True if the device is online."""
        device_data = self.coordinator.devices.get(self._device_id, {})
        return device_data.get("online")
