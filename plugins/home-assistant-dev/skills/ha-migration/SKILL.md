---
name: ha-migration
description: Home Assistant integration upgrade guide — config entry version migration and deprecation fixes. Use when upgrading an integration to a newer HA version or handling migration warnings.
---

# Home Assistant Integration Migration

This skill is an entry point for two distinct migration concerns:

## Config Entry Version Migration

When your config entry **schema changes** (renaming keys, adding required fields), you need to increment `VERSION` and implement `async_migrate_entry`.

See `ha-config-migration` for the full pattern and template.

**When to use it:** You changed what's stored in `entry.data` or `entry.options` and existing users' data needs to be transformed.

## Deprecation Fixes

When upgrading to a newer HA version, imports, type annotations, and API patterns that were deprecated may now emit warnings or fail.

See `ha-deprecation-fixes` for 2024–2025 deprecation patterns with before/after examples.

**When to use it:** You see deprecation warnings in HA logs, or you're upgrading `homeassistant` minimum version in `hacs.json`.

## Migration Checklist (Per Version Upgrade)

1. Check the [Home Assistant Developer Blog](https://developers.home-assistant.io/blog/) for breaking changes
2. Search for deprecated imports in your code
3. Run `check-patterns.py` to detect common issues:
   ```bash
   python3 scripts/check-patterns.py custom_components/my_integration/
   ```
4. Update minimum HA version in `hacs.json`
5. Test against target HA version

## Related Skills

- Config entry migration → `ha-config-migration`
- Deprecation patterns → `ha-deprecation-fixes`
- Integration structure → `ha-integration-scaffold`
