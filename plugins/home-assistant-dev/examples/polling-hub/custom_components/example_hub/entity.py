"""Base entity for Example Hub.

Provides shared functionality for all entity platforms:
- Device info
- Availability based on coordinator
- Unique ID generation
"""
from __future__ import annotations

from homeassistant.helpers.device_registry import DeviceInfo
from homeassistant.helpers.update_coordinator import CoordinatorEntity

from . import ExampleHubConfigEntry
from .const import DOMAIN, MANUFACTURER
from .coordinator import ExampleHubCoordinator


class ExampleHubEntity(CoordinatorEntity[ExampleHubCoordinator]):
    """Base class for Example Hub entities.

    Provides:
    - Automatic availability based on coordinator
    - Device info for grouping entities
    - Has entity name support
    """

    _attr_has_entity_name = True

    def __init__(
        self,
        coordinator: ExampleHubCoordinator,
        device_id: str,
    ) -> None:
        """Initialize the entity."""
        super().__init__(coordinator)
        self._device_id = device_id

        # Base unique ID - subclasses should append entity type
        self._attr_unique_id = f"{coordinator.config_entry.entry_id}_{device_id}"

    @property
    def device_info(self) -> DeviceInfo:
        """Return device info for grouping entities."""
        device_data = self.coordinator.devices.get(self._device_id, {})
        hub_info = self.coordinator.device_info

        return DeviceInfo(
            identifiers={(DOMAIN, self._device_id)},
            name=device_data.get("name", f"Device {self._device_id}"),
            manufacturer=MANUFACTURER,
            model=hub_info.get("model"),
            sw_version=hub_info.get("sw_version"),
            via_device=(DOMAIN, hub_info.get("serial")),
        )

    @property
    def available(self) -> bool:
        """Return True if entity is available.

        Checks both coordinator availability and device-specific online status.
        """
        if not super().available:
            return False

        # Check device-specific availability
        device_data = self.coordinator.devices.get(self._device_id, {})
        return device_data.get("online", True)
