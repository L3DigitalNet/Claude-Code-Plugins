---
name: mosquitto
description: >
  Eclipse Mosquitto MQTT broker administration: installation, configuration,
  authentication, TLS setup, ACLs, bridging, WebSocket listeners, and
  troubleshooting. Triggers on: mosquitto, MQTT, MQTT broker, Mosquitto,
  mqtt topic, IoT messaging, mqtt subscribe, mosquitto_pub.
globs:
  - "**/mosquitto.conf"
  - "**/mosquitto/**/*.conf"
  - "**/conf.d/**"
---

## Identity
- **Unit**: `mosquitto.service`
- **Daemon**: `mosquitto`
- **Config**: `/etc/mosquitto/mosquitto.conf`, `/etc/mosquitto/conf.d/`
- **Logs**: `journalctl -u mosquitto`, `/var/log/mosquitto/mosquitto.log`
- **User**: `mosquitto`
- **Distro install**: `apt install mosquitto mosquitto-clients` / `dnf install mosquitto`

## Key Operations

| Operation | Command |
|-----------|---------|
| Service status | `systemctl status mosquitto` |
| Test publish | `mosquitto_pub -h localhost -t test/topic -m "hello"` |
| Test subscribe | `mosquitto_sub -h localhost -t test/topic -v` |
| Subscribe all topics (wildcard) | `mosquitto_sub -h localhost -t '#' -v` |
| Subscribe single-level wildcard | `mosquitto_sub -h localhost -t 'sensors/+/temperature' -v` |
| Show connected clients | `mosquitto_sub -h localhost -t '$SYS/broker/clients/connected' -C 1` |
| Check connections count | `mosquitto_sub -h localhost -t '$SYS/broker/clients/total' -C 1` |
| Check messages per second | `mosquitto_sub -h localhost -t '$SYS/broker/messages/sent' -C 1` |
| Test with authentication | `mosquitto_pub -h localhost -t test/topic -m "hello" -u myuser -P mypassword` |
| Test TLS | `mosquitto_pub -h broker.example.com -p 8883 --cafile /etc/mosquitto/ca.crt -t test/topic -m "hello"` |
| Test TLS with client cert | `mosquitto_pub -h broker.example.com -p 8883 --cafile /etc/mosquitto/ca.crt --cert client.crt --key client.key -t test/topic -m "hello"` |
| Bridge to another broker | See `references/mosquitto.conf.annotated` bridge section |
| Check log for errors | `journalctl -u mosquitto --since "1 hour ago" \| grep -i error` |
| Reload config | `sudo systemctl reload mosquitto` (re-reads config without dropping connections) |
| Create password file | `mosquitto_passwd -c /etc/mosquitto/passwd myuser` (add user: `-b` flag) |
| Add user to password file | `mosquitto_passwd -b /etc/mosquitto/passwd anotheruser secretpass` |
| Generate self-signed CA + cert | See TLS section in `references/mosquitto.conf.annotated` |

## Expected Ports
- **1883/tcp** — MQTT plaintext. Verify: `ss -tlnp | grep mosquitto`
- **8883/tcp** — MQTT over TLS (MQTTS). Firewall: `sudo ufw allow 8883/tcp`
- **9001/tcp** — MQTT over WebSocket. Firewall: `sudo ufw allow 9001/tcp`
- Default bind: `0.0.0.0` (all interfaces). Restrict with `listener 1883 127.0.0.1` for local-only.

## Health Checks
1. `systemctl is-active mosquitto` — expect `active`
2. Loopback publish/subscribe round-trip:
   ```bash
   mosquitto_sub -h localhost -t 'health/check' -C 1 &
   sleep 0.2
   mosquitto_pub -h localhost -t 'health/check' -m 'ok'
   ```
   Expect output: `health/check ok`
3. `journalctl -u mosquitto -n 50 | grep -i 'error\|warning'` — should be clean

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `Connection refused` on port 1883 | Firewall blocking or broker not listening on external interface | `ss -tlnp \| grep 1883` — if bound to `127.0.0.1`, add `listener 1883 0.0.0.0` in config |
| `Not authorized` | `allow_anonymous false` set but no credentials supplied, or ACL denying topic | Check `password_file` and `acl_file` paths; test with `-u`/`-P` flags |
| TLS handshake failure | `cafile`/`certfile`/`keyfile` path wrong, or cert CN mismatch | Verify paths with `ls -l`; check cert CN: `openssl x509 -noout -subject -in cert.pem` |
| `No matching subscribers` | Topic filter mismatch (wildcard misuse) | MQTT `+` = single level, `#` = multi-level and must be last segment; test with `mosquitto_sub -t '#' -v` |
| Retained messages cause confusion | Old retained payloads replayed to new subscribers | Clear with empty retained publish: `mosquitto_pub -t topic -m '' -r` |
| WebSocket clients can't connect | `protocol websockets` listener not configured, or proxy stripping `Upgrade` header | Add `listener 9001` + `protocol websockets`; if behind nginx, add `proxy_set_header Upgrade $http_upgrade` |
| `MQTT protocol version mismatch` | Client using MQTTv5 against broker configured for v3 only | Set `listener ... protocol mqtt` and check client library version |
| Broker exits immediately on start | Config error — mosquitto is strict | `journalctl -u mosquitto -n 20`; run `mosquitto -c /etc/mosquitto/mosquitto.conf` in foreground to see parse errors |

## Pain Points
- **No encryption by default**: MQTT plaintext transmits credentials and payloads in the clear. Use TLS (port 8883) or route through a VPN for anything sensitive.
- **Anonymous access on by default in older versions**: Mosquitto < 2.0 defaults to `allow_anonymous true`. Version 2.0+ defaults to no listeners at all until you explicitly configure them. Always set `allow_anonymous false` and configure a `password_file` in production.
- **MQTT wildcard syntax**: `+` matches exactly one topic level (`sensors/+/temp` matches `sensors/room1/temp` but not `sensors/room1/floor2/temp`). `#` matches any number of remaining levels and must appear only at the end. A common mistake is using `*` (which is not MQTT syntax).
- **Retained messages persist across broker restarts**: Any message published with `-r` (retain flag) is stored to disk if `persistence true` is set and replayed to every new subscriber. Stale retained state is a frequent source of confusion during development — clear explicitly with an empty retained publish.
- **QoS levels trade reliability for performance**: QoS 0 = fire-and-forget (fastest, no guarantee), QoS 1 = at least once (duplicate possible), QoS 2 = exactly once (slowest, safe). Most IoT sensors use QoS 0 or 1; only use QoS 2 where duplicates are harmful.
- **`$SYS` topic tree**: Mosquitto publishes broker stats under `$SYS/broker/...`. Subscribing to `#` does NOT include `$SYS` topics — subscribe explicitly if you need them.
- **ACL file changes require reload, not restart**: `systemctl reload mosquitto` re-reads the ACL and password files without dropping existing connections.

## References
See `references/` for:
- `mosquitto.conf.annotated` — complete config with every directive explained
- `docs.md` — official documentation and MQTT specification links
