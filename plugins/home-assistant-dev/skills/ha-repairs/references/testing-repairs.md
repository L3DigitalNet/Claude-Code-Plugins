# Testing Repair Issues

## Complete Coordinator Example

End-to-end pattern showing how a coordinator creates and clears repair issues based on data state and exceptions.

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
