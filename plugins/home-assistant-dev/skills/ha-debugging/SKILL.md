---
name: ha-debugging
description: Debug and troubleshoot Home Assistant integration issues. Use when mentioning error, debug, not working, unavailable, traceback, exception, logs, failing, ConfigEntryNotReady, UpdateFailed, or needing help diagnosing HA integration problems.
---

# Debugging Home Assistant Integrations

## Step 1: Enable Debug Logging

Add to `configuration.yaml`:

```yaml
logger:
  default: warning
  logs:
    custom_components.{domain}: debug
    homeassistant.config_entries: debug
```

View: Settings → System → Logs, or `tail -f config/home-assistant.log`

## Step 2: Identify Error Category

| Symptom | Likely Cause | Check |
|---|---|---|
| Integration won't load | Import/manifest error | `__init__.py`, `manifest.json` |
| "Config flow could not be loaded" | Syntax error | `config_flow.py`, `strings.json` |
| "Unexpected exception" in setup | Unhandled error | Config flow validation |
| Entities "unavailable" | Coordinator UpdateFailed | `coordinator.py` |
| Entities don't appear | Missing platform forward | `__init__.py`, platform files |
| "ConfigEntryNotReady" | First refresh failed | Coordinator/API connection |
| State not updating | Subscription broken | Entity `super().__init__()` |

## Common Fixes

### ImportError / ModuleNotFoundError

```python
# Check relative imports
from .const import DOMAIN  # RIGHT
from custom_components.my_integration.const import DOMAIN  # WRONG

# Check manifest.json requirements
# Check __init__.py exists
```

### Config Flow "Unexpected exception"

```python
async def async_step_user(self, user_input=None):
    errors: dict[str, str] = {}  # MUST initialize!
    if user_input is not None:
        try:
            # validation
        except Exception:
            _LOGGER.exception("Setup failed")  # Log actual error
            errors["base"] = "unknown"
    return self.async_show_form(..., errors=errors)
```

### Entities Unavailable

```python
# Check coordinator raises UpdateFailed properly
async def _async_update_data(self):
    try:
        return await self.client.get_data()
    except Exception as err:
        raise UpdateFailed(f"Error: {err}") from err

# Check entity available property
@property
def available(self) -> bool:
    return super().available and self._device_id in self.coordinator.data
```

### Entities Not Appearing

```python
# Check PLATFORMS list
PLATFORMS = [Platform.SENSOR, Platform.SWITCH]

# Check platform forwarding
await hass.config_entries.async_forward_entry_setups(entry, PLATFORMS)

# Check async_add_entities is called
async def async_setup_entry(hass, entry, async_add_entities):
    entities = [MySensor(coordinator, "temp")]
    async_add_entities(entities)  # Must be called!
```

### Blocking Event Loop

```python
# WRONG
data = requests.get(url)

# RIGHT
data = await hass.async_add_executor_job(requests.get, url)
```

### State Not Updating

```python
# Check inheritance order
class MySensor(CoordinatorEntity[MyCoordinator], SensorEntity):  # Coordinator FIRST!

# Check super().__init__ is called
def __init__(self, coordinator):
    super().__init__(coordinator)  # REQUIRED!

# Check native_value reads from coordinator
@property
def native_value(self):
    return self.coordinator.data.get("value")
```

## Diagnostic Commands

```bash
# Validate JSON
python -c "import json; json.load(open('manifest.json'))"
python -c "import json; json.load(open('strings.json'))"

# Check syntax
python -m py_compile __init__.py
python -m py_compile config_flow.py

# Lint
ruff check .

# Type check
mypy .

# Check if loaded
grep '{domain}' config/home-assistant.log | tail -20
```

## Workflow

1. **Reproduce** — exact steps
2. **Enable debug logging**
3. **Check logs** — find first error, not last
4. **Isolate** — which file/function
5. **Fix** — apply targeted fix
6. **Verify** — restart HA, confirm
7. **Test** — write regression test
