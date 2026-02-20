---
name: ha-config-migration
description: Config entry version migration in Home Assistant. Use when incrementing VERSION or MINOR_VERSION, implementing async_migrate_entry, or migrating stored entry data between schema versions.
---

# Home Assistant — Config Entry Version Migration

When your config entry schema changes (renaming keys, adding required fields, restructuring data), increment `VERSION` and implement `async_migrate_entry`.

## Incrementing Versions

```python
# config_flow.py
class MyConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 2        # Increment for breaking schema changes
    MINOR_VERSION = 1  # Increment for non-breaking additions
```

## async_migrate_entry Template

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
        # Minor version migration (non-breaking additions)
        new_options = {**entry.options}
        new_options.setdefault("new_option", True)

        hass.config_entries.async_update_entry(
            entry, options=new_options, minor_version=1
        )

    _LOGGER.info("Migration to version %s.%s successful", entry.version, entry.minor_version)
    return True
```

## Rules

- **Major VERSION** (`VERSION = 2`): Breaking changes — existing users' data must be transformed
- **MINOR_VERSION** (`MINOR_VERSION = 1`): Non-breaking additions — safe to add defaults
- Return `True` on success, `False` to signal migration failure (entry will be disabled)
- Always log migration for debuggability
- Migrate incrementally through versions (1→2→3), not directly to latest

## Related Skills

- Config flow → `ha-config-flow`
- Deprecation fixes → `ha-deprecation-fixes`
