---
name: ha-repairs
description: Implement repair issues for Home Assistant integrations. Gold tier IQS requirement. Use when asked about repair issues, issue registry, user notifications, fixable issues, or actionable alerts.
---

# Home Assistant Repair Issues

Repair issues provide actionable notifications to users about problems that require attention. **Gold tier IQS requirement.**

## When to Use Repairs

Use repair issues for:
- Configuration problems the user can fix
- Firmware updates available
- Deprecated features being used
- Missing optional dependencies
- Service disruptions with user action needed

Do NOT use for:
- Transient errors (use logging)
- Entity unavailability (use `available` property)
- Internal errors (use exceptions)

## Basic Implementation

```python
from homeassistant.helpers import issue_registry as ir

# Create an issue
ir.async_create_issue(
    hass,
    DOMAIN,
    "firmware_update_available",
    is_fixable=False,
    severity=ir.IssueSeverity.WARNING,
    translation_key="firmware_update_available",
    translation_placeholders={
        "current_version": "1.0.0",
        "new_version": "2.0.0",
    },
)
```

## Severity Levels

```python
from homeassistant.helpers.issue_registry import IssueSeverity

IssueSeverity.CRITICAL  # Immediate action required
IssueSeverity.ERROR     # Something is broken
IssueSeverity.WARNING   # Should be addressed soon
```

## Issue Types

### Non-Fixable Issue

User must take action outside Home Assistant:

```python
ir.async_create_issue(
    hass,
    DOMAIN,
    "device_firmware_outdated",
    is_fixable=False,
    severity=ir.IssueSeverity.WARNING,
    translation_key="device_firmware_outdated",
    translation_placeholders={
        "device": device_name,
        "version": current_version,
    },
    learn_more_url="https://example.com/firmware-update",
)
```

### Fixable Issue (with Repair Flow)

User can fix directly in Home Assistant:

```python
# In __init__.py or where issue is detected
ir.async_create_issue(
    hass,
    DOMAIN,
    f"reauth_required_{entry.entry_id}",
    is_fixable=True,
    severity=ir.IssueSeverity.ERROR,
    translation_key="reauth_required",
    data={"entry_id": entry.entry_id},
)
```

```python
# repairs.py
from homeassistant import data_entry_flow
from homeassistant.components.repairs import RepairsFlow

class ReauthRequiredRepairFlow(RepairsFlow):
    """Handler for reauth repair flow."""

    async def async_step_init(
        self, user_input: dict[str, Any] | None = None
    ) -> data_entry_flow.FlowResult:
        """Handle the first step."""
        return await self.async_step_confirm()

    async def async_step_confirm(
        self, user_input: dict[str, Any] | None = None
    ) -> data_entry_flow.FlowResult:
        """Handle the confirm step."""
        if user_input is not None:
            entry_id = self.data["entry_id"]
            entry = self.hass.config_entries.async_get_entry(entry_id)
            if entry:
                self.hass.async_create_task(
                    self.hass.config_entries.flow.async_init(
                        DOMAIN,
                        context={"source": "reauth", "entry_id": entry_id},
                    )
                )
            return self.async_create_entry(data={})

        return self.async_show_form(step_id="confirm")


async def async_create_fix_flow(
    hass: HomeAssistant,
    issue_id: str,
    data: dict[str, Any] | None,
) -> RepairsFlow:
    """Create flow."""
    if issue_id.startswith("reauth_required_"):
        return ReauthRequiredRepairFlow()
    raise ValueError(f"Unknown issue: {issue_id}")
```

## strings.json for Repairs

```json
{
  "issues": {
    "firmware_update_available": {
      "title": "Firmware update available",
      "description": "Device {device} has firmware {current_version}. Version {new_version} is available with important fixes."
    },
    "reauth_required": {
      "title": "Re-authentication required",
      "fix_flow": {
        "step": {
          "confirm": {
            "title": "Re-authenticate",
            "description": "Your credentials have expired. Click submit to re-authenticate."
          }
        }
      }
    }
  }
}
```

## Removing Issues

```python
# Remove when issue is resolved
ir.async_delete_issue(hass, DOMAIN, "firmware_update_available")

# Remove all issues for an entry (e.g., on unload)
ir.async_delete_issue(hass, DOMAIN, f"reauth_required_{entry.entry_id}")
```

## Complete Example

```python
# coordinator.py
class MyCoordinator(DataUpdateCoordinator):
    async def _async_update_data(self):
        try:
            data = await self.client.async_get_data()
            
            # Check for conditions that need user attention
            if data.get("firmware_update_available"):
                ir.async_create_issue(
                    self.hass,
                    DOMAIN,
                    f"firmware_{self.config_entry.entry_id}",
                    is_fixable=False,
                    severity=ir.IssueSeverity.WARNING,
                    translation_key="firmware_update",
                    translation_placeholders={
                        "current": data["firmware_version"],
                        "available": data["available_version"],
                    },
                )
            else:
                # Clear issue if no longer applicable
                ir.async_delete_issue(
                    self.hass,
                    DOMAIN,
                    f"firmware_{self.config_entry.entry_id}",
                )
            
            return data
            
        except AuthenticationError:
            ir.async_create_issue(
                self.hass,
                DOMAIN,
                f"auth_{self.config_entry.entry_id}",
                is_fixable=True,
                severity=ir.IssueSeverity.ERROR,
                translation_key="authentication_failed",
            )
            raise ConfigEntryAuthFailed
```

## Related Skills

- Config flow → `ha-config-flow`
- Coordinator → `ha-coordinator`
- Quality review → `ha-quality-review`
