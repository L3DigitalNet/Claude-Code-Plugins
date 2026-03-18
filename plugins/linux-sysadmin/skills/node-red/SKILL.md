---
name: node-red
description: >
  Node-RED flow automation runtime administration: service management, flow
  deployment, palette node installation, settings configuration, credentials,
  Docker volume setup, debugging flows, and backup/restore.
  MUST consult when installing, configuring, or troubleshooting Node-RED.
triggerPhrases:
  - "node-red"
  - "Node-RED"
  - "node red"
  - "flow automation"
  - "IoT automation"
  - "node-red MQTT"
  - "visual programming automation"
  - "flows.json"
  - "settings.js Node-RED"
  - "1880"
  - "node-red-admin"
globs:
  - "**/settings.js"
  - "**/flows.json"
  - "**/flows_*.json"
  - "**/.node-red/settings.js"
  - "**/node-red/**"
last_verified: "unverified"
---

## Identity
- **Unit**: `nodered.service` (systemd) or PM2 process (`pm2 list`) or Docker container
- **Port**: 1880/tcp (web UI and API)
- **Config**: `~/.node-red/settings.js` (native), `/data/settings.js` (Docker)
- **Flows**: `~/.node-red/flows.json` (native), `/data/flows.json` (Docker)
- **Logs**: `journalctl -u nodered` (systemd), `pm2 logs node-red` (PM2), `docker logs <container>` (Docker)
- **User**: typically `pi` (Raspberry Pi), `nodered` (dedicated service user), or the installing user
- **Install**: `npm install -g --unsafe-perm node-red` (native) or Docker image `nodered/node-red`

## Quick Start

```bash
# Native install
sudo apt install nodejs npm
sudo npm install -g --unsafe-perm node-red
node-red &                         # start in background
curl -s -o /dev/null -w "%{http_code}" http://localhost:1880/
# Docker
docker run -d -p 1880:1880 -v node_red_data:/data --name nodered nodered/node-red
```

## Key Operations

| Task | Command |
|------|---------|
| Start (systemd) | `sudo systemctl start nodered` |
| Stop (systemd) | `sudo systemctl stop nodered` |
| Start (PM2) | `pm2 start node-red` |
| Stop (PM2) | `pm2 stop node-red` |
| Start (Docker) | `docker start <container>` or `docker compose up -d` |
| Check logs (systemd) | `journalctl -u nodered -f` |
| Check logs (PM2) | `pm2 logs node-red --lines 50` |
| Check logs (Docker) | `docker logs -f <container>` |
| Access web UI | `http://<host>:1880` in browser |
| Deploy flows | Click Deploy button in the UI (top-right) |
| Install palette node (CLI) | `cd ~/.node-red && npm install node-red-contrib-<name>` then restart |
| Install palette node (UI) | Menu → Manage palette → Install tab |
| Export flows (UI) | Menu → Export → Download |
| Export flows (CLI) | `node-red-admin export --file flows-backup.json` (requires auth token if adminAuth set) |
| Import flows | Menu → Import → paste or upload JSON |
| Backup flows.json | `cp ~/.node-red/flows.json flows-$(date +%Y%m%d).json` |
| Restart after settings change | `sudo systemctl restart nodered` or `pm2 restart node-red` |
| Debug flow | Add a Debug node; output appears in the debug panel (right sidebar) |
| Manage credentials | Stored encrypted in `flows_cred.json`; key is `credentialSecret` in settings.js |
| List flows via CLI | `node-red-admin list` (prints deployed flow node count and types) |

## Expected Ports
- 1880/tcp — web UI, REST API, WebSocket (editor live updates)
- Verify: `ss -tlnp | grep 1880`
- Firewall (ufw): `sudo ufw allow 1880/tcp`
- Firewall (firewalld): `sudo firewall-cmd --permanent --add-port=1880/tcp && sudo firewall-cmd --reload`
- If behind a reverse proxy: bind Node-RED to localhost only — set `uiHost: "127.0.0.1"` in settings.js

## Health Checks
1. `systemctl is-active nodered` → `active` (or `pm2 list | grep node-red` → `online`)
2. `curl -s -o /dev/null -w "%{http_code}" http://localhost:1880/` → `200` (or `401` if adminAuth configured)
3. `ss -tlnp | grep :1880` → process listed

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Error: Cannot find module 'node-red-contrib-...'` | Node installed in wrong context | Install with `cd ~/.node-red && npm install <pkg>`, not global npm |
| Port 1880 not accessible | Firewall blocking or wrong bind address | `ss -tlnp \| grep 1880`; check `uiHost` in settings.js; open firewall port |
| Flows not persisting (Docker) | Volume not mounted or wrong path | Verify Docker volume maps to `/data`; `docker inspect <container>` to check mounts |
| UI accessible without login | adminAuth not configured | Add `adminAuth` block to settings.js with bcrypt-hashed credential |
| Node install fails | Incompatible Node.js version or network issue | Check `node --version` against node compatibility matrix; try `npm install --legacy-peer-deps` |
| `Permission denied` accessing GPIO | Process user lacks gpio group membership | `sudo usermod -aG gpio <user>`, then log out/in |
| Editor shows "Not deployed" banner | Flows changed in UI but not deployed | Click Deploy button — changes are not auto-saved |
| `flows_cred.json` decryption error | `credentialSecret` changed or missing | Set correct `credentialSecret` in settings.js; if lost, delete `flows_cred.json` and re-enter credentials in UI |
| Node-RED crashes on startup | Corrupt `flows.json` | Check logs for parse error; restore from backup; validate with `node -e "require('./flows.json')"` |

## Pain Points
- **UI is unauthenticated by default**: anyone who can reach port 1880 has full access. Set `adminAuth` in settings.js before exposing Node-RED to a network. The admin auth hash uses bcrypt — generate with `node-red-admin hash-pw`.
- **Custom nodes must be installed in Node-RED's own `node_modules`**: installing a package globally with `npm install -g` does not make it available to Node-RED. Always install from `~/.node-red/` (or `/data/` in Docker) using `npm install`.
- **`flows.json` is the entire flow logic**: deleting or corrupting it loses all flows. Back it up before every significant change. There is no built-in undo across restarts.
- **Docker volumes must mount `/data`, not individual files**: Node-RED stores settings, flows, credentials, and installed packages all under `/data`. Mounting only `flows.json` causes package installs and settings changes to be lost on container restart.
- **Node.js version compatibility**: palette nodes often declare peer dependency ranges. Upgrading Node.js (e.g. 18 → 20) can silently break installed nodes. Check the node's npm page before upgrading the runtime.

## See Also

- **mosquitto** — MQTT broker commonly used as Node-RED's messaging backbone for IoT flows
- **zigbee2mqtt** — Zigbee device bridge that publishes device state to MQTT for Node-RED consumption
- **zwave-js** — Z-Wave device controller that integrates with Node-RED via MQTT topics
- **gotify** — push notifications that Node-RED flows can trigger via REST API

## References
See `references/` for:
- `settings.js.annotated` — full settings.js with every key explained and annotated
- `docs.md` — official documentation links, API reference, and community resources
