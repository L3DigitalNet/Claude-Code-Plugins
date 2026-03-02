---
name: jellyfin
description: >
  Jellyfin media server administration: installation, Docker deployment,
  library management, hardware transcoding, user management, networking,
  and troubleshooting. Triggers on: jellyfin, Jellyfin, media server,
  media streaming, Plex alternative, jellyfin docker, media transcoding,
  jellyfin library, jellyfin hardware acceleration, jellyfin DLNA.
globs:
  - "**/system.xml"
  - "**/network.xml"
  - "**/encoding.xml"
---

## Identity

- **Unit (native)**: `jellyfin.service`
- **Config (native)**: `/etc/jellyfin/` (system.xml, network.xml, encoding.xml, logging.json)
- **Config (Docker)**: `/config` volume — same XML files, path is inside the container
- **Data dir**: `/var/lib/jellyfin/` (native) or `/config` volume (Docker) — holds metadata cache, DB, plugins
- **Logs**: `journalctl -u jellyfin` (native) or `docker logs jellyfin` (Docker), also `/var/log/jellyfin/`
- **Media dir**: read-only mount recommended; Jellyfin only needs read access to media files
- **Ports**: 8096/tcp (HTTP), 8920/tcp (HTTPS optional), 7359/udp (auto-discovery), 1900/udp (DLNA/uPnP)
- **User (native)**: `jellyfin` — media files must be readable by this user
- **Distro install**: `apt install jellyfin` / `dnf install jellyfin` (after adding Jellyfin repo)

## Key Operations

| Operation | Command |
|-----------|---------|
| Service status | `systemctl status jellyfin` |
| Start / stop / restart | `sudo systemctl start\|stop\|restart jellyfin` |
| Check logs (live) | `journalctl -u jellyfin -f` |
| Check logs (Docker) | `docker logs -f jellyfin` |
| Restart (also triggers rescan) | `sudo systemctl restart jellyfin` |
| Force library scan | UI: Dashboard → Libraries → select library → Scan Library |
| Force full metadata refresh | UI: Library → select item → Edit Metadata → Refresh |
| Check hardware transcoding | UI: Dashboard → Playback → Transcoding — verify hardware encoder shown |
| View active streams | UI: Dashboard → Active Devices — shows current sessions and transcoding state |
| Clear metadata cache | UI: Dashboard → Libraries → select library → Delete Metadata and Images |
| Rebuild library (full) | UI: Dashboard → Libraries → select library → Remove, re-add library path |
| Check network settings | UI: Dashboard → Networking — PublishedServerUrl, bind address, ports |
| Update plugins | UI: Dashboard → Plugins → select plugin → Update |
| Create user | UI: Dashboard → Users → Add User |
| Check FFmpeg path | UI: Dashboard → Playback → Transcoding → FFmpeg path field |
| Check media file permissions | `ls -la /path/to/media` — jellyfin user needs read (r) on files, execute (x) on dirs |
| Docker restart | `docker restart jellyfin` |

## Expected Ports

- **8096/tcp** — HTTP web UI and API (primary port)
- **8920/tcp** — HTTPS (optional; configure cert in Dashboard → Networking)
- **7359/udp** — Jellyfin client auto-discovery (LAN only)
- **1900/udp** — DLNA/uPnP discovery (requires multicast; blocked by most firewalls)
- Verify: `ss -tlnp | grep jellyfin` (native) or `docker port jellyfin`
- Firewall: `sudo ufw allow 8096/tcp` — add 8920, 7359, 1900 only if needed

## Health Checks

1. `systemctl is-active jellyfin` → `active` (native), or `docker inspect jellyfin --format '{{.State.Status}}'` → `running` (Docker)
2. `curl -s http://localhost:8096/health` → `{"Status":"Healthy"}`
3. `curl -s http://localhost:8096/System/Info/Public` → JSON with `ServerName`, `Version`, `Id`

## Common Failures

| Symptom | Likely cause | Check / Fix |
|---------|-------------|-------------|
| Transcoding fails, stream stops | FFmpeg path wrong or missing codec | UI: Dashboard → Playback → Transcoding — verify FFmpeg path; `jellyfin-ffmpeg` package vs system FFmpeg |
| "Permission denied" on media files | Media files not readable by `jellyfin` user | `ls -la /media` — add jellyfin to media group or `chmod o+r` on files; `id jellyfin` to check groups |
| Hardware transcoding not working | Device not passed through (Docker) | Add `--device /dev/dri:/dev/dri` to Docker run, or `devices:` in Compose; verify with `vainfo` / `nvidia-smi` |
| Metadata not scraped, poster missing | Internet blocked or wrong scraper selected | Check Jellyfin server has outbound HTTPS to `api.themoviedb.org`, `www.thetvdb.com`; verify library type (Movies vs Shows) |
| Subtitles not displaying | libass missing or wrong codec | `jellyfin-ffmpeg` includes libass; system FFmpeg may not — check transcoding logs |
| DLNA clients can't discover server | Firewall blocking multicast or wrong interface | Allow 1900/udp; `network_mode: host` in Docker (bridge mode blocks multicast); check Dashboard → DLNA |
| Container can't read media | Wrong volume mount path or permissions | Verify `docker inspect jellyfin` volumes; check host path exists; `:ro` flag is fine, `:z` needed on SELinux hosts |
| Web UI loads but library empty | Library path wrong or not scanned yet | UI: Dashboard → Libraries — verify path matches container-internal path, not host path |

## Pain Points

- **Hardware transcoding requires device passthrough in Docker**: `--device /dev/dri:/dev/dri` for Intel/AMD (VA-API); the NVIDIA Container Runtime (`--runtime=nvidia`) for NVIDIA. Without this, the device is invisible inside the container and Jellyfin falls back to software transcoding silently.
- **Media files need read permission for the jellyfin user**: Native installs run as the `jellyfin` system user. Add it to the group owning your media (e.g., `usermod -aG media jellyfin`) or ensure world-readable permissions. Docker deployments should set `PUID`/`PGID` to match the media owner.
- **Library folder structure determines metadata scraping**: Jellyfin's scrapers expect Movies in a flat or `Movie Name (Year)/` structure, and TV Shows as `Show Name/Season XX/`. The wrong structure causes metadata mismatches or no scraping at all. See the Jellyfin media organization docs before adding libraries.
- **Subtitles need libass**: The system FFmpeg package often omits libass. Use `jellyfin-ffmpeg` (from the Jellyfin repo) to ensure subtitle rendering works; set its path explicitly in Dashboard → Playback → Transcoding.
- **Config and media must be separate volumes**: Do not combine config and media in one mount. Config is read/write (DB, metadata cache, plugins); media should be read-only. Mixing them makes backups, permissions, and upgrades harder.
- **Transcoding is CPU-intensive without hardware acceleration**: 4K HEVC software transcoding can saturate a modern CPU at 1–2 simultaneous streams. Enable hardware acceleration (Intel Quick Sync, AMD VA-API, NVIDIA NVENC) before putting the server into production use.

## References

See `references/` for:
- `docker-compose.yml.annotated` — complete Docker Compose with hardware transcoding options explained
- `docs.md` — official documentation and community links
