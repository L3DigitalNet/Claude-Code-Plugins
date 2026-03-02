---
name: immich
description: >
  Immich self-hosted photo and video management — multi-container Docker stack
  administration, backup strategy, external library sync, machine learning face
  detection, job queue management, and troubleshooting. Triggers on: immich,
  Immich, photo management, Google Photos alternative, self-hosted photos,
  photo backup server, immich-server, immich-microservices, immich-machine-learning.
globs:
  - "**/immich/**/docker-compose.yml"
  - "**/immich/**/docker-compose.yaml"
  - "**/immich/**/.env"
  - "**/immich/**/compose.yml"
  - "**/immich/**/compose.yaml"
---

## Identity
- **Stack**: multi-container Docker Compose application — 5 services minimum
  - `immich-server` — API, web UI, upload handling (port 2283)
  - `immich-microservices` — background job worker (thumbnail generation, metadata extraction, video transcoding)
  - `immich-machine-learning` — face detection, CLIP semantic search (optional but common)
  - `database` — PostgreSQL with `pgvecto-rs` extension (NOT standard postgres — the vector extension is required)
  - `redis` — job queue broker between server and microservices
- **Config**: `.env` file in the same directory as `docker-compose.yml`
- **Port**: 2283/tcp (HTTP — reverse-proxy this; Immich has no built-in TLS)
- **Upload dir**: controlled by `UPLOAD_LOCATION` in `.env` — must be a persistent volume mount
- **Project page**: https://immich.app

## Key Operations

| Goal | Command |
|------|---------|
| Check all container status | `docker compose ps` |
| View logs (all containers) | `docker compose logs -f` |
| View logs for specific service | `docker compose logs -f immich-server` |
| Restart one service | `docker compose restart immich-microservices` |
| Full stack restart | `docker compose down && docker compose up -d` |
| Update to latest (or pinned) version | `docker compose pull && docker compose up -d` |
| Open shell in server container | `docker compose exec immich-server bash` |
| Check job queue status | Open web UI → Administration → Jobs |
| Run face detection on all photos | Web UI → Administration → Jobs → Face Detection → Run all |
| Force thumbnail regeneration | Web UI → Administration → Jobs → Generate Thumbnails → Run all |
| Sync external library | Web UI → Administration → External Libraries → Scan All |
| Create user via CLI | `docker compose exec immich-server immich-admin user create` |
| Create user via API | `curl -X POST http://localhost:2283/api/user -H 'x-api-key: <key>' -d '{"email":"...","name":"...","password":"..."}'` |
| Import external library (one-off) | `docker compose exec immich-server immich-admin library scan <library-id>` |
| Check storage usage | Web UI → Administration → Server Stats, or `du -sh $UPLOAD_LOCATION` |
| PostgreSQL dump (backup) | `docker compose exec database pg_dumpall -U postgres > immich-db-$(date +%F).sql` |

## Expected State
- All 5 containers show `Up` (or `Up (healthy)` if healthchecks are configured) in `docker compose ps`
- No containers in `Restarting` or `Exit` state
- Job queue shows no permanently failed jobs (occasional transient failures are normal)
- `immich-machine-learning` may be absent if ML is disabled via `IMMICH_MACHINE_LEARNING_ENABLED=false`

## Health Checks
1. `docker compose ps` — all services show `Up`; nothing in `Restarting` or `Exit`
2. `curl -s http://localhost:2283/api/server-info/ping` — returns `{"res":"pong"}`
3. Web UI → Administration → Jobs — no queue items stuck in a failed/error state indefinitely

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| "Internal Server Error" on login or API calls | PostgreSQL migration failure on upgrade | `docker compose logs database` and `docker compose logs immich-server` — look for migration errors; often requires manual intervention or rollback |
| `immich-machine-learning` restarting in loop | Out of memory (OOM kill) | `docker stats` or `dmesg | grep -i oom`; increase container memory limit or disable ML with `MACHINE_LEARNING_ENABLED=false` |
| Face detection not running / no faces recognized | ML container down or never started | `docker compose ps immich-machine-learning`; check `MACHINE_LEARNING_URL` in `.env` points to correct container name |
| Photos not appearing after upload | `UPLOAD_LOCATION` path misconfigured or volume not mounted | `docker compose exec immich-server ls /usr/src/app/upload`; confirm the volume mount matches `UPLOAD_LOCATION` in `.env` |
| Upgrade broke the stack | Missing or failed database migration | Always read the release notes before upgrading — check https://github.com/immich-app/immich/releases; rolling back requires a database restore |
| Duplicate detection not working | Thumbhash or encode-clip jobs not run | Web UI → Administration → Jobs → Encode CLIP → Run all; also run Detect Faces and Generate Thumbnails |
| Video transcoding fails | FFmpeg error or unsupported codec | `docker compose logs immich-microservices` — look for FFmpeg errors; hardware transcoding misconfiguration is a common cause |
| External library photos not visible | Library scan not triggered or path not mounted | Confirm external library path is volume-mounted in `docker-compose.yml`; trigger a manual scan in the UI |
| Redis connection errors in server logs | Redis container down or wrong hostname | `docker compose ps redis`; confirm `REDIS_HOSTNAME` in `.env` matches the service name in `docker-compose.yml` |

## Pain Points
- **Immich updates frequently and can be breaking.** The project moves fast — breaking changes appear in minor versions. Always read the GitHub release notes before running `docker compose pull`. Never update without a current database backup.
- **PostgreSQL is not standard postgres.** Immich requires the `pgvecto-rs` extension for vector similarity search. Use the `ghcr.io/immich-app/postgres` image (or the official Immich-provided compose file) — a plain `postgres:16` image will fail to start with migration errors.
- **Machine learning is optional but memory-hungry.** The ML container runs CLIP and facial recognition models that can consume 2–4 GB RAM. On memory-constrained hosts, disable it with `MACHINE_LEARNING_ENABLED=false` in `.env`; the core photo library remains fully functional without it.
- **The upload directory must have sufficient space.** Immich stores originals, thumbnails, video transcodes, and encoded clips all under `UPLOAD_LOCATION`. Plan for at least 2–3× your raw photo storage. Monitor with `df -h` or integrate with a monitoring stack.
- **Backup strategy must cover two things: the PostgreSQL database AND the upload directory.** Neither alone is sufficient. The database holds metadata, albums, faces, and user accounts; the upload directory holds the actual media. A restored database pointing at missing files — or media files with no metadata — leaves the library unusable.
- **External library scanning is a separate job.** Photos in an external library path are not automatically indexed. You must configure the library in the UI, mount the path as a Docker volume, and trigger a scan manually or via a cron-based `docker compose exec` call.

## References
See `references/` for:
- `docker-compose-env.annotated` — annotated `.env` and `docker-compose.yml` structure with hardware transcoding, external library, and backup strategy notes
- `docs.md` — official documentation and community links
