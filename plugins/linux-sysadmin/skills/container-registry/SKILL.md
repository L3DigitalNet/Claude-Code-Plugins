---
name: container-registry
description: >
  Container image registry administration — Docker Registry (Distribution),
  Harbor enterprise registry, image storage, authentication, TLS configuration,
  garbage collection, replication, and vulnerability scanning.
  MUST consult when installing, configuring, or troubleshooting container image registries.
triggerPhrases:
  - "container registry"
  - "docker registry"
  - "image registry"
  - "Harbor"
  - "private registry"
  - "registry mirror"
  - "registry authentication"
  - "push image"
  - "pull image"
  - "OCI registry"
  - "distribution registry"
globs:
  - "**/registry/config.yml"
  - "**/harbor.yml"
last_verified: "2026-03"
---

## Identity

### Distribution Registry (CNCF)

- **What**: OCI-compliant container image registry, the open-source engine behind Docker Hub — donated by Docker to CNCF
- **Image**: `registry:3` (v3.0.0+, stable since April 2025); legacy `registry:2` still available for v2.8.x
- **Config**: `/etc/distribution/config.yml` (mounted into container)
- **Data dir**: `/var/lib/registry` (default filesystem storage root inside container)
- **Port**: 5000/tcp (HTTP API)
- **API**: OCI Distribution Spec, Docker Registry HTTP API V2 at `/v2/`
- **Storage backends**: filesystem, S3, Azure Blob, Google Cloud Storage, in-memory (testing only)

### Harbor

- **What**: CNCF Graduated enterprise registry — adds RBAC, vulnerability scanning (Trivy), replication, audit logging, and a web UI on top of Distribution
- **Current version**: v2.14.x (stable as of early 2026)
- **Config**: `harbor.yml` in the installer directory
- **Data dir**: `/data` (default `data_volume` in `harbor.yml`)
- **Ports**: 80/tcp (HTTP), 443/tcp (HTTPS)
- **Components**: nginx proxy, core API, PostgreSQL, Redis, registry (Distribution), jobservice, portal, (optional) Trivy scanner
- **Prerequisites**: Docker Engine > 20.10, Docker Compose > 2.3, minimum 2 CPU / 4 GB RAM / 40 GB disk
- **Default admin**: `admin` / `Harbor12345` — change immediately after install

## Quick Start

Run a local registry and push an image in four commands:

```bash
docker run -d -p 5000:5000 --restart=always --name registry registry:3
docker tag alpine:latest localhost:5000/alpine:latest
docker push localhost:5000/alpine:latest
docker pull localhost:5000/alpine:latest
```

## Key Operations

| Task | Command |
|------|---------|
| Start registry (Docker) | `docker run -d -p 5000:5000 --restart=always --name registry registry:3` |
| Start registry (with storage volume) | `docker run -d -p 5000:5000 -v /mnt/registry:/var/lib/registry --restart=always --name registry registry:3` |
| Push image | `docker tag myimg:v1 registry.example.com:5000/myimg:v1 && docker push registry.example.com:5000/myimg:v1` |
| Pull image | `docker pull registry.example.com:5000/myimg:v1` |
| List repositories (API) | `curl -s https://registry.example.com:5000/v2/_catalog \| jq` |
| List tags for a repo (API) | `curl -s https://registry.example.com:5000/v2/myimg/tags/list \| jq` |
| Delete manifest by digest | `curl -X DELETE https://registry.example.com:5000/v2/myimg/manifests/sha256:<digest>` |
| Get manifest digest | `curl -sI -H "Accept: application/vnd.docker.distribution.manifest.v2+json" https://registry.example.com:5000/v2/myimg/manifests/v1 \| grep Docker-Content-Digest` |
| Garbage collect (dry run) | `docker exec registry bin/registry garbage-collect --dry-run /etc/distribution/config.yml` |
| Garbage collect (execute) | `docker exec registry bin/registry garbage-collect /etc/distribution/config.yml` |
| GC + delete untagged | `docker exec registry bin/registry garbage-collect --delete-untagged /etc/distribution/config.yml` |
| Harbor install | `sudo ./install.sh` (from extracted Harbor installer directory) |
| Harbor install + Trivy | `sudo ./install.sh --with-trivy` |
| Harbor stop/start | `docker compose down` / `docker compose up -d` (from Harbor install directory) |
| Harbor reconfigure | Edit `harbor.yml`, then `sudo ./prepare && docker compose down && docker compose up -d` |

## Expected Ports

- **5000/tcp**: Distribution Registry default HTTP API port
- **443/tcp**: Distribution Registry with TLS, or Harbor HTTPS (default)
- **80/tcp**: Harbor HTTP (default; avoid in production)
- Verify: `ss -tlnp | grep -E '5000|:80|:443'`
- Firewall: `sudo ufw allow 5000/tcp` (standalone registry) or `sudo ufw allow 443/tcp` (Harbor/TLS)

## Health Checks

1. **Registry v2 API check**: `curl -sf https://localhost:5000/v2/` → `{}` (200 OK) or 401 if auth enabled
2. **Registry debug health** (if debug server enabled): `curl -sf http://localhost:5001/debug/health`
3. **Harbor health endpoint**: `curl -sf https://harbor.example.com/api/v2.0/health` → JSON with component statuses
4. **Docker login test**: `docker login registry.example.com:5000` → `Login Succeeded`

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `http: server gave HTTP response to HTTPS client` | Docker daemon requires HTTPS for non-localhost registries | Add `"insecure-registries": ["registry.example.com:5000"]` to `/etc/docker/daemon.json` and restart Docker, or configure TLS on the registry |
| `x509: certificate signed by unknown authority` | Self-signed cert not trusted by Docker daemon | Copy CA cert to `/etc/docker/certs.d/registry.example.com:5000/ca.crt` and restart Docker |
| `authentication required` / 401 on push | Registry has auth enabled but client not logged in | Run `docker login registry.example.com:5000`; for htpasswd auth, ensure passwords are bcrypt-encoded (`htpasswd -Bbn`) |
| `denied: requested access to the resource is denied` | Harbor RBAC — user lacks push permission for the project | Grant developer or admin role to the user on the Harbor project |
| Push succeeds but disk not freed after delete | Deleting manifests/tags only removes references, not blobs | Run garbage collection: `registry garbage-collect /etc/distribution/config.yml`; Harbor: run GC from Administration > Clean Up |
| GC runs but no space reclaimed | Blobs still referenced by other manifests, or `delete` not enabled in storage config | Add `delete: {enabled: true}` under `storage` in `config.yml`; check for multi-tag references |
| Harbor "core" container in restart loop | `harbor.yml` hostname set to localhost/127.0.0.1, or database password unchanged | Set `hostname` to FQDN or real IP; change `database.password` from default |
| Harbor GC deletes in-progress uploads | Upload started during GC window | Harbor reserves a 2-hour window for recent uploads; schedule GC during low-traffic periods |
| `manifest unknown` on pull after delete + GC | Tag was deleted and GC cleaned the layers | Expected behavior — re-push the image if needed |
| Registry container exits immediately | Port conflict or invalid config.yml | Check `docker logs registry`; validate YAML syntax; verify port 5000 is not in use |

## Pain Points

- **TLS is mandatory for non-localhost access.** Docker refuses plaintext HTTP to any registry except `localhost` and `127.0.0.1`. Either configure TLS on the registry, or add `insecure-registries` to every client's `daemon.json` — the latter is a maintenance burden that scales poorly.
- **Garbage collection is not automatic and requires downtime (Distribution).** Deleting images via the API only removes the manifest reference. Blobs persist on disk until you run `registry garbage-collect`, which is a stop-the-world operation — the registry must be read-only or stopped. Harbor improves on this with a built-in GC scheduler that runs online with a 2-hour safety window for in-flight uploads.
- **`delete` must be explicitly enabled.** Distribution's default config does not allow deletes. You need `storage.delete.enabled: true` in `config.yml`, or API DELETE calls return 405.
- **Harbor is a full platform, not just a registry.** It bundles PostgreSQL, Redis, nginx, a job service, and optionally Trivy. This means higher resource consumption (4 GB RAM minimum) and more components to monitor compared to a standalone Distribution registry. For simple use cases, bare Distribution is lighter.
- **Storage backend determines performance and cost.** Filesystem storage is simple but limits you to a single node. S3-compatible backends enable HA and load balancing but add latency and cost. Distribution supports filesystem, S3, Azure, and GCS; Harbor inherits these options.
- **Pull-through cache has limits.** Distribution can act as a pull-through cache for Docker Hub (via `proxy.remoteurl`), but only for Docker Hub — not arbitrary upstream registries. Cached content respects a TTL (default 168h). Private images require embedding credentials in the registry config, which makes the mirror a security-sensitive component.
- **Harbor replication is powerful but operationally complex.** Push-based and pull-based replication between Harbor instances (or to/from Docker Hub, ECR, GCR, ACR, etc.) works well, but each rule needs an endpoint definition, filters, and trigger configuration. Test replication rules on a small project before rolling out broadly.

## See Also

- `docker` — container runtime, `docker push`/`pull`/`login` commands
- `podman` — daemonless alternative, supports the same registry protocol
- `helm` — Helm charts can be stored in OCI registries (Harbor supports Helm chart repositories natively)
- **buildah** — build images to push to your registry without a Docker daemon
- **trivy** — scan registry images for vulnerabilities

## References

See `references/` for:
- `docs.md` — official documentation links for Distribution and Harbor
- `common-patterns.md` — TLS + auth setup, Harbor Docker Compose deployment, pull-through cache, daemon configuration, GC, and replication patterns
