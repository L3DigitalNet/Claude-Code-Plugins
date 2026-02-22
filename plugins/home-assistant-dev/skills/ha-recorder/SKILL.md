---
name: ha-recorder
description: Work with the Home Assistant recorder and statistics. Use when asked about history, statistics, long-term stats, database, recorder exclusion, or historical data.
---

# Home Assistant Recorder Integration

Guide for integrations that work with historical data, statistics, and the recorder.

## When to Use Recorder Features

- **Statistics**: Energy monitoring, long-term trends
- **History exclusion**: High-frequency sensors, diagnostic entities
- **Custom statistics**: External data sources
- **History queries**: Historical analysis features

## Excluding from Recorder

Exclude noisy entities from history to reduce database size:

```python
# In your entity class
class MyDiagnosticSensor(SensorEntity):
    """Sensor that shouldn't be recorded."""

    _attr_entity_registry_enabled_default = False  # Disabled by default
    _attr_should_poll = True

    @property
    def entity_registry_visible_default(self) -> bool:
        """Hide from UI by default."""
        return False
```

Or use recorder configuration in the user's config:

```yaml
# configuration.yaml (user config, not your integration)
recorder:
  exclude:
    entity_globs:
      - sensor.my_integration_debug_*
    domains:
      - my_integration_diagnostic
```

## Long-Term Statistics

For sensors that should appear in energy dashboard or statistics graphs:

```python
from homeassistant.components.sensor import (
    SensorDeviceClass,
    SensorEntity,
    SensorStateClass,
)

class MyEnergySensor(SensorEntity):
    """Energy sensor with long-term statistics."""

    _attr_device_class = SensorDeviceClass.ENERGY
    _attr_state_class = SensorStateClass.TOTAL_INCREASING
    _attr_native_unit_of_measurement = "kWh"

    # These attributes enable long-term statistics:
    # - device_class: ENERGY, GAS, WATER, etc.
    # - state_class: MEASUREMENT, TOTAL, TOTAL_INCREASING
    # - unit_of_measurement: Standard units
```

### State Classes

| State Class | Use Case | Example |
|-------------|----------|---------|
| `MEASUREMENT` | Instantaneous value | Temperature |
| `TOTAL` | Resettable counter | Trip odometer |
| `TOTAL_INCREASING` | Monotonic counter | Energy meter |

### Statistics-Compatible Device Classes

- `ENERGY` (kWh, Wh, MWh)
- `GAS` (m³, ft³)
- `WATER` (L, gal, m³)
- `MONETARY` (currency)
- `POWER` (W, kW)
- `TEMPERATURE` (°C, °F)

## Importing External Statistics and Querying History

**Full `statistics.py` implementation with incremental import and last-timestamp detection** — see [references/statistics-patterns.md](references/statistics-patterns.md)

**History state queries and recorder availability guard** — see [references/history-patterns.md](references/history-patterns.md)

## Best Practices

1. **Use appropriate state_class**: Enables automatic statistics
2. **Use standard units**: Allows unit conversion
3. **Exclude diagnostic data**: Reduces database bloat
4. **Import history incrementally**: Track last import time
5. **Handle recorder unavailable**: May be disabled by user

## Related Skills

- Entity platforms → `ha-entity-platforms`
- Coordinator → `ha-coordinator`
- Diagnostics → `ha-diagnostics`
