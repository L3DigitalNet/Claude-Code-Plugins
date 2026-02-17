---
name: ha-coordinator
description: Implement or fix a Home Assistant DataUpdateCoordinator for centralized data fetching. Use when mentioning coordinator, DataUpdateCoordinator, polling, data fetching, _async_update_data, _async_setup, UpdateFailed, or setting up efficient data polling for a Home Assistant integration.
---

# Home Assistant DataUpdateCoordinator Pattern

The DataUpdateCoordinator is the most important architectural pattern for polling-based integrations. It centralizes data fetching, distributes updates to entities, and handles error/retry logic automatically.

## Complete Coordinator Template (2025)

```python
"""DataUpdateCoordinator for {Name}."""
from __future__ import annotations

import logging
from datetime import timedelta
from typing import Any

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.exceptions import ConfigEntryAuthFailed
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed

from .const import DEFAULT_SCAN_INTERVAL, DOMAIN

_LOGGER = logging.getLogger(__name__)


class {Name}Coordinator(DataUpdateCoordinator[dict[str, Any]]):
    """Coordinator to manage data fetching."""

    config_entry: ConfigEntry

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        """Initialize coordinator."""
        super().__init__(
            hass,
            _LOGGER,
            name=DOMAIN,
            update_interval=timedelta(
                seconds=entry.options.get("scan_interval", DEFAULT_SCAN_INTERVAL)
            ),
            always_update=False,  # Only notify when data changes
        )
        self.client = MyClient(
            host=entry.data["host"],
            username=entry.data["username"],
            password=entry.data["password"],
        )

    async def _async_setup(self) -> None:
        """One-time initialization (Home Assistant 2024.8+).

        Called once during async_config_entry_first_refresh() before _async_update_data.
        Use for data that doesn't change: device info, serial numbers, capabilities.
        Same error handling as _async_update_data (ConfigEntryAuthFailed, UpdateFailed).
        """
        self.device_info = await self.client.async_get_device_info()

    async def _async_update_data(self) -> dict[str, Any]:
        """Fetch data from the device/API.

        Called on every polling cycle.

        Raises:
            ConfigEntryAuthFailed: Triggers reauth flow (expired/invalid credentials)
            UpdateFailed: Marks entities unavailable, logs once, retries on schedule
        """
        try:
            return await self.client.async_get_data()
        except AuthenticationError as err:
            raise ConfigEntryAuthFailed("Authentication failed") from err
        except ConnectionError as err:
            raise UpdateFailed(f"Connection error: {err}") from err
        except RateLimitError as err:
            # 2025.10+: retry_after delays next attempt
            raise UpdateFailed(
                f"Rate limited: {err}",
                translation_key="rate_limited",
            ) from err
        except TimeoutError as err:
            raise UpdateFailed(f"Timeout: {err}") from err
```

## Error Handling Reference

| Exception | Effect | When to Use |
|---|---|---|
| `UpdateFailed` | Entities unavailable, logs once, retries on schedule | Device offline, timeout, temporary error |
| `ConfigEntryAuthFailed` | Triggers reauth flow, stops polling | Expired token, invalid credentials |
| `ConfigEntryError` | Permanently fails config entry | Unrecoverable configuration error |

## Key Features

### `_async_setup` (HA 2024.8+)

One-time initialization, replaces the old pattern:

```python
# OLD PATTERN (avoid)
async def _async_update_data(self):
    if not self._initialized:
        self._initialized = True
        self.static_data = await self.client.get_info()
    return await self.client.get_data()

# NEW PATTERN (use this)
async def _async_setup(self):
    self.static_data = await self.client.get_info()

async def _async_update_data(self):
    return await self.client.get_data()
```

### `always_update=False`

Set when your data supports Python `__eq__` comparison (dicts, dataclasses). Prevents unnecessary state writes when data hasn't changed.

### `retry_after` (HA 2025.10+)

For rate-limited APIs, the coordinator respects `Retry-After` headers automatically. Ignored during first refresh (ConfigEntryNotReady handles that).

### Retriggering (HA 2025.10+)

If `async_request_refresh()` is called during an update, a new update is queued after the current one completes — no more dropped refresh requests.

## Using in __init__.py

```python
async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    coordinator = {Name}Coordinator(hass, entry)

    # Calls _async_setup() then _async_update_data()
    # Raises ConfigEntryNotReady on failure (auto-retries)
    await coordinator.async_config_entry_first_refresh()

    entry.runtime_data = coordinator  # Modern pattern

    await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)
    return True
```

## Using in Entity Platforms

```python
class MySensor(CoordinatorEntity[{Name}Coordinator], SensorEntity):
    def __init__(self, coordinator: {Name}Coordinator, device_id: str) -> None:
        super().__init__(coordinator)  # Subscribe to updates
        self._device_id = device_id

    @property
    def native_value(self) -> float | None:
        return self.coordinator.data.get("devices", {}).get(self._device_id, {}).get("temperature")

    @property
    def available(self) -> bool:
        return super().available and self._device_id in self.coordinator.data.get("devices", {})
```

## Dynamic Device Discovery

For integrations where devices appear/disappear at runtime:

```python
async def async_setup_entry(hass, entry, async_add_entities):
    coordinator = entry.runtime_data
    known_devices: set[str] = set()

    def _check_device() -> None:
        current = set(coordinator.data)
        new_devices = current - known_devices
        if new_devices:
            known_devices.update(new_devices)
            async_add_entities([MySensor(coordinator, d) for d in new_devices])

    _check_device()
    entry.async_on_unload(coordinator.async_add_listener(_check_device))
```

## Common Mistakes

1. **Not calling `async_config_entry_first_refresh()`** — setup succeeds but no data
2. **Catching exceptions too broadly** — let `ConfigEntryAuthFailed` propagate
3. **Blocking I/O in `_async_update_data`** — use `await hass.async_add_executor_job()`
4. **Using `hass.data`** — use `entry.runtime_data` instead
5. **Setting `always_update=True` unnecessarily** — causes excessive state writes
