---
name: ha-migration
description: Migrate Home Assistant integrations between versions, fix deprecations, and handle config entry upgrades. Use when asked about migration, deprecation, upgrading integration, version compatibility, config entry version, or async_migrate_entry.
---

# Home Assistant Integration Migration

Guide for updating integrations to newer Home Assistant versions and handling config entry migrations.

## Config Entry Version Migration

When your config entry schema changes, increment VERSION and implement migration:

```python
# config_flow.py
class MyConfigFlow(ConfigFlow, domain=DOMAIN):
    """Handle config flow."""

    VERSION = 2  # Increment when schema changes
    MINOR_VERSION = 1  # For non-breaking changes
```

```python
# __init__.py
async def async_migrate_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Migrate old entry to new version."""
    _LOGGER.debug("Migrating from version %s.%s", entry.version, entry.minor_version)

    if entry.version == 1:
        # Migration from v1 to v2
        new_data = {**entry.data}
        
        # Example: rename a key
        if "old_key" in new_data:
            new_data["new_key"] = new_data.pop("old_key")
        
        # Example: add new required field with default
        if "new_field" not in new_data:
            new_data["new_field"] = "default_value"

        hass.config_entries.async_update_entry(
            entry, data=new_data, version=2, minor_version=0
        )

    if entry.version == 2 and entry.minor_version < 1:
        # Minor version migration (non-breaking)
        new_options = {**entry.options}
        new_options.setdefault("new_option", True)
        
        hass.config_entries.async_update_entry(
            entry, options=new_options, minor_version=1
        )

    _LOGGER.info("Migration to version %s.%s successful", entry.version, entry.minor_version)
    return True
```

## Deprecation Timeline

Home Assistant deprecations follow a consistent pattern:
- **Deprecated**: Warning logged, feature still works
- **Removed**: Feature no longer works (usually 1 year later)

## 2024-2025 Deprecations

### ServiceInfo Import Relocation (2025.1, removed 2026.2)

```python
# OLD (deprecated)
from homeassistant.components.zeroconf import ZeroconfServiceInfo
from homeassistant.components.ssdp import SsdpServiceInfo
from homeassistant.components.dhcp import DhcpServiceInfo
from homeassistant.components.usb import UsbServiceInfo
from homeassistant.components.bluetooth import BluetoothServiceInfo

# NEW (use these)
from homeassistant.helpers.service_info.zeroconf import ZeroconfServiceInfo
from homeassistant.helpers.service_info.ssdp import SsdpServiceInfo
from homeassistant.helpers.service_info.dhcp import DhcpServiceInfo
from homeassistant.helpers.service_info.usb import UsbServiceInfo
from homeassistant.helpers.service_info.bluetooth import BluetoothServiceInfo
```

### hass.data[DOMAIN] → runtime_data (2024.8+)

```python
# OLD pattern
async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    coordinator = MyCoordinator(hass, entry)
    await coordinator.async_config_entry_first_refresh()
    hass.data.setdefault(DOMAIN, {})[entry.entry_id] = coordinator
    # ...

async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    if unload_ok := await hass.config_entries.async_unload_platforms(entry, PLATFORMS):
        hass.data[DOMAIN].pop(entry.entry_id)
    return unload_ok

# NEW pattern
type MyConfigEntry = ConfigEntry[MyCoordinator]

async def async_setup_entry(hass: HomeAssistant, entry: MyConfigEntry) -> bool:
    coordinator = MyCoordinator(hass, entry)
    await coordinator.async_config_entry_first_refresh()
    entry.runtime_data = coordinator  # Just assign directly
    # ...

async def async_unload_entry(hass: HomeAssistant, entry: MyConfigEntry) -> bool:
    # No cleanup needed - runtime_data is automatically cleared
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
```

### OptionsFlow __init__ Deprecation (2025.12)

```python
# OLD (deprecated)
class MyOptionsFlow(OptionsFlow):
    def __init__(self, config_entry: ConfigEntry) -> None:
        self.config_entry = config_entry

    async def async_step_init(self, user_input=None):
        # Use self.config_entry
        pass

# NEW (use this)
class MyOptionsFlow(OptionsFlow):
    # No __init__ needed - self.config_entry is automatically available
    
    async def async_step_init(self, user_input=None):
        # self.config_entry is automatically set by HA
        current_value = self.config_entry.options.get("key", "default")
        pass
```

### DataUpdateCoordinator._async_setup (2024.8+)

```python
# For one-time async initialization
class MyCoordinator(DataUpdateCoordinator[dict[str, Any]]):
    async def _async_setup(self) -> None:
        """Set up the coordinator (runs once before first update)."""
        # Fetch initial device info, setup subscriptions, etc.
        self.device_info = await self.client.async_get_device_info()
    
    async def _async_update_data(self) -> dict[str, Any]:
        """Fetch data (runs on every update)."""
        return await self.client.async_get_data()
```

### VacuumActivity Enum (2025.1, removed 2026.1)

```python
# OLD (deprecated)
from homeassistant.components.vacuum import (
    STATE_CLEANING,
    STATE_DOCKED,
    STATE_PAUSED,
    STATE_IDLE,
    STATE_RETURNING,
    STATE_ERROR,
)

class MyVacuum(StateVacuumEntity):
    @property
    def state(self) -> str:
        return STATE_CLEANING

# NEW (use this)
from homeassistant.components.vacuum import VacuumActivity

class MyVacuum(StateVacuumEntity):
    @property
    def activity(self) -> VacuumActivity | None:
        return VacuumActivity.CLEANING
```

### Camera WebRTC Changes (2024.12, removed 2025.6)

```python
# OLD (deprecated)
class MyCamera(Camera):
    @property
    def frontend_stream_type(self) -> StreamType:
        return StreamType.WEB_RTC
    
    async def async_handle_web_rtc_offer(self, offer_sdp: str) -> str:
        # Handle offer
        pass

# NEW (use this)
class MyCamera(Camera):
    # frontend_stream_type is auto-detected from implementing WebRTC methods
    
    async def async_handle_async_webrtc_offer(
        self, offer_sdp: str, session_id: str, send_message: Callable
    ) -> None:
        """Handle async WebRTC offer."""
        # Use async signaling approach
        pass
```

## Type Annotation Updates (Python 3.9+)

```python
# OLD (pre-Python 3.9)
from typing import List, Dict, Optional, Union, Tuple, Set

def my_func(items: List[str]) -> Dict[str, int]:
    pass

def optional_param(value: Optional[str] = None) -> None:
    pass

# NEW (Python 3.9+)
from __future__ import annotations

def my_func(items: list[str]) -> dict[str, int]:
    pass

def optional_param(value: str | None = None) -> None:
    pass
```

## Migration Checklist

When upgrading your integration:

### For HA 2025.x Compatibility

- [ ] Add `from __future__ import annotations` to all files
- [ ] Replace `List[]`, `Dict[]`, etc. with `list[]`, `dict[]`
- [ ] Replace `Optional[X]` with `X | None`
- [ ] Replace `Union[X, Y]` with `X | Y`
- [ ] Update ServiceInfo imports to `helpers.service_info.*`
- [ ] Replace `hass.data[DOMAIN]` with `entry.runtime_data`
- [ ] Remove OptionsFlow `__init__` if only storing config_entry
- [ ] Use `VacuumActivity` enum instead of STATE_* constants
- [ ] Update Camera to use async WebRTC methods

### For Each HA Version Upgrade

1. Check the [Home Assistant Developer Blog](https://developers.home-assistant.io/blog/) for breaking changes
2. Search for deprecated imports in your code
3. Run `check-patterns.py` script to detect issues
4. Update minimum HA version in `hacs.json`
5. Test against target HA version

## Automated Migration Script

Use the migration script to automatically detect and fix common issues:

```bash
# Check for deprecations
python3 scripts/check-patterns.py custom_components/my_integration/

# The script detects:
# - Old import locations
# - Deprecated type hints
# - Blocking I/O calls
# - hass.data[DOMAIN] usage
# - OptionsFlow __init__ patterns
```

## Related Skills

- Integration structure → `ha-integration-scaffold`
- Config flow → `ha-config-flow`
- Coordinator → `ha-coordinator`
- Quality review → `ha-quality-review`
