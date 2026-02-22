# Statistics Patterns

## Importing External Statistics

For integrations that provide historical data from external sources — creates a `statistics.py` module, detects the last imported timestamp to avoid duplicates, and imports incrementally.

```python
# statistics.py
"""Statistics support for {Name}."""
from __future__ import annotations

from datetime import datetime
from typing import TYPE_CHECKING

from homeassistant.components.recorder import get_instance
from homeassistant.components.recorder.models import StatisticData, StatisticMetaData
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
        has_mean=False,
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

## Statistics Queries

Query aggregated statistics by period — use for features that display historical trend data.

```python
from homeassistant.components.recorder.statistics import (
    statistics_during_period,
)

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
