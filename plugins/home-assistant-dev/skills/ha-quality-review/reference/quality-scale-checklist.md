# Integration Quality Scale — Detailed Reference

## Bronze Tier Implementation Examples

### action-setup
Register services in `async_setup`, not `async_setup_entry`:

```python
# __init__.py
async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Set up the integration."""
    async def handle_my_action(call: ServiceCall) -> None:
        # Handle the service call
        pass

    hass.services.async_register(DOMAIN, "my_action", handle_my_action)
    return True
```

### common-modules
Organize code into logical modules:
- `coordinator.py` — DataUpdateCoordinator subclass
- `entity.py` — Base entity class with shared logic
- `const.py` — Constants and configuration keys

### runtime-data
```python
# Modern pattern (use this)
entry.runtime_data = coordinator

# Legacy pattern (avoid)
hass.data.setdefault(DOMAIN, {})[entry.entry_id] = coordinator
```

### config-flow with data_description
```json
{
  "config": {
    "step": {
      "user": {
        "data": {
          "host": "Host"
        },
        "data_description": {
          "host": "The IP address or hostname of your device (e.g., 192.168.1.100)"
        }
      }
    }
  }
}
```

### entity-unique-id
```python
class MySensor(SensorEntity):
    def __init__(self, device_id: str, sensor_type: str) -> None:
        # Unique ID must be stable across restarts
        self._attr_unique_id = f"{device_id}_{sensor_type}"
```

### has-entity-name
```python
class MySensor(SensorEntity):
    _attr_has_entity_name = True  # Required

    def __init__(self, coordinator, description):
        self._attr_translation_key = description.key  # Use translations
        # OR for simple cases:
        # self._attr_name = "Temperature"  # Only the entity name, not device name
```

### test-before-setup
```python
async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    coordinator = MyCoordinator(hass, entry)
    
    # This validates connection - raises ConfigEntryNotReady on failure
    await coordinator.async_config_entry_first_refresh()
    
    entry.runtime_data = coordinator
    return True
```

---

## Silver Tier Implementation Examples

### action-exceptions
```python
from homeassistant.exceptions import HomeAssistantError, ServiceValidationError

async def handle_my_action(call: ServiceCall) -> None:
    if not call.data.get("target"):
        raise ServiceValidationError("Target is required")
    
    try:
        await client.do_action(call.data["target"])
    except DeviceOfflineError as err:
        raise HomeAssistantError(f"Device is offline: {err}") from err
```

### entity-unavailable
```python
class MySensor(CoordinatorEntity, SensorEntity):
    @property
    def available(self) -> bool:
        # Include coordinator availability AND device-specific checks
        return (
            super().available 
            and self._device_id in self.coordinator.data
        )
```

### parallel-updates
```python
# In sensor.py (or any platform file)
PARALLEL_UPDATES = 1  # Limit concurrent updates to 1
```

### reauthentication-flow
```python
class MyConfigFlow(ConfigFlow, domain=DOMAIN):
    async def async_step_reauth(
        self, entry_data: dict[str, Any]
    ) -> ConfigFlowResult:
        """Handle reauth when credentials expire."""
        return await self.async_step_reauth_confirm()

    async def async_step_reauth_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        errors: dict[str, str] = {}
        if user_input is not None:
            reauth_entry = self._get_reauth_entry()
            # Validate new credentials, then:
            return self.async_update_reload_and_abort(
                reauth_entry, data={**reauth_entry.data, **user_input}
            )
        return self.async_show_form(step_id="reauth_confirm", ...)
```

---

## Gold Tier Implementation Examples

### diagnostics
```python
# diagnostics.py
from homeassistant.components.diagnostics import async_redact_data

TO_REDACT = {"password", "token", "api_key", "serial"}

async def async_get_config_entry_diagnostics(
    hass: HomeAssistant, entry: ConfigEntry
) -> dict[str, Any]:
    coordinator = entry.runtime_data
    return {
        "config_entry": async_redact_data(entry.as_dict(), TO_REDACT),
        "coordinator_data": async_redact_data(coordinator.data, TO_REDACT),
    }
```

### entity-category
```python
from homeassistant.const import EntityCategory

class MyDiagnosticSensor(SensorEntity):
    _attr_entity_category = EntityCategory.DIAGNOSTIC

class MyConfigSwitch(SwitchEntity):
    _attr_entity_category = EntityCategory.CONFIG
```

### entity-disabled-by-default
```python
class MyVerboseSensor(SensorEntity):
    _attr_entity_registry_enabled_default = False  # Disabled by default
```

### reconfiguration-flow
```python
async def async_step_reconfigure(
    self, user_input: dict[str, Any] | None = None
) -> ConfigFlowResult:
    """Handle reconfiguration."""
    reconfigure_entry = self._get_reconfigure_entry()
    if user_input is not None:
        return self.async_update_reload_and_abort(
            reconfigure_entry,
            data={**reconfigure_entry.data, **user_input},
        )
    return self.async_show_form(
        step_id="reconfigure",
        data_schema=vol.Schema({...}),
    )
```

### repair-issues
```python
from homeassistant.helpers import issue_registry as ir

# Create an issue
ir.async_create_issue(
    hass,
    DOMAIN,
    "firmware_update_required",
    is_fixable=False,
    severity=ir.IssueSeverity.WARNING,
    translation_key="firmware_update_required",
    translation_placeholders={"version": "2.0.0"},
)

# Remove when resolved
ir.async_delete_issue(hass, DOMAIN, "firmware_update_required")
```

### dynamic-devices
```python
async def async_setup_entry(hass, entry, async_add_entities):
    coordinator = entry.runtime_data
    known_devices: set[str] = set()

    def _check_devices() -> None:
        current = set(coordinator.data.keys())
        new_devices = current - known_devices
        if new_devices:
            known_devices.update(new_devices)
            async_add_entities([MySensor(coordinator, d) for d in new_devices])

    _check_devices()
    entry.async_on_unload(coordinator.async_add_listener(_check_devices))
```

### stale-devices
```python
from homeassistant.helpers import device_registry as dr

async def async_setup_entry(hass, entry):
    device_registry = dr.async_get(hass)
    coordinator = entry.runtime_data
    
    # Get current device IDs from API
    current_devices = set(coordinator.data.keys())
    
    # Get registered devices
    for device_entry in dr.async_entries_for_config_entry(device_registry, entry.entry_id):
        # Check if device still exists
        device_id = next(iter(device_entry.identifiers))[1]
        if device_id not in current_devices:
            device_registry.async_remove_device(device_entry.id)
```

---

## Platinum Tier Requirements

### async-dependency
The third-party library must be natively async:
```python
# Good - native async
data = await client.async_get_data()

# Bad - requires executor
data = await hass.async_add_executor_job(client.get_data)
```

### inject-websession
Library should accept aiohttp ClientSession:
```python
from homeassistant.helpers.aiohttp_client import async_get_clientsession

async def async_setup_entry(hass, entry):
    session = async_get_clientsession(hass)
    client = MyClient(session=session)  # Pass HA's session
```

### strict-typing
All code must pass `mypy --strict`:
- All function signatures have type hints
- No `Any` types without explicit annotation
- All return types specified
