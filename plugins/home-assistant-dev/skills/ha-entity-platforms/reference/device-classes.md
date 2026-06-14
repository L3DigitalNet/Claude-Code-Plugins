# Entity Device Class Reference

## Sensor Device Classes

| Device Class | Unit Examples | Use Case |
| --- | --- | --- |
| `APPARENT_POWER` | VA | Apparent power |
| `AQI` | — | Air Quality Index |
| `ATMOSPHERIC_PRESSURE` | hPa, mbar | Barometric pressure |
| `BATTERY` | % | Battery charge level |
| `CO` | ppm, µg/m³ | Carbon monoxide |
| `CO2` | ppm | Carbon dioxide |
| `CURRENT` | A, mA | Electrical current |
| `DATA_RATE` | bit/s, Mbit/s | Network throughput |
| `DATA_SIZE` | kB, MB, GB | Storage size |
| `DISTANCE` | m, km, ft | Distance |
| `DURATION` | s, min, h | Time duration |
| `ENERGY` | Wh, kWh | Energy consumption |
| `ENERGY_STORAGE` | Wh, kWh | Stored energy (e.g. battery capacity) |
| `ENUM` | — | Limited set of non-numeric states; requires the `options` property |
| `FREQUENCY` | Hz, MHz | Frequency |
| `GAS` | m³, ft³ | Gas volume |
| `HUMIDITY` | % | Relative humidity |
| `ILLUMINANCE` | lx | Light level |
| `IRRADIANCE` | W/m² | Radiant flux per area |
| `MOISTURE` | % | Moisture level |
| `MONETARY` | ISO 4217 code | Monetary value |
| `NITROGEN_DIOXIDE` | µg/m³, ppm | NO₂ concentration |
| `NITROGEN_MONOXIDE` | µg/m³, ppb | NO concentration |
| `NITROUS_OXIDE` | µg/m³ | N₂O concentration |
| `OZONE` | µg/m³, ppm | O₃ concentration |
| `PH` | — | Acidity / pH |
| `PM1` / `PM10` / `PM25` | µg/m³ | Particulate matter |
| `POWER` | W, kW | Electrical power |
| `POWER_FACTOR` | % | Power factor |
| `PRECIPITATION` | mm, cm, in | Accumulated precipitation |
| `PRECIPITATION_INTENSITY` | mm/h, in/h | Precipitation rate |
| `PRESSURE` | Pa, hPa, psi | Pressure |
| `REACTIVE_ENERGY` | varh, kvarh | Reactive energy |
| `REACTIVE_POWER` | var, kvar | Reactive power |
| `SIGNAL_STRENGTH` | dB, dBm | Signal strength |
| `SOUND_PRESSURE` | dB, dBA | Sound pressure |
| `SPEED` | m/s, km/h, mph | Velocity |
| `SULPHUR_DIOXIDE` | µg/m³, ppb | SO₂ concentration |
| `TEMPERATURE` | °C, °F | Temperature |
| `TEMPERATURE_DELTA` | °C, °F, K | Temperature difference |
| `TIMESTAMP` | — | ISO 8601 datetime |
| `VOLATILE_ORGANIC_COMPOUNDS` | µg/m³, mg/m³ | VOC concentration (mass) |
| `VOLATILE_ORGANIC_COMPOUNDS_PARTS` | ppm, ppb | VOC concentration (parts) |
| `VOLTAGE` | V, mV | Voltage |
| `VOLUME` | L, gal, m³ | Measured volume snapshot (not a flow rate) |
| `VOLUME_FLOW_RATE` | m³/h, L/min, ft³/min | Volume per unit time (flow rate) |
| `VOLUME_STORAGE` | L, gal, m³ | Stored volume (e.g. tank capacity) |
| `WATER` | L, gal, m³ | Water consumption |
| `WEIGHT` | kg, lb | Mass |
| `WIND_SPEED` | m/s, km/h | Wind velocity |

## State Classes

| Class              | Use Case                           |
| ------------------ | ---------------------------------- |
| `MEASUREMENT`      | Instantaneous (temperature, power) |
| `TOTAL`            | Running total that can reset       |
| `TOTAL_INCREASING` | Monotonic total (energy meter)     |

## Binary Sensor Device Classes

| Class              | On         | Off          |
| ------------------ | ---------- | ------------ |
| `BATTERY`          | Low        | Normal       |
| `BATTERY_CHARGING` | Charging   | Not          |
| `CO`               | Detected   | Clear        |
| `COLD`             | Cold       | Normal       |
| `CONNECTIVITY`     | Connected  | Disconnected |
| `DOOR`             | Open       | Closed       |
| `GARAGE_DOOR`      | Open       | Closed       |
| `GAS`              | Detected   | Clear        |
| `HEAT`             | Hot        | Normal       |
| `LIGHT`            | Light      | No light     |
| `LOCK`             | Unlocked   | Locked       |
| `MOISTURE`         | Wet        | Dry          |
| `MOTION`           | Motion     | Clear        |
| `MOVING`           | Moving     | Stopped      |
| `OCCUPANCY`        | Occupied   | Clear        |
| `OPENING`          | Open       | Closed       |
| `PLUG`             | Plugged in | Unplugged    |
| `POWER`            | Power      | No power     |
| `PRESENCE`         | Present    | Away         |
| `PROBLEM`          | Problem    | OK           |
| `RUNNING`          | Running    | Not          |
| `SAFETY`           | Unsafe     | Safe         |
| `SMOKE`            | Detected   | Clear        |
| `SOUND`            | Detected   | Clear        |
| `TAMPER`           | Tampering  | Clear        |
| `UPDATE`           | Available  | Up-to-date   |
| `VIBRATION`        | Vibration  | Clear        |
| `WINDOW`           | Open       | Closed       |

> `UPDATE` is deprecated — use the [`update`](https://developers.home-assistant.io/docs/core/entity/update) entity instead of a binary sensor with this device class.

## Cover Device Classes

`AWNING`, `BLIND`, `CURTAIN`, `DAMPER`, `DOOR`, `GARAGE`, `GATE`, `SHADE`, `SHUTTER`, `WINDOW`

## Button Device Classes

`IDENTIFY` (commonly paired with entity_category=DIAGNOSTIC), `RESTART`, `UPDATE`
