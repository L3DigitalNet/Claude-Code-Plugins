---
name: ha-deprecation-fixes
description: Fix Home Assistant deprecation warnings and upgrade integrations to newer HA versions. Use when encountering deprecated imports, type annotations, or patterns that need updating for HA 2024.x/2025.x compatibility.
---

# Home Assistant — Deprecation Fixes (2024–2025)

## Deprecation Timeline

Home Assistant deprecations follow a consistent pattern:
- **Deprecated**: Warning logged, feature still works
- **Removed**: Feature no longer works (usually 1 year later)

## ServiceInfo Import Relocation (2025.1, removed 2026.2)

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

## hass.data[DOMAIN] → runtime_data (2024.8+)

```python
# OLD pattern
async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    coordinator = MyCoordinator(hass, entry)
    await coordinator.async_config_entry_first_refresh()
    hass.data.setdefault(DOMAIN, {})[entry.entry_id] = coordinator

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

async def async_unload_entry(hass: HomeAssistant, entry: MyConfigEntry) -> bool:
    # No cleanup needed - runtime_data is automatically cleared
    return await hass.config_entries.async_unload_platforms(entry, PLATFORMS)
```

## OptionsFlow \_\_init\_\_ Deprecation (2025.12)

```python
# OLD (deprecated)
class MyOptionsFlow(OptionsFlow):
    def __init__(self, config_entry: ConfigEntry) -> None:
        self.config_entry = config_entry

# NEW (use this)
class MyOptionsFlow(OptionsFlow):
    # No __init__ needed - self.config_entry is automatically available
    async def async_step_init(self, user_input=None):
        current_value = self.config_entry.options.get("key", "default")
```

## DataUpdateCoordinator._async_setup (2024.8+)

```python
class MyCoordinator(DataUpdateCoordinator[dict[str, Any]]):
    async def _async_setup(self) -> None:
        """Set up the coordinator (runs once before first update)."""
        self.device_info = await self.client.async_get_device_info()

    async def _async_update_data(self) -> dict[str, Any]:
        """Fetch data (runs on every update)."""
        return await self.client.async_get_data()
```

## VacuumActivity Enum (2025.1, removed 2026.1)

```python
# OLD (deprecated)
from homeassistant.components.vacuum import STATE_CLEANING, STATE_DOCKED
class MyVacuum(StateVacuumEntity):
    @property
    def state(self) -> str:
        return STATE_CLEANING

# NEW
from homeassistant.components.vacuum import VacuumActivity
class MyVacuum(StateVacuumEntity):
    @property
    def activity(self) -> VacuumActivity | None:
        return VacuumActivity.CLEANING
```

## Camera WebRTC Changes (2024.12, removed 2025.6)

```python
# OLD (deprecated)
class MyCamera(Camera):
    @property
    def frontend_stream_type(self) -> StreamType:
        return StreamType.WEB_RTC

    async def async_handle_web_rtc_offer(self, offer_sdp: str) -> str:
        pass

# NEW
class MyCamera(Camera):
    async def async_handle_async_webrtc_offer(
        self, offer_sdp: str, session_id: str, send_message: Callable
    ) -> None:
        pass
```

## Type Annotation Updates (Python 3.9+)

```python
# OLD (pre-Python 3.9)
from typing import List, Dict, Optional, Union

def my_func(items: List[str]) -> Dict[str, int]: ...
def optional_param(value: Optional[str] = None) -> None: ...

# NEW
from __future__ import annotations

def my_func(items: list[str]) -> dict[str, int]: ...
def optional_param(value: str | None = None) -> None: ...
```

## Migration Checklist (2025.x Compatibility)

- [ ] Add `from __future__ import annotations` to all files
- [ ] Replace `List[]`, `Dict[]`, `Optional[X]`, `Union[X, Y]` with modern syntax
- [ ] Update ServiceInfo imports to `helpers.service_info.*`
- [ ] Replace `hass.data[DOMAIN]` with `entry.runtime_data`
- [ ] Remove OptionsFlow `__init__` if only storing config_entry
- [ ] Use `VacuumActivity` enum instead of `STATE_*` constants
- [ ] Update Camera to use async WebRTC methods

## Automated Detection

```bash
# Detect common deprecations
python3 scripts/check-patterns.py custom_components/my_integration/
# Detects: old imports, deprecated type hints, blocking I/O, hass.data usage
```

## Related Skills

- Config entry migration → `ha-config-migration`
- Coordinator patterns → `ha-coordinator`
