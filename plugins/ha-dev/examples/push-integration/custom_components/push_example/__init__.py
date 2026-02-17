"""The Push Example integration.

This is a Silver-tier example demonstrating:
- Push-based updates (no polling)
- WebSocket/callback pattern
- Reconnection handling
- Event-driven entities

Use this for integrations where the device pushes updates.
"""
from __future__ import annotations

import logging

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import Platform
from homeassistant.core import HomeAssistant

from .const import DOMAIN
from .coordinator import PushCoordinator

_LOGGER = logging.getLogger(__name__)

PLATFORMS: list[Platform] = [Platform.SENSOR, Platform.BINARY_SENSOR]

type PushConfigEntry = ConfigEntry[PushCoordinator]


async def async_setup_entry(hass: HomeAssistant, entry: PushConfigEntry) -> bool:
    """Set up Push Example from a config entry."""
    coordinator = PushCoordinator(hass, entry)

    # Start the push connection
    await coordinator.async_connect()

    entry.runtime_data = coordinator

    # Ensure we disconnect on unload
    entry.async_on_unload(coordinator.async_disconnect)

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)

    return True


async def async_unload_entry(hass: HomeAssistant, entry: PushConfigEntry) -> bool:
    """Unload a config entry."""
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
