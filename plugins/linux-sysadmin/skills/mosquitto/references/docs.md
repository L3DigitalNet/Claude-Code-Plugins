# Mosquitto and MQTT Documentation

## Eclipse Mosquitto

- [mosquitto.org](https://mosquitto.org/) — project homepage, downloads, changelogs
- [mosquitto.conf(5) man page](https://mosquitto.org/man/mosquitto-conf-5.html) — every configuration directive with defaults
- [mosquitto_pub(1) man page](https://mosquitto.org/man/mosquitto_pub-1.html) — all publish client flags
- [mosquitto_sub(1) man page](https://mosquitto.org/man/mosquitto_sub-1.html) — all subscribe client flags, including `-C` (count), `-W` (wait), `-F` (format)
- [mosquitto_passwd(1) man page](https://mosquitto.org/man/mosquitto_passwd-1.html) — password file management
- [Mosquitto documentation index](https://mosquitto.org/documentation/) — TLS, bridges, authentication plugins, `$SYS` topic reference

## MQTT Specification

- [MQTT 3.1.1 specification (OASIS)](https://docs.oasis-open.org/mqtt/mqtt/v3.1.1/mqtt-v3.1.1.html) — the wire protocol most devices implement
- [MQTT 5.0 specification (OASIS)](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html) — adds shared subscriptions, user properties, reason codes, message expiry; Mosquitto 2.0+ supports it

## Topic Design

- [MQTT topic best practices (HiveMQ)](https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/) — hierarchy, naming conventions, avoiding leading slashes
- [MQTT wildcard syntax (HiveMQ)](https://www.hivemq.com/blog/mqtt-essentials-part-5-mqtt-topics-best-practices/#wildcards) — `+` single-level, `#` multi-level, `$SYS` special topics
- [MQTT QoS levels explained (HiveMQ)](https://www.hivemq.com/blog/mqtt-essentials-part-6-mqtt-quality-of-service-levels/) — QoS 0/1/2 tradeoffs with sequence diagrams

## Client Libraries

- [Eclipse Paho MQTT clients](https://www.eclipse.org/paho/) — official client libraries for Python, Java, JavaScript, C, C++, Go, and more
  - [Paho Python](https://pypi.org/project/paho-mqtt/) — `pip install paho-mqtt`; most common Python choice
  - [Paho JavaScript](https://www.npmjs.com/package/mqtt) — `npm install mqtt`; works in Node.js and browsers
- [MQTT.js](https://github.com/mqttjs/MQTT.js) — popular browser + Node.js client with WebSocket support

## GUI Tools

- [MQTT Explorer](https://mqtt-explorer.com/) — desktop GUI (Windows/macOS/Linux) for browsing all topics, inspecting retained messages, and publishing test payloads; indispensable for debugging
- [MQTTX](https://mqttx.app/) — cross-platform MQTT 5.0 client with scripting support and connection management
