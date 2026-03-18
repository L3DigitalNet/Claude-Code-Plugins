---
name: zwave-js
description: >
  Z-Wave JS device control and zwavejs2mqtt/zwave-js-ui administration: USB
  controller setup, device inclusion and exclusion, mesh healing, NVM backup and
  restore, OTA firmware updates, MQTT integration, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting Z-Wave JS.
triggerPhrases:
  - "Z-Wave"
  - "zwave"
  - "zwave-js"
  - "Z-Wave JS"
  - "zwave stick"
  - "Z-Wave devices"
  - "zwavejs2mqtt"
  - "zwave-js-ui"
  - "Z-Wave controller"
  - "Z-Wave mesh"
  - "Z-Wave inclusion"
  - "Z-Wave exclusion"
  - "Z-Wave USB"
  - "700 series"
  - "800 series"
  - "Aeotec"
  - "Z-Stick"
globs: []
last_verified: "unverified"
---

## Identity

- **Service name**: `zwavejs2mqtt` (systemd) or Docker container `zwavejs2mqtt` / `zwave-js-ui`
- **Project name**: zwavejs2mqtt and zwave-js-ui are the same project; zwave-js-ui is the current name
- **Logs**: `journalctl -u zwavejs2mqtt -f` (systemd) or `docker logs -f zwavejs2mqtt`
- **Web UI**: `http://<host>:8091` (built-in; always enabled unlike Zigbee2MQTT)
- **Config**: `/opt/zwavejs2mqtt/store/` (bare metal) or Docker volume mapped to `/usr/src/app/store/`
- **Key config files**: `store/settings.json` (main config), `store/zwcfg.xml` (Z-Wave network cache)
- **Serial device**: `/dev/ttyUSB0`, `/dev/ttyACM0` — use `/dev/serial/by-id/...` for stability
- **Depends on**: Mosquitto (or any MQTT broker) — must be running before zwavejs2mqtt starts
- **Install**: `docker run zwavejs/zwave-js-ui` or bare-metal Node.js service
- **User**: must be in `dialout` group to access the serial device

## Quick Start

```bash
# Docker (recommended)
docker compose pull
docker compose up -d
curl -s -o /dev/null -w "%{http_code}" http://localhost:8091/
# Verify Z-Wave controller is detected in the web UI at http://<host>:8091
# Check MQTT connection
mosquitto_sub -t 'zwave/#' -C 5
```

## Key Operations

| Task | Command |
|------|---------|
| Check service status | `systemctl status zwavejs2mqtt` or `docker ps` |
| Follow logs live | `journalctl -u zwavejs2mqtt -f` or `docker logs -f zwavejs2mqtt` |
| Restart service | `sudo systemctl restart zwavejs2mqtt` or `docker restart zwavejs2mqtt` |
| Access web UI | `http://<host>:8091` — Control Panel tab |
| Check controller info | Web UI: Settings > Z-Wave > Controller Info, or MQTT topic `zwave/_CLIENTS/ZWAVE_GATEWAY-<name>/api/getControllerCapabilities/get` |
| List all nodes | Web UI: Control Panel node list, or `mosquitto_sub -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-<name>/api/getNodes/get' -C 1` |
| Include (add) a device | Web UI: Control Panel > Manage nodes > Add node, then trigger pairing mode on device |
| Exclude (remove) a device | Web UI: Control Panel > Manage nodes > Remove node, then trigger exclusion mode on device |
| Interview node (re-interview) | Web UI: node row > three-dot menu > Re-interview Node |
| Heal network | Web UI: Control Panel > Heal Network, or Settings > Z-Wave > Heal Network |
| Check node statistics | Web UI: node row > Statistics (shows RTT, retries, route history) |
| Test node reachability | Web UI: node row > Ping |
| OTA update firmware | Web UI: node row > OTA update (device must support OTA) |
| Backup NVM | Web UI: Settings > Z-Wave > Backup > Create NVM backup |
| Restore NVM | Web UI: Settings > Z-Wave > Backup > Restore NVM backup |
| Check MQTT connection | Web UI: top-right status indicators; or `mosquitto_sub -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-<name>/status' -C 1` |

## Expected State

- Controller connected and detected (visible in Settings > Z-Wave; firmware version shown)
- All mains-powered nodes: status `Alive`, last activity recent
- Battery nodes: status `Asleep` or `Alive`; they only wake on schedule (every few hours) or on interaction
- MQTT publishing: `zwave/<node_name>/` topics updating on device events
- MQTT broker connected (green indicator in web UI header)

## Health Checks

1. `systemctl is-active zwavejs2mqtt` → `active` (or `docker ps | grep zwavejs2mqtt` showing `Up`)
2. Open `http://<host>:8091` — web UI loads and shows the node list
3. `mosquitto_sub -t 'zwave/#' -C 5` → Z-Wave event messages arriving within seconds of device activity

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Failed to open serial port` | Wrong device path or permission denied | `ls /dev/serial/by-id/` to find the correct path; `groups $USER` to confirm `dialout` membership; `sudo usermod -aG dialout $USER` then log out/in |
| Controller not recognized at startup | Device path changed (e.g., `/dev/ttyUSB0` reassigned) | Use `/dev/serial/by-id/usb-<vendor>-if00-port0` instead — survives reboots and re-plugs |
| Battery device not responding | Device is asleep; commands are queued | Commands are sent automatically when the device next wakes; check wake interval in node settings or trigger a manual wake per device docs |
| Inclusion fails / device not found | Device too far from controller, or not in pairing mode | Bring device within 2-3m; factory-reset the device; check Z-Wave frequency match (US/EU use different bands) |
| Mesh degraded / high latency after adding devices | Network routes need recalculation | Run Heal Network from the web UI after adding or moving devices; healing is slow — allow 20-30 min for large networks |
| MQTT not connected | Mosquitto not running or credentials wrong | `systemctl status mosquitto`; verify `mqtt.host`, `mqtt.port`, and credentials in `store/settings.json` |
| Web UI unreachable on port 8091 | Service not running or port conflict | `ss -tlnp \| grep 8091`; check service logs for startup errors |
| NVM restore fails | Firmware mismatch between backup source and current stick | NVM format is firmware-version-specific; restore to the same stick model and firmware version |

## Pain Points

- **Z-Wave is 900MHz, not 2.4GHz**: Unlike Zigbee, Z-Wave does not share spectrum with WiFi. No channel conflicts to worry about. Range and the device ecosystem vary significantly by region because US (Z-Wave Plus uses 908.4MHz) and EU (868.4MHz) are different frequencies — a US stick will not communicate with EU devices.
- **700/800 series stick strongly recommended**: Older 300/500 series sticks lack Long Range support and have known firmware issues. Aeotec Z-Stick 7 (700 series) and Zooz ZST39 (800 series) are well-supported. Avoid Silicon Labs WSTK development boards for production use.
- **Always use `/dev/serial/by-id/` in Docker**: `/dev/ttyUSB0` is dynamically assigned and changes if another USB device is added. The by-id path is stable. Pass it with `--device /dev/serial/by-id/usb-<vendor>-if00-port0:/dev/ttyUSB0`.
- **Battery devices are asleep most of the time**: Commands sent to battery devices are queued and delivered on the device's next wake interval (typically every 4-24 hours). Instant commands (e.g., setting a configuration parameter) appear to hang but are actually pending. Force a wake by manually activating the device.
- **Z-Wave mesh takes time to stabilize**: After adding several devices, routing is suboptimal until the controller has learned neighbor relationships. Heal the network after adding or moving devices, and wait 24-48 hours for routes to fully settle before troubleshooting sluggish devices.
- **zwavejs2mqtt == zwave-js-ui**: The project was renamed from zwavejs2mqtt to zwave-js-ui in 2022. Docker images, documentation, and community posts use both names interchangeably. The underlying Z-Wave JS library is a separate project (`zwave-js`).
- **NVM backups are stick-specific**: The Non-Volatile Memory backup contains the controller's home ID and routing tables. It is not portable across different stick models or significantly different firmware versions. Back up before firmware updates.

## See Also

- **zigbee2mqtt** — Zigbee device bridge, the 2.4GHz counterpart to Z-Wave for smart home automation
- **mosquitto** — MQTT broker required by zwave-js-ui for device state and command transport
- **node-red** — flow automation tool for building rules and dashboards from Z-Wave device MQTT data

## References

See `references/` for:
- `common-patterns.md` — Docker setup, inclusion/exclusion, mesh healing, NVM backup, MQTT integration, OTA updates, HA integration, and troubleshooting patterns
- `docs.md` — official documentation links
