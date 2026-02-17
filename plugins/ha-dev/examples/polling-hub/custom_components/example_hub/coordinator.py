"""DataUpdateCoordinator for Example Hub.

Demonstrates:
- Generic type parameter
- _async_setup for one-time initialization
- Proper error handling with UpdateFailed
- ConfigEntryAuthFailed for reauth triggering
- Logging once when unavailable/reconnected
"""
from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import CONF_HOST, CONF_PASSWORD, CONF_USERNAME
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryAuthFailed
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .const import DEFAULT_SCAN_INTERVAL, DOMAIN

_LOGGER = logging.getLogger(__name__)


class ExampleHubCoordinator(DataUpdateCoordinator[dict[str, Any]]):
    """Coordinator to manage data fetching from Example Hub.

    The generic type [dict[str, Any]] specifies the type of self.data
    """

    config_entry: ConfigEntry

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        """Initialize coordinator."""
        # Get update interval from options, with fallback to default
        scan_interval = entry.options.get("scan_interval", DEFAULT_SCAN_INTERVAL)

        super().__init__(
            hass,
            _LOGGER,
            name=DOMAIN,
            update_interval=timedelta(seconds=scan_interval),
            always_update=False,  # Only notify listeners when data actually changes
        )

        # Store connection parameters
        self._host = entry.data[CONF_HOST]
        self._username = entry.data[CONF_USERNAME]
        self._password = entry.data[CONF_PASSWORD]

        # Will be populated in _async_setup
        self.device_info: dict[str, Any] = {}
        self.devices: dict[str, dict[str, Any]] = {}

    async def _async_setup(self) -> None:
        """Set up the coordinator (runs once before first update).

        This is the right place for:
        - Fetching device info that doesn't change
        - Setting up subscriptions
        - Validating connection
        """
        try:
            # In a real integration, this would call your client library
            # self.client = MyClient(self._host, self._username, self._password)
            # self.device_info = await self.client.async_get_device_info()

            # Simulated device info
            self.device_info = {
                "serial": "EXAMPLE123",
                "name": "Example Hub",
                "model": "Hub Pro",
                "sw_version": "1.2.3",
            }

            _LOGGER.debug("Connected to Example Hub: %s", self.device_info["name"])

        except AuthenticationError as err:
            # This triggers the reauth flow
            raise ConfigEntryAuthFailed("Invalid credentials") from err
        except ConnectionError as err:
            # This will be caught by async_config_entry_first_refresh
            # and converted to ConfigEntryNotReady
            raise UpdateFailed(f"Error connecting to device: {err}") from err

    async def _async_update_data(self) -> dict[str, Any]:
        """Fetch data from the device.

        This runs on every update interval.
        """
        try:
            # In a real integration:
            # data = await self.client.async_get_data()

            # Simulated data
            data = {
                "devices": {
                    "device_1": {
                        "name": "Living Room Sensor",
                        "temperature": 22.5,
                        "humidity": 45,
                        "online": True,
                    },
                    "device_2": {
                        "name": "Bedroom Switch",
                        "state": True,
                        "online": True,
                    },
                },
                "hub_online": True,
            }

            # Track devices for dynamic entity creation
            self.devices = data.get("devices", {})

            return data

        except AuthenticationError as err:
            # Credentials expired - trigger reauth
            raise ConfigEntryAuthFailed("Authentication expired") from err
        except ConnectionError as err:
            # Device offline - will retry on next interval
            # DataUpdateCoordinator logs once when this happens
            raise UpdateFailed(f"Error communicating with device: {err}") from err


# Exception classes for the example
# In a real integration, these would come from your client library
class AuthenticationError(Exception):
    """Error indicating authentication failure."""


class ConnectionError(Exception):
    """Error indicating connection failure."""
