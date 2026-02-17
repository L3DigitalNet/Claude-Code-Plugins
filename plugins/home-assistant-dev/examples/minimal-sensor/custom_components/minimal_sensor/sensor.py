"""Sensor platform for Minimal Sensor.

This is the simplest possible sensor implementation.
For production use, consider using DataUpdateCoordinator.
"""
from __future__ import annotations

from datetime import timedelta
import random

from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorStateClass,
)
from homeassistant.config_entries import ConfigEntry
from homeassistant.const import CONF_NAME, UnitOfTemperature
from homeassistant.core import HomeAssistant
from homeassistant.helpers.entity_platform import AddEntitiesCallback

SCAN_INTERVAL = timedelta(seconds=30)


async def async_setup_entry(
    hass: HomeAssistant,
    entry: ConfigEntry,
    async_add_entities: AddEntitiesCallback,
) -> None:
    """Set up sensor platform."""
    async_add_entities([MinimalTemperatureSensor(entry)])


class MinimalTemperatureSensor(SensorEntity):
    """A minimal temperature sensor."""

    _attr_has_entity_name = True
    _attr_name = "Temperature"
    _attr_device_class = SensorDeviceClass.TEMPERATURE
    _attr_state_class = SensorStateClass.MEASUREMENT
    _attr_native_unit_of_measurement = UnitOfTemperature.CELSIUS

    def __init__(self, entry: ConfigEntry) -> None:
        """Initialize the sensor."""
        self._attr_unique_id = f"{entry.entry_id}_temperature"
        self._entry = entry

    async def async_update(self) -> None:
        """Fetch new state data for the sensor.

        This is called by Home Assistant at SCAN_INTERVAL.
        In a real integration, you would fetch data from your device here.
        """
        # Simulated temperature reading
        self._attr_native_value = round(20 + random.uniform(-2, 2), 1)
