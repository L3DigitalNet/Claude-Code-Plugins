---
name: minio
description: >
  MinIO S3-compatible object storage administration: mc CLI operations, bucket
  management, user and policy configuration, erasure coding, server pools,
  bucket replication, lifecycle rules (expiration and transition), versioning,
  TLS setup, Docker and bare-metal deployment, and monitoring.
  MUST consult when installing, configuring, or troubleshooting minio.
triggerPhrases:
  - "minio"
  - "MinIO"
  - "mc alias"
  - "mc admin"
  - "object storage"
  - "S3 compatible"
  - "minio server"
  - "minio console"
  - "minio bucket"
  - "mc ilm"
  - "mc replicate"
  - "erasure coding minio"
  - "MINIO_ROOT_USER"
globs:
  - "**/minio.conf"
  - "**/minio/**/*.conf"
  - "**/minio/**/*.env"
  - "**/.minio/**"
last_verified: "2026-03"
---

## Identity
- **Binary**: `minio` (server), `mc` (client CLI)
- **License**: GNU AGPLv3 -- all usage requires compliance with AGPL obligations including release of modified source code
- **Config**: environment variables (`MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD`, `MINIO_VOLUMES`); optional `/etc/default/minio` for systemd
- **Data dir**: path(s) passed to `minio server` (e.g., `/data/minio`)
- **TLS certs**: `~/.minio/certs/` (default) or `--certs-dir` flag; expects `public.crt` and `private.key`
- **Logs**: `journalctl -u minio`, `mc admin logs ALIAS`, or stdout in Docker
- **Install (Debian)**: `curl -O https://dl.min.io/server/minio/release/linux-amd64/minio.deb && sudo dpkg -i minio.deb`
- **Install (binary)**: `curl -O https://dl.min.io/server/minio/release/linux-amd64/minio && chmod +x minio && sudo mv minio /usr/local/bin/`
- **Install mc**: `curl -O https://dl.min.io/client/mc/release/linux-amd64/mc && chmod +x mc && sudo mv mc /usr/local/bin/`

## Quick Start

```bash
# Single-node, single-drive (development only).
export MINIO_ROOT_USER=minioadmin
export MINIO_ROOT_PASSWORD=minioadmin
mkdir -p /data/minio
minio server /data/minio --console-address ":9001"

# Configure mc to talk to this instance.
mc alias set local http://127.0.0.1:9000 minioadmin minioadmin
mc admin info local                       # verify deployment health
mc mb local/my-bucket                     # create a bucket
mc cp myfile.txt local/my-bucket/         # upload a file
```

## Key Operations

| Task | Command |
|------|---------|
| Set up mc alias | `mc alias set ALIAS http://HOST:9000 ACCESS_KEY SECRET_KEY` |
| Server info | `mc admin info ALIAS` |
| Create bucket | `mc mb ALIAS/bucket` |
| Remove bucket | `mc rb ALIAS/bucket --force` |
| List buckets | `mc ls ALIAS` |
| List objects | `mc ls ALIAS/bucket/path/` |
| Upload file | `mc cp file.txt ALIAS/bucket/` |
| Download file | `mc cp ALIAS/bucket/file.txt ./` |
| Recursive copy | `mc cp --recursive ./dir/ ALIAS/bucket/dir/` |
| Mirror (sync) | `mc mirror ./local-dir ALIAS/bucket/` |
| Remove object | `mc rm ALIAS/bucket/file.txt` |
| Recursive remove | `mc rm --recursive --force ALIAS/bucket/prefix/` |
| Disk usage | `mc du ALIAS/bucket` |
| Object metadata | `mc stat ALIAS/bucket/file.txt` |
| Create user | `mc admin user add ALIAS newuser newpassword` |
| List users | `mc admin user list ALIAS` |
| Disable user | `mc admin user disable ALIAS newuser` |
| Attach policy to user | `mc admin policy attach ALIAS readwrite --user newuser` |
| List policies | `mc admin policy list ALIAS` |
| Create custom policy | `mc admin policy create ALIAS mypolicy policy.json` |
| Enable versioning | `mc version enable ALIAS/bucket` |
| Check versioning | `mc version info ALIAS/bucket` |
| Add lifecycle expiration | `mc ilm rule add ALIAS/bucket --expire-days 90` |
| Add lifecycle transition | `mc ilm rule add ALIAS/bucket --transition-days 30 --storage-class TIER-1` |
| List lifecycle rules | `mc ilm rule ls ALIAS/bucket` |
| Add replication rule | `mc replicate add ALIAS/bucket --remote-bucket https://USER:PASS@REMOTE:9000/bucket --replicate "delete,delete-marker,existing-objects"` |
| Site replication setup | `mc admin replicate add site1 site2 site3` |
| Server restart | `mc admin service restart ALIAS` |
| Server logs (live) | `mc admin logs ALIAS` |
| Trace API calls | `mc admin trace ALIAS` |
| Heal objects | `mc admin heal ALIAS/bucket --recursive` |
| Bucket encryption | `mc encrypt set sse-s3 ALIAS/bucket` |
| Presigned download URL | `mc share download ALIAS/bucket/file.txt` |
| Prometheus metrics | `mc admin prometheus generate ALIAS` |

## Expected Ports
- **9000/tcp** -- S3 API (default)
- **9001/tcp** -- MinIO Console web UI (set with `--console-address ":9001"`)
- Verify: `ss -tlnp | grep minio`
- Firewall (ufw): `sudo ufw allow 9000/tcp && sudo ufw allow 9001/tcp`

## Health Checks

1. `systemctl is-active minio` -> `active` (when installed via DEB/RPM with systemd)
2. `mc admin info ALIAS` -> shows server status, uptime, and drive health
3. `mc ready ALIAS` -> checks read/write quorum availability
4. `mc ping ALIAS` -> basic liveness check
5. `curl -s http://localhost:9000/minio/health/live` -> HTTP 200 when server is live
6. `curl -s http://localhost:9000/minio/health/cluster` -> HTTP 200 when cluster has write quorum

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Access Denied` on all operations | Wrong access key / secret key, or policy not attached | Verify `mc alias set` credentials match `MINIO_ROOT_USER`/`MINIO_ROOT_PASSWORD`; check `mc admin policy entities ALIAS` |
| `Unable to initialize backend` on startup | Disk path does not exist or wrong permissions | Create the data directory; ensure the `minio` user owns it: `chown minio:minio /data/minio` |
| `Write quorum not met` | Not enough drives available in the erasure set | Check `mc admin info ALIAS` for offline drives; replace failed drives and let healing complete |
| `Read quorum not met` | Too many drives offline to reconstruct objects | Bring drives back online; if drives are permanently lost beyond parity tolerance, data is unrecoverable |
| Console not accessible on port 9001 | `--console-address` not set or port conflict | Add `--console-address ":9001"` to the server command; check `ss -tlnp \| grep 9001` |
| TLS handshake failure | Missing or misnamed certificate files | Place `public.crt` and `private.key` in `~/.minio/certs/`; verify SAN covers the hostname |
| `Bucket replication not syncing` | Versioning not enabled on source or target | `mc version enable ALIAS/src-bucket` and `mc version enable REMOTE/dst-bucket` |
| `mc: command not found` | mc binary not in PATH | Move binary to `/usr/local/bin/` or add its location to PATH |
| Objects not expiring per lifecycle rules | Rule status is `Disabled` or prefix filter doesn't match | `mc ilm rule ls ALIAS/bucket` to check; ensure rule status is `Enabled` |
| Server OOM on startup with many drives | Insufficient memory for erasure coding metadata | MinIO recommends 32 GB+ RAM for production; 128 MB per drive as a minimum estimate |

## Pain Points
- **AGPL license requires source disclosure**: Any modification to MinIO server code must be released under AGPL when distributed or offered as a service. Evaluate this before embedding in commercial products. MinIO offers a commercial license (AIStor Enterprise) as an alternative.
- **Erasure coding is immutable per server pool**: The number of drives and parity level are fixed when a server pool is created. You cannot add drives to an existing pool; you can only expand by adding a new server pool. Plan drive count carefully at deployment time.
- **Default credentials are `minioadmin`/`minioadmin`**: Every fresh install uses the same root credentials. Change them immediately via `MINIO_ROOT_USER` and `MINIO_ROOT_PASSWORD` environment variables. Minimum password length is 8 characters.
- **`mc mirror` deletes by default**: Like `rclone sync`, `mc mirror` removes objects in the destination that are not in the source. Use `mc mirror --overwrite` to only update changed files without deleting, or `mc cp --recursive` for additive transfers.
- **Versioning must be enabled before replication**: Bucket replication requires versioning on both source and target buckets. Enabling versioning is irreversible; you can suspend it but not disable it. This is an S3 specification constraint.
- **Single-drive mode has no data protection**: Running `minio server /single/path` provides no erasure coding, no healing, and no drive failure tolerance. Use a minimum of 4 drives (one server, four paths) for any data you care about.
- **Lifecycle expiration does not replicate**: When a lifecycle rule deletes an object on the source, that deletion is not replicated to the target by default. Replication and lifecycle operate independently. Plan retention policies on both sides.
- **TLS cert file naming is strict**: Certificates must be named exactly `public.crt` and `private.key` in the certs directory. Subdirectories can hold additional certs for SNI routing, each also named `public.crt` and `private.key`. MinIO reloads modified certs automatically but requires `SIGHUP` for newly added cert directories.
- **Server pools must have identical erasure set sizes**: When expanding by adding a new server pool, the new pool's erasure set size should match the existing pools for balanced distribution. Mismatched pools lead to uneven data placement.

## See Also
- **rclone** -- Cloud storage sync tool with MinIO/S3 backend support for backup workflows
- **borg** -- Deduplicated encrypted backup; can target MinIO via rclone or S3 backend
- **restic** -- Content-addressed backup with native S3 backend support for MinIO
- **docker** -- MinIO is commonly deployed as a Docker container in lab and production environments

## References
See `references/` for:
- `common-patterns.md` -- deployment patterns, user/policy management, replication, lifecycle, and TLS setup
- `docs.md` -- official documentation links
