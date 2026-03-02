# Z-Wave JS Common Patterns

---

## 1. Docker Setup (zwavejs2mqtt / zwave-js-ui with USB passthrough)

Find the stable device path first:

```bash
ls /dev/serial/by-id/
# Example output: usb-Silicon_Labs_Zooz_ZST39_800_Z-Wave_Stick_00_05-if00-port0
```

`docker-compose.yml`:

```yaml
version: "3.7"

services:
  zwavejs2mqtt:
    image: zwavejs/zwave-js-ui:latest
    container_name: zwavejs2mqtt
    restart: unless-stopped
    tty: true
    stop_signal: SIGINT
    environment:
      - SESSION_SECRET=changeme_use_a_long_random_string
      - ZWAVEJS_EXTERNAL_CONFIG=/usr/src/app/store/.config-db
      # Store logs in the volume so they persist across container restarts.
      - LOGFILENAME=/usr/src/app/store/zwavejs2mqtt.log
    devices:
      # Use by-id path — survives reboots and USB re-plugs.
      - /dev/serial/by-id/usb-Silicon_Labs_Zooz_ZST39_800_Z-Wave_Stick_00_05-if00-port0:/dev/ttyUSB0
    volumes:
      - ./store:/usr/src/app/store
    ports:
      - "8091:8091"  # Web UI and WebSocket
      - "3000:3000"  # Z-Wave JS server (used by Home Assistant direct integration)
    networks:
      - iot

networks:
  iot:
    external: true
```

```bash
docker compose up -d
docker logs -f zwavejs2mqtt
```

Initial configuration is done through the web UI at `http://<host>:8091`. Set:
- **Z-Wave > Serial port**: `/dev/ttyUSB0` (the mapped device inside the container)
- **MQTT > Host**: address of your Mosquitto broker

---

## 2. Include (Add) a New Z-Wave Device

Z-Wave inclusion requires the controller to enter include mode, then the device to be triggered into pairing mode. Both must happen within roughly 60 seconds.

**Via web UI (recommended):**
1. Open `http://<host>:8091` > Control Panel
2. Click **Manage nodes** > **Add node**
3. Select inclusion mode: **Secure (S2)** for modern devices, **Non-secure** as fallback
4. Follow the device's pairing instructions (typically triple-click or hold a button)
5. Wait for interview to complete — the node appears in the list

**Via MQTT (automation-friendly):**
```bash
# Start secure inclusion (60-second window)
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/startInclusion/set' \
  -m '{"args": [{"strategy": 1}]}'

# strategy: 0 = non-secure, 1 = S0/S2 security (SmartStart), 2 = S2 only

# Stop inclusion mode manually (also stops automatically after 60s)
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/stopInclusion/set' \
  -m '{"args": []}'
```

After inclusion, the controller runs a full device **interview** (queries all supported command classes). This can take 1–5 minutes for complex devices. Battery devices may not complete the interview until their next wake cycle.

---

## 3. Exclude (Remove) a Z-Wave Device

Exclusion removes the device from the Z-Wave network. The device itself is factory-reset in the process — it can then be added to any controller.

**Via web UI:**
1. Control Panel > **Manage nodes** > **Remove node**
2. Trigger exclusion mode on the device (typically triple-click)
3. Confirm the device disappears from the node list

**Via MQTT:**
```bash
# Start exclusion mode (60-second window)
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/startExclusion/set' \
  -m '{"args": []}'

# Stop exclusion mode
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/stopExclusion/set' \
  -m '{"args": []}'
```

If a device is physically inaccessible or broken, use the web UI to **Force Remove** by node ID (Control Panel > node > three-dot menu > Remove Failed Node).

---

## 4. Heal the Z-Wave Mesh Network

Healing rebuilds routing tables so the controller knows the most efficient path to each node. Run after adding or moving devices.

**Via web UI:**
Control Panel > **Heal Network** button (top of page), or Settings > Z-Wave > Heal Network.

**Via MQTT:**
```bash
# Begin heal (runs in background — no completion event on MQTT)
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/healNetwork/set' \
  -m '{"args": []}'
```

Notes:
- Healing is node-by-node and can take 20–45 minutes on a network with 20+ devices
- Mains-powered devices participate immediately; battery devices heal on next wake
- The network remains operational during healing but may be briefly sluggish
- You do not need to heal on every change — the mesh self-heals over time, but explicit healing speeds up recovery after topology changes

---

## 5. Backup and Restore Controller NVM

The Non-Volatile Memory (NVM) backup contains the controller's home ID, security keys, and routing tables. It is your disaster-recovery backup — without it, all paired devices must be excluded and re-included.

**Backup via web UI:**
Settings > Z-Wave > **Backup** > **Create NVM backup**
The file is saved to `store/backups/` with a timestamp.

**Backup via MQTT:**
```bash
# Trigger backup; file written to store/backups/ on the server
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/backupNVMRaw/set' \
  -m '{"args": []}'
```

**Restore via web UI:**
Settings > Z-Wave > Backup > **Restore NVM backup** > choose the `.bin` file.

**Important:**
- Backups are firmware-version-specific. Restoring to a different stick model or significantly different firmware may fail silently or produce a corrupted network state.
- After a restore, the controller needs to re-interview nodes whose routing paths changed. Run Heal Network after restoration.
- Schedule automated backups by volume-mounting `store/backups/` and copying files with cron.

---

## 6. MQTT Integration and Topic Structure

Z-Wave JS publishes device state and accepts commands over MQTT. All topics are under the `zwave/` prefix by default (configurable).

**State topics (published by zwavejs2mqtt):**
```
zwave/<node_name>/<commandClass>/<endpoint>/<property>
```

Examples:
```
zwave/living_room_switch/switch_binary/endpoint_0/currentValue   → true/false
zwave/bedroom_thermostat/thermostat_setpoint/endpoint_0/heating  → {"value": 21.5}
zwave/front_door_lock/door_lock/endpoint_0/currentMode           → "secured"
```

**Command topics (send to control a device):**
```
zwave/<node_name>/<commandClass>/<endpoint>/<property>/set
```

Example — turn on a switch:
```bash
mosquitto_pub -h localhost -t 'zwave/living_room_switch/switch_binary/endpoint_0/currentValue/set' \
  -m 'true'
```

**Bridge status and API topics:**
```
zwave/_CLIENTS/ZWAVE_GATEWAY-<name>/status         → online/offline
zwave/_CLIENTS/ZWAVE_GATEWAY-<name>/api/<method>/set  → invoke API method
```

**Node values topic (full snapshot):**
```bash
mosquitto_sub -h localhost -t 'zwave/#' -v
```

---

## 7. Firmware Update (OTA)

Z-Wave OTA updates require the device to support the Firmware Update command class (most devices manufactured after 2016 do).

**Via web UI:**
1. Control Panel > node row > **OTA update**
2. Upload the firmware file (.hex or .otz format, from the device manufacturer)
3. Monitor progress in the web UI — do not restart the service during an update

**Via MQTT:**
```bash
# Check if an OTA update is available (requires manufacturer's cloud OTA if no local file)
mosquitto_pub -h localhost -t 'zwave/_CLIENTS/ZWAVE_GATEWAY-Home/api/firmwareUpdateOTW/set' \
  -m '{"args": [<nodeId>]}'
```

Notes:
- Keep the device within reliable radio range of the controller during an update
- Battery-powered devices must be awake for the entire update — wake them manually and keep them awake by repeatedly triggering them if needed
- Some devices require the controller to be on the same firmware version track — check the manufacturer's notes

---

## 8. Home Assistant Integration via MQTT

zwavejs2mqtt exposes devices to Home Assistant through MQTT discovery. HA auto-discovers entities when discovery is enabled.

**Enable MQTT discovery in zwavejs2mqtt:**
Settings > Home Assistant > Enable MQTT discovery: **on**
Discovery prefix: `homeassistant` (must match HA's `mqtt.discovery_prefix`)

**Home Assistant `configuration.yaml` (if not using UI-based MQTT setup):**
```yaml
mqtt:
  broker: 192.168.1.10
  port: 1883
  username: ha_user
  password: !secret mqtt_password
  discovery: true
  discovery_prefix: homeassistant
```

After enabling, entities appear in HA under the **MQTT** integration. Device names follow the zwavejs2mqtt node names.

**Alternative: Z-Wave JS Server (direct, no MQTT):**
zwavejs2mqtt also exposes a Z-Wave JS server on port 3000 (WebSocket). The HA Z-Wave JS integration can connect directly to this without MQTT. This is the preferred method for new installations — it provides faster response and richer device support.

In HA: Settings > Integrations > Add > Z-Wave JS > enter `ws://zwavejs2mqtt-host:3000`.

---

## 9. Troubleshooting an Unresponsive Device

Work through these checks in order:

```bash
# 1. Check node status in web UI
# Control Panel > node > Status column (Alive / Dead / Asleep)

# 2. Ping the node from web UI
# node row > Ping — shows RTT or timeout

# 3. Check node statistics in web UI
# node row > Statistics — shows retry count, last route, RTT history
# High retries or long RTT indicates a mesh routing problem.

# 4. Force a re-interview to refresh capabilities
# node row > three-dot menu > Re-interview Node

# 5. Check neighbors (routing)
# node row > three-dot menu > Get Neighbors
# A node with no neighbors (or only the controller) has no mesh path — move it closer.

# 6. Heal just the individual node
# node row > three-dot menu > Heal Node

# 7. If node is Dead, try refreshing it
# node row > three-dot menu > Refresh Node Values

# 8. Check controller logs
docker logs zwavejs2mqtt 2>&1 | grep -i "node <id>"
# or
journalctl -u zwavejs2mqtt --since "10 minutes ago"
```

If a node remains Dead after all of the above: exclude it (Remove Failed Node), power-cycle it, and re-include.

---

## 10. Choosing and Configuring a Z-Wave USB Stick

**Recommended hardware (as of 2024):**
- **Zooz ZST39 800LR** — 800 series, Z-Wave Long Range support, USB
- **Aeotec Z-Stick 7 (ZWA010)** — 700 series, widely supported, USB
- **HUSBZB-1** — combo Zigbee + Z-Wave (700 series Z-Wave chip) via USB

**Avoid:**
- 300/500 series sticks (Aeotec Gen5, older Sigma Designs sticks) — missing Long Range, known firmware issues
- Raspberry Pi GPIO Z-Wave hats if running in Docker — serial passthrough is more complex

**Confirming the stick is recognized by the OS:**
```bash
# List USB serial devices with vendor/product info
ls -la /dev/serial/by-id/
lsusb | grep -i "silicon labs\|zooz\|aeotec"

# Check kernel messages when plugging in
dmesg | tail -20
```

**Firmware updates for the stick itself:**
Controller firmware can be updated through the zwavejs2mqtt web UI (Settings > Z-Wave > Controller actions > Update firmware) or via Silicon Labs' PC Controller tool. Back up NVM first.

**Z-Wave frequency configuration:**
The stick must be configured for the correct regional frequency. Most sticks ship pre-configured for the region of purchase. The frequency is visible in Settings > Z-Wave > Controller Info > Region. Changing the region requires a factory reset of the controller (all paired devices must be re-included).

| Region | Frequency |
|--------|-----------|
| US/Canada/Mexico | 908.4 MHz |
| Europe | 868.4 MHz |
| Australia/New Zealand | 919.8 MHz |
| Israel | 916 MHz |
| Russia | 869 MHz |
