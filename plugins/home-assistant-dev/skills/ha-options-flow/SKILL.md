---
name: ha-options-flow
description: Home Assistant options flow for post-setup user preferences. Use when adding or fixing an options flow, allowing users to change integration settings after initial setup, or implementing reauth when credentials expire.
---

# Home Assistant — Options Flow and Reauth

## OptionsFlow Template

Options flow lets users adjust integration settings after initial setup (scan interval, feature toggles, etc.).

```python
from homeassistant.config_entries import ConfigEntry, ConfigFlowResult, OptionsFlow
import voluptuous as vol


class {Name}OptionsFlow(OptionsFlow):
    """Handle options."""

    # NOTE: Do NOT use __init__ to store config_entry - deprecated since 2025.12
    # Access via self.config_entry (automatically set by HA)

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(title="", data=user_input)

        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema({
                vol.Optional(
                    "scan_interval",
                    default=self.config_entry.options.get("scan_interval", 30),
                ): vol.All(vol.Coerce(int), vol.Range(min=10, max=300)),
            }),
        )
```

Wire it to the config flow class with `async_get_options_flow`:

```python
from homeassistant.core import callback

class {Name}ConfigFlow(ConfigFlow, domain=DOMAIN):
    ...
    @staticmethod
    @callback
    def async_get_options_flow(config_entry: ConfigEntry) -> OptionsFlow:
        return {Name}OptionsFlow()
```

## strings.json — Options Section

```json
{
  "options": {
    "step": {
      "init": {
        "title": "Settings",
        "data": {
          "scan_interval": "Update interval (seconds)"
        },
        "data_description": {
          "scan_interval": "How often to poll the device (10-300 seconds)"
        }
      }
    }
  }
}
```

## Reauth Flow

Reauth handles expired credentials without removing the integration. Add to the `ConfigFlow` class (not `OptionsFlow`):

```python
async def async_step_reauth(
    self, entry_data: dict[str, Any]
) -> ConfigFlowResult:
    """Handle reauth when credentials expire."""
    return await self.async_step_reauth_confirm()

async def async_step_reauth_confirm(
    self, user_input: dict[str, Any] | None = None
) -> ConfigFlowResult:
    """Collect new credentials for reauth."""
    errors: dict[str, str] = {}

    if user_input is not None:
        reauth_entry = self._get_reauth_entry()
        data = {**reauth_entry.data, **user_input}
        try:
            await self._async_validate_input(data)
        except CannotConnect:
            errors["base"] = "cannot_connect"
        except InvalidAuth:
            errors["base"] = "invalid_auth"
        else:
            return self.async_update_reload_and_abort(reauth_entry, data=data)

    return self.async_show_form(
        step_id="reauth_confirm",
        data_schema=vol.Schema({
            vol.Required(CONF_USERNAME): str,
            vol.Required(CONF_PASSWORD): str,
        }),
        errors=errors,
    )
```

Trigger reauth from the coordinator when an API call fails with `401`:

```python
raise ConfigEntryAuthFailed("Credentials expired")
```

## Data vs Options

- **`entry.data`** — Connection info (host, credentials). Set once at setup.
- **`entry.options`** — User preferences (scan interval, feature flags). Changed via options flow.

Never store user preferences in `entry.data` — they belong in `entry.options` so the options flow can update them without requiring re-setup.
