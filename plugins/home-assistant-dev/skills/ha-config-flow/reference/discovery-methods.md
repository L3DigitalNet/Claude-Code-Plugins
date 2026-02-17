# Config Flow Discovery Methods Reference

## Import Locations (2025.1+)

**Important:** ServiceInfo models have been relocated. Old imports are deprecated and will be removed in 2026.2.

```python
# NEW (use these)
from homeassistant.helpers.service_info.zeroconf import ZeroconfServiceInfo
from homeassistant.helpers.service_info.ssdp import SsdpServiceInfo
from homeassistant.helpers.service_info.dhcp import DhcpServiceInfo
from homeassistant.helpers.service_info.usb import UsbServiceInfo
```

## Zeroconf / mDNS Discovery

**manifest.json:**
```json
{
  "zeroconf": [{"type": "_mydevice._tcp.local."}]
}
```

**config_flow.py:**
```python
from homeassistant.helpers.service_info.zeroconf import ZeroconfServiceInfo

async def async_step_zeroconf(
    self, discovery_info: ZeroconfServiceInfo
) -> ConfigFlowResult:
    self._host = discovery_info.host
    self._port = discovery_info.port
    unique_id = discovery_info.properties.get("id")

    await self.async_set_unique_id(unique_id)
    self._abort_if_unique_id_configured(updates={"host": self._host})

    self.context["title_placeholders"] = {"name": discovery_info.name}
    return await self.async_step_confirm()
```

## SSDP Discovery

**manifest.json:**
```json
{
  "ssdp": [{"st": "urn:schemas-upnp-org:device:Basic:1", "manufacturer": "MyBrand"}]
}
```

**config_flow.py:**
```python
from homeassistant.helpers.service_info.ssdp import SsdpServiceInfo

async def async_step_ssdp(
    self, discovery_info: SsdpServiceInfo
) -> ConfigFlowResult:
    unique_id = discovery_info.upnp.get("serialNumber")
    await self.async_set_unique_id(unique_id)
    self._abort_if_unique_id_configured()

    self._host = discovery_info.ssdp_headers.get("_host", "")
    self._name = discovery_info.upnp.get("friendlyName", "Unknown")
    return await self.async_step_confirm()
```

## DHCP Discovery

**manifest.json:**
```json
{
  "dhcp": [{"macaddress": "AABBCC*", "hostname": "mydevice*"}]
}
```

**config_flow.py:**
```python
from homeassistant.helpers.service_info.dhcp import DhcpServiceInfo

async def async_step_dhcp(
    self, discovery_info: DhcpServiceInfo
) -> ConfigFlowResult:
    self._host = discovery_info.ip
    self._mac = discovery_info.macaddress
    await self.async_set_unique_id(self._mac)
    self._abort_if_unique_id_configured(updates={"host": self._host})
    return await self.async_step_confirm()
```

## USB Discovery

**manifest.json:**
```json
{
  "usb": [{"vid": "10C4", "pid": "EA60", "description": "*cp2102*"}]
}
```

**config_flow.py:**
```python
from homeassistant.helpers.service_info.usb import UsbServiceInfo

async def async_step_usb(
    self, discovery_info: UsbServiceInfo
) -> ConfigFlowResult:
    self._device_path = discovery_info.device
    unique_id = f"{discovery_info.vid}:{discovery_info.pid}:{discovery_info.serial_number}"
    await self.async_set_unique_id(unique_id)
    self._abort_if_unique_id_configured()
    return await self.async_step_confirm()
```

## Key Rules

1. Always `async_set_unique_id()` then `_abort_if_unique_id_configured()`
2. Pass `updates={}` for devices whose address may change (DHCP)
3. Show confirmation step before creating entry
4. Use `context["title_placeholders"]` for device name in flow title
