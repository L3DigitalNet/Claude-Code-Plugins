"""Sensor platform for Push Example.

Demonstrates entities that subscribe to push updates
using Home Assistant's dispatcher pattern.
"""
from __future__ import annotations

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorStateClass,
)
from homeassistant.const import UnitOfTemperature
from homeassistant.core import HomeAssistant, callback
from homeassistant.helpers.dispatcher import async_dispatcher_connect
from homeassistant.helpers.entity_platform import AddEntitiesCallback

from . import PushConfigEntry
from .const import DOMAIN, MANUFACTURER
from .coordinator import SIGNAL_UPDATE, PushCoordinator


# Silver IQS: parallel-updates
# Push entities update via dispatcher — no concurrent update management needed.
PARALLEL_UPDATES = 0


async def async_setup_entry(
    hass: HomeAssistant,
    entry: PushConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up sensor platform."""
    coordinator = entry.runtime_data
    async_add_entities([PushTemperatureSensor(coordinator, entry)])


class PushTemperatureSensor(SensorEntity):
    """Temperature sensor that receives push updates."""

    _attr_has_entity_name = True
    _attr_name = "Temperature"
    _attr_device_class = SensorDeviceClass.TEMPERATURE
    _attr_state_class = SensorStateClass.MEASUREMENT
    _attr_native_unit_of_measurement = UnitOfTemperature.CELSIUS

    def __init__(
        self,
        coordinator: PushCoordinator,
        entry: PushConfigEntry,
    ) -> None:
        """Initialize the sensor."""
        self._coordinator = coordinator
        self._attr_unique_id = f"{entry.entry_id}_temperature"

        # Device info for grouping
        self._attr_device_info = {
            "identifiers": {(DOMAIN, coordinator.device_info.get("serial", entry.entry_id))},
            "name": coordinator.device_info.get("name", "Push Device"),
            "manufacturer": MANUFACTURER,
            "model": coordinator.device_info.get("model"),
        }

    @property
    def available(self) -> bool:
        """Return True if entity is available."""
        return self._coordinator.available

    @property
    def native_value(self) -> float | None:
        """Return the sensor value."""
        return self._coordinator.data.get("temperature")

    async def async_added_to_hass(self) -> None:
        """Subscribe to updates when added to hass."""
        # This is the key pattern for push-based entities
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
        # This triggers a state update in Home Assistant
        self.async_write_ha_state()
