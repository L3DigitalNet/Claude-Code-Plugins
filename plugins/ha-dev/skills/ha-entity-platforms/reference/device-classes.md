# Entity Device Class Reference

## Sensor Device Classes

| Device Class | Unit Examples | Use Case |
|---|---|---|
| `APPARENT_POWER` | VA | Apparent power |
| `AQI` | — | Air Quality Index |
| `ATMOSPHERIC_PRESSURE` | hPa, mbar | Barometric pressure |
| `BATTERY` | % | Battery charge level |
| `CO` | ppm | Carbon monoxide |
| `CO2` | ppm | Carbon dioxide |
| `CURRENT` | A, mA | Electrical current |
| `DATA_RATE` | bit/s, Mbit/s | Network throughput |
| `DATA_SIZE` | kB, MB, GB | Storage size |
| `DISTANCE` | m, km, ft | Distance |
| `DURATION` | s, min, h | Time duration |
| `ENERGY` | Wh, kWh | Energy consumption |
| `FREQUENCY` | Hz, MHz | Frequency |
| `GAS` | m³, ft³ | Gas volume |
| `HUMIDITY` | % | Relative humidity |
| `ILLUMINANCE` | lx | Light level |
| `MOISTURE` | % | Moisture level |
| `PM1` / `PM10` / `PM25` | µg/m³ | Particulate matter |
| `POWER` | W, kW | Electrical power |
| `POWER_FACTOR` | % | Power factor |
| `PRESSURE` | Pa, hPa, psi | Pressure |
| `SIGNAL_STRENGTH` | dB, dBm | Signal strength |
| `SPEED` | m/s, km/h, mph | Velocity |
| `TEMPERATURE` | °C, °F | Temperature |
| `TIMESTAMP` | — | ISO 8601 datetime |
| `VOLTAGE` | V, mV | Voltage |
| `VOLUME` | L, gal, m³ | Volume |
| `WATER` | L, gal | Water consumption |
| `WEIGHT` | kg, lb | Mass |
| `WIND_SPEED` | m/s, km/h | Wind velocity |

## State Classes

| Class | Use Case |
|---|---|
| `MEASUREMENT` | Instantaneous (temperature, power) |
| `TOTAL` | Running total that can reset |
| `TOTAL_INCREASING` | Monotonic total (energy meter) |

## Binary Sensor Device Classes

| Class | On | Off |
|---|---|---|
| `BATTERY` | Low | Normal |
| `BATTERY_CHARGING` | Charging | Not |
| `CONNECTIVITY` | Connected | Disconnected |
| `DOOR` | Open | Closed |
| `GARAGE_DOOR` | Open | Closed |
| `GAS` | Detected | Clear |
| `LIGHT` | Light | No light |
| `LOCK` | Unlocked | Locked |
| `MOISTURE` | Wet | Dry |
| `MOTION` | Motion | Clear |
| `OCCUPANCY` | Occupied | Clear |
| `POWER` | Power | No power |
| `PRESENCE` | Present | Away |
| `PROBLEM` | Problem | OK |
| `RUNNING` | Running | Not |
| `SMOKE` | Detected | Clear |
| `WINDOW` | Open | Closed |

## Cover Device Classes

`AWNING`, `BLIND`, `CURTAIN`, `DAMPER`, `DOOR`, `GARAGE`, `GATE`, `SHADE`, `SHUTTER`, `WINDOW`

## Button Device Classes

`IDENTIFY` (entity_category must be DIAGNOSTIC), `RESTART`, `UPDATE`
