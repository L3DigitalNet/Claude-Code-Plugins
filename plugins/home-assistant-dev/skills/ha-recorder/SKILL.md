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

    # Disabling an entity keeps it out of the recorder; hiding only removes it from the
    # UI (it is still recorded). For true recorder exclusion, use the recorder config below.
    _attr_entity_registry_enabled_default = False  # Disabled (and not recorded) by default
    _attr_entity_registry_visible_default = False  # Hidden from the UI by default
    _attr_should_poll = True
```

Or use recorder configuration in the user's config:

```yaml
# configuration.yaml (user config, not your integration)
recorder:
  exclude:
    entity_globs:
      - sensor.my_integration_debug_*
    domains:
      # `domains` takes entity domains (sensor, switch, ...), not the integration name.
      - sensor
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

| State Class        | Use Case            | Example       |
| ------------------ | ------------------- | ------------- |
| `MEASUREMENT`      | Instantaneous value | Temperature   |
| `TOTAL`            | Resettable counter  | Trip odometer |
| `TOTAL_INCREASING` | Monotonic counter   | Energy meter  |

### Statistics-Compatible Device Classes

Measurement-type classes (`state_class: MEASUREMENT`) produce mean/min/max statistics — set `mean_type` (e.g. `StatisticMeanType.ARITHMETIC`), leave `has_sum=False`:

- `TEMPERATURE` (°C, °F)
- `POWER` (W, kW)

Cumulative/sum-type classes (`state_class: TOTAL` / `TOTAL_INCREASING`) produce sum statistics — set `has_sum=True`, leave `mean_type=StatisticMeanType.NONE`:

- `ENERGY` (kWh, Wh, MWh)
- `GAS` (m³, ft³)
- `WATER` (L, gal, m³)
- `MONETARY` (currency) — sum-based, but no unit conversion is applied

## Importing External Statistics

For integrations that provide historical data from external sources:

```python
# statistics.py
"""Statistics support for {Name}."""
from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from homeassistant.components.recorder import get_instance
from homeassistant.components.recorder.models import (
    StatisticData,
    StatisticMeanType,
    StatisticMetaData,
)
from homeassistant.components.recorder.statistics import (
    async_add_external_statistics,
    async_import_statistics,
    get_last_statistics,
)
from homeassistant.const import UnitOfEnergy
from homeassistant.core import HomeAssistant
from homeassistant.util import dt as dt_util

from .const import DOMAIN

if TYPE_CHECKING:
    from . import MyConfigEntry


async def async_import_historical_data(
    hass: HomeAssistant,
    entry: MyConfigEntry,
) -> None:
    """Import historical statistics from external source."""
    coordinator = entry.runtime_data

    # Define statistic metadata
    statistic_id = f"{DOMAIN}:energy_{entry.entry_id}"

    metadata = StatisticMetaData(
        mean_type=StatisticMeanType.NONE,
        has_sum=True,
        name="Energy Consumption",
        source=DOMAIN,
        statistic_id=statistic_id,
        unit_of_measurement=UnitOfEnergy.KILO_WATT_HOUR,
    )

    # Get last imported timestamp
    last_stats = await get_instance(hass).async_add_executor_job(
        get_last_statistics, hass, 1, statistic_id, True, {"sum"}
    )

    if statistic_id in last_stats:
        last_time = last_stats[statistic_id][0]["start"]
    else:
        last_time = None

    # Fetch historical data from your API
    historical_data = await coordinator.client.async_get_history(since=last_time)

    # Convert to statistics format
    statistics: list[StatisticData] = []
    for record in historical_data:
        statistics.append(
            StatisticData(
                start=record["timestamp"],
                sum=record["total_energy"],
            )
        )

    # Import the statistics
    async_add_external_statistics(hass, metadata, statistics)
```

> **Recorder statistics API change (2025-10-16):** `StatisticMetaData` now takes `mean_type` (a `StatisticMeanType`: `NONE` / `ARITHMETIC` / `CIRCULAR`) instead of `has_mean`, and `async_import_statistics` / `async_add_external_statistics` accept an optional `unit_class`. Re-validate any statistics calls against [the breaking-change blog](https://developers.home-assistant.io/blog/2025/10/16/recorder-statistics-api-changes).

## Querying History

For features that need historical data:

```python
from datetime import timedelta

from homeassistant.components.recorder import get_instance, history
from homeassistant.util import dt as dt_util

async def get_entity_history(
    hass: HomeAssistant,
    entity_id: str,
    hours: int = 24,
) -> list[dict]:
    """Get historical states for an entity."""
    start_time = dt_util.utcnow() - timedelta(hours=hours)
    end_time = dt_util.utcnow()

    # Use the recorder instance
    instance = get_instance(hass)

    # Query history
    states = await instance.async_add_executor_job(
        history.state_changes_during_period,
        hass,
        start_time,
        end_time,
        entity_id,
    )

    return [
        {"state": state.state, "last_changed": state.last_changed}
        for state in states.get(entity_id, [])
    ]
```

## Statistics Queries

```python
from datetime import timedelta

from homeassistant.components.recorder.statistics import (
    statistics_during_period,
)
from homeassistant.util import dt as dt_util

async def get_energy_statistics(
    hass: HomeAssistant,
    statistic_id: str,
    days: int = 30,
) -> dict:
    """Get energy statistics for the past N days."""
    start_time = dt_util.utcnow() - timedelta(days=days)

    instance = get_instance(hass)

    stats = await instance.async_add_executor_job(
        statistics_during_period,
        hass,
        start_time,
        None,  # end_time (None = now)
        {statistic_id},
        "day",  # period: "5minute", "hour", "day", "week", "month"
        None,  # units
        {"sum"},  # types: "mean", "min", "max", "sum", "state"
    )

    return stats.get(statistic_id, [])
```

## Best Practices

1. **Use appropriate state_class**: Enables automatic statistics
2. **Use standard units**: Allows unit conversion
3. **Exclude diagnostic data**: Reduces database bloat
4. **Import history incrementally**: Track last import time
5. **Handle recorder unavailable**: May be disabled by user

## Checking Recorder Availability

```python
from homeassistant.components.recorder import DOMAIN as RECORDER_DOMAIN

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up integration."""
    # Check if recorder is available
    if RECORDER_DOMAIN not in hass.config.components:
        _LOGGER.warning("Recorder not available, statistics disabled")
        return True

    # Recorder is available, set up statistics
    await async_import_historical_data(hass, entry)
    return True
```

## Related Skills

- Entity platforms → `ha-entity-platforms`
- Coordinator → `ha-coordinator`
- Diagnostics → `ha-diagnostics`
