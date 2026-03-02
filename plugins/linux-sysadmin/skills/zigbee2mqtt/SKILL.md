---
name: zigbee2mqtt
description: >
  Zigbee2MQTT bridge administration: coordinator setup, device pairing,
  network configuration, OTA firmware updates, MQTT integration, and
  troubleshooting. Triggers on: zigbee2mqtt, Zigbee2MQTT, zigbee, Zigbee bridge,
  zigbee coordinator, zigbee devices MQTT, Z2M, zigbee pairing, zigbee network,
  CC2652, Sonoff Zigbee, ConBee, zigbee adapter, permit_join.
globs:
  - "**/zigbee2mqtt/configuration.yaml"
  - "**/zigbee2mqtt/data/configuration.yaml"
---

## Identity
- **Unit**: `zigbee2mqtt.service` (systemd) or Docker container `zigbee2mqtt`
- **Config**: `/opt/zigbee2mqtt/data/configuration.yaml` (bare metal) or `./data/configuration.yaml` (Docker volume)
- **Logs**: `journalctl -u zigbee2mqtt -f` (systemd) or `docker logs -f zigbee2mqtt`
- **Serial device**: `/dev/ttyUSB0`, `/dev/ttyACM0` — use `/dev/serial/by-id/...` for stability
- **Frontend**: `http://<host>:8080` (must be explicitly enabled in config)
- **Depends on**: Mosquitto (or any MQTT broker) — must be running before Z2M starts
- **Install**: Node.js service (`git clone`, `npm ci`) or `docker run koenkk/zigbee2mqtt`
- **User**: typically `pi`, `ubuntu`, or a dedicated `zigbee2mqtt` user; must be in `dialout` group

## Key Operations

| Operation | Command |
|-----------|---------|
| Check service status | `systemctl status zigbee2mqtt` |
| Follow logs live | `journalctl -u zigbee2mqtt -f` |
| Restart service | `sudo systemctl restart zigbee2mqtt` |
| Permit join (pair new device) | `mosquitto_pub -t zigbee2mqtt/bridge/request/permit_join -m '{"value": true, "time": 254}'` |
| Disable permit join | `mosquitto_pub -t zigbee2mqtt/bridge/request/permit_join -m '{"value": false}'` |
| List all devices | `mosquitto_sub -t zigbee2mqtt/bridge/devices -C 1` |
| Remove a device | `mosquitto_pub -t zigbee2mqtt/bridge/request/device/remove -m '{"id": "FRIENDLY_NAME"}'` |
| Rename a device | `mosquitto_pub -t zigbee2mqtt/bridge/request/device/rename -m '{"from": "OLD", "to": "NEW"}'` |
| Check coordinator info | `mosquitto_sub -t zigbee2mqtt/bridge/info -C 1` |
| Force device re-interview | `mosquitto_pub -t zigbee2mqtt/bridge/request/device/interview -m '{"id": "FRIENDLY_NAME"}'` |
| Trigger OTA update check | `mosquitto_pub -t zigbee2mqtt/bridge/request/device/ota_update/check -m '{"id": "FRIENDLY_NAME"}'` |
| Start OTA update | `mosquitto_pub -t zigbee2mqtt/bridge/request/device/ota_update/update -m '{"id": "FRIENDLY_NAME"}'` |
| Backup configuration | Copy `data/configuration.yaml` and `data/database.db` |
| Check MQTT connection | `mosquitto_sub -t zigbee2mqtt/bridge/state -C 1` (expect `{"state":"online"}`) |
| View frontend | `http://<host>:8080` (requires `frontend.enabled: true` in config) |
| Health via MQTT | `mosquitto_sub -t zigbee2mqtt/bridge/health -C 1` |

## Expected State
- Coordinator connected and recognized (visible in `bridge/info`)
- `bridge/state` publishes `{"state": "online"}`
- All paired devices publish state updates to `zigbee2mqtt/<friendly_name>`
- `permit_join` is `false` during normal operation — only `true` briefly when pairing
- MQTT broker reachable and authenticated

## Health Checks
1. `systemctl is-active zigbee2mqtt` → `active`
2. `mosquitto_sub -t zigbee2mqtt/bridge/state -C 1` → `{"state":"online"}`
3. `mosquitto_sub -t zigbee2mqtt/bridge/devices -C 1 | python3 -m json.tool` → non-empty device list

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `Error: Failed to find serial port` or coordinator not found | Wrong serial port path or device not connected | `ls /dev/ttyUSB* /dev/ttyACM*`; use `by-id` path; check USB cable |
| `Error: Failed to start coordinator` | Wrong `adapter` type in config or corrupt coordinator firmware | Verify `serial.adapter` matches hardware (e.g. `zstack`, `ezsp`, `deconz`); reflash coordinator firmware |
| Device won't pair after permit_join | Device not in pairing mode, or too far from coordinator | Factory reset device; bring within 2m of coordinator; check Z2M logs for `Device joined` |
| `MQTT: not connected` / `ECONNREFUSED` | Mosquitto not running or wrong host/port/credentials | `systemctl status mosquitto`; verify `mqtt.server` and credentials in config |
| Device showing as `unavailable` | Device lost Zigbee connection (battery, distance, interference) | Check battery; move device closer; check for 2.4GHz channel conflicts |
| OTA update failing / stuck | Firmware file not found or device out of range during update | Ensure device is close to coordinator; check Z2M logs; some devices require multiple retries |
| EZSP/Silicon Labs error on startup | ConBee/Elelabs adapter needs different flow control | Set `serial.rtscts: true` in config for EZSP adapters |
| `EPERM: operation not permitted` on serial port | User not in `dialout` group | `sudo usermod -aG dialout $USER` then log out/in (or `newgrp dialout`) |
| Service starts then immediately exits | Config YAML syntax error | `python3 -c "import yaml; yaml.safe_load(open('configuration.yaml'))"` |

## Pain Points
- **Serial path changes after reboot**: `/dev/ttyUSB0` is assigned dynamically. Use the stable path under `/dev/serial/by-id/usb-<vendor>-<product>-if00-port0` instead — it survives reboots and re-plugs.
- **Adapter type must match hardware**: `zstack` (CC2652/CC1352), `ezsp` (ConBee II, Elelabs), `deconz` (ConBee), `zigate` (ZiGate). Wrong type causes cryptic startup failures — check the supported adapters list before configuring.
- **Zigbee channel vs WiFi interference**: Zigbee channels 11–26 overlap with WiFi 2.4GHz. WiFi channel 1 = Zigbee 11–14, WiFi channel 6 = Zigbee 19–21, WiFi channel 11 = Zigbee 24–26. Use Zigbee channel 15, 20, or 25 to minimize overlap.
- **Frontend is not enabled by default**: The web UI requires `frontend.enabled: true` in `configuration.yaml`. Without it, port 8080 is not open and there is no web interface.
- **Docker USB pass-through**: Docker requires `--device /dev/ttyUSB0:/dev/ttyUSB0` (or `--device /dev/ttyACM0`). The container does NOT see host USB devices without this flag — by-id paths work here too.
- **Some devices need factory reset to pair**: Devices previously paired to another coordinator, or purchased with a prior pairing, will not join without a factory reset. The reset procedure varies by device — check the Z2M supported devices page.
- **`permit_join` left open is a security risk**: Any Zigbee device in range can join when `permit_join: true`. Set it to `false` in config after initial setup; use the MQTT API or frontend to open it briefly when needed.

## References
See `references/` for:
- `configuration.yaml.annotated` — every configuration directive explained with defaults and when to change
- `docs.md` — official documentation links
