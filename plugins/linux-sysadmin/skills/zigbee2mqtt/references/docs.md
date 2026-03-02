# Zigbee2MQTT — Reference Documentation

## Primary Documentation

- [Zigbee2MQTT Documentation](https://www.zigbee2mqtt.io/guide/getting-started/) — Installation, configuration, and usage guide
- [Configuration Reference](https://www.zigbee2mqtt.io/guide/configuration/) — Every `configuration.yaml` option with defaults
- [MQTT Topics Reference](https://www.zigbee2mqtt.io/guide/usage/mqtt_topics_and_messages.html) — All topics Z2M publishes and subscribes to, including bridge control API

## Hardware

- [Supported Adapters](https://www.zigbee2mqtt.io/guide/adapters/) — USB coordinators that work with Z2M, grouped by chip (CC2652, EZSP, ConBee, etc.), with recommended picks
- [Supported Devices](https://www.zigbee2mqtt.io/supported-devices/) — Searchable list of 3,000+ paired devices with feature flags and notes

## Integration

- [Home Assistant Integration](https://www.zigbee2mqtt.io/guide/usage/integrations/home_assistant.html) — MQTT discovery setup, entity naming, and HA-specific options
- [Node-RED Integration](https://www.zigbee2mqtt.io/guide/usage/integrations/node_red.html) — Using Z2M with Node-RED flows

## Device Management

- [OTA Updates Guide](https://www.zigbee2mqtt.io/guide/usage/ota_updates.html) — How to check for and apply firmware updates to paired devices
- [Device-specific notes](https://www.zigbee2mqtt.io/supported-devices/) — Each device page includes pairing instructions and known quirks

## Network Optimization

- [Zigbee Network](https://www.zigbee2mqtt.io/guide/installation/zigbee_network.html) — Channel selection, mesh topology, router vs end-device roles, range and interference
- [Coordinator Firmware](https://www.zigbee2mqtt.io/guide/adapters/flashing/flashing_via_cc2538-bsl.html) — How to flash or update coordinator firmware

## Troubleshooting

- [FAQ and Troubleshooting](https://www.zigbee2mqtt.io/guide/usage/troubleshooting.html) — Common errors and their resolutions
- [Debug Logging](https://www.zigbee2mqtt.io/guide/configuration/logging.html) — How to enable debug output for pairing and device issues

## Installation

- [Bare Metal Install (Linux)](https://www.zigbee2mqtt.io/guide/installation/01_linux.html) — systemd service setup, Node.js requirements
- [Docker Install](https://www.zigbee2mqtt.io/guide/installation/02_docker.html) — Docker run command and Compose example with USB pass-through
- [Home Assistant Add-on](https://www.zigbee2mqtt.io/guide/installation/03_ha_addon.html) — Running Z2M as a supervised HA add-on
