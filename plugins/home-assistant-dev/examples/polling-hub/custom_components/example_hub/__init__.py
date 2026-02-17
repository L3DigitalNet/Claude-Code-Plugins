"""The Example Hub integration.

This is a Gold-tier reference implementation demonstrating:
- DataUpdateCoordinator with _async_setup
- entry.runtime_data pattern
- Proper error handling with ConfigEntryNotReady
- Multi-platform support (sensor, switch, binary_sensor)
- Options flow integration
"""
from __future__ import annotations

import logging

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryNotReady

from .const import DOMAIN
from .coordinator import ExampleHubCoordinator

_LOGGER = logging.getLogger(__name__)

PLATFORMS: list[Platform] = [
    Platform.SENSOR,
    Platform.SWITCH,
    Platform.BINARY_SENSOR,
]

# Type alias for config entry with typed runtime_data
type ExampleHubConfigEntry = ConfigEntry[ExampleHubCoordinator]


async def async_setup_entry(hass: HomeAssistant, entry: ExampleHubConfigEntry) -> bool:
    """Set up Example Hub from a config entry."""
    coordinator = ExampleHubCoordinator(hass, entry)

    # This validates connection and raises ConfigEntryNotReady if it fails
    # The coordinator handles logging and retry logic
    await coordinator.async_config_entry_first_refresh()

    # Store coordinator in runtime_data (modern pattern)
    entry.runtime_data = coordinator

    # Register update listener for options changes
    entry.async_on_unload(entry.add_update_listener(async_reload_entry))

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)

    return True


async def async_unload_entry(hass: HomeAssistant, entry: ExampleHubConfigEntry) -> bool:
    """Unload a config entry."""
    # runtime_data is automatically cleaned up - no manual cleanup needed
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)


async def async_reload_entry(hass: HomeAssistant, entry: ExampleHubConfigEntry) -> None:
    """Reload config entry when options change."""
    await hass.config_entries.async_reload(entry.entry_id)
