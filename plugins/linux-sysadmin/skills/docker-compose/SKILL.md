---
name: docker-compose
description: >
  Docker Compose multi-container application orchestration: compose file syntax,
  service definitions, networking, volumes, environment variables, healthchecks,
  and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting Docker Compose.
triggerPhrases:
  - "docker compose"
  - "docker-compose"
  - "compose.yml"
  - "compose.yaml"
  - "multi-container"
  - "docker stack"
globs:
  - "**/docker-compose.yml"
  - "**/docker-compose.yaml"
  - "**/compose.yml"
  - "**/compose.yaml"
  - "**/docker-compose.*.yml"
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **CLI** | `docker compose` (v2, plugin) or `docker-compose` (v1, standalone) |
| **Config** | `compose.yml` / `compose.yaml` / `docker-compose.yml` (searched in order) |
| **Default project name** | directory name of the compose file |
| **Install** | Included with Docker Desktop; `apt install docker-compose-plugin` (Compose v2 plugin) |

## Quick Start
```bash
sudo apt install docker-compose-plugin
docker compose version                  # Docker Compose version v2.x.x
docker compose config                   # validate compose file in current dir
docker compose up -d                    # start all services detached
```

## Key Operations

| Task | Command |
|------|---------|
| Start all services (detached) | `docker compose up -d` |
| Stop and remove containers | `docker compose down` |
| Stop and remove including volumes | `docker compose down -v` |
| View logs | `docker compose logs -f` |
| View logs for one service | `docker compose logs -f servicename` |
| Rebuild images | `docker compose build` or `docker compose up -d --build` |
| Scale a service | `docker compose up -d --scale web=3` |
| Run one-off command | `docker compose run --rm servicename command` |
| Exec into running service | `docker compose exec servicename bash` |
| Show running services | `docker compose ps` |
| Validate compose file | `docker compose config` |
| Pull latest images | `docker compose pull` |
| Restart one service | `docker compose restart servicename` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Service won't start | Config error or port conflict | `docker compose logs servicename` |
| `network not found` | Stale network from old run | `docker compose down` then `docker compose up -d` |
| Volume data lost | Used `down -v` | Volumes are persistent unless explicitly deleted |
| Service start order wrong | No `depends_on` or unhealthy dependency | Add `depends_on` with `condition: service_healthy` |
| `invalid interpolation format` | `$` in value needs escaping | Use `$$` to escape literal dollar signs |
| Environment var not picked up | `.env` file not in compose file directory | Check path; use `env_file:` to be explicit |
| Compose file not found | Wrong directory or wrong filename | Filenames checked: compose.yml, compose.yaml, docker-compose.yml |

## Pain Points
- **`docker compose down` vs `stop`**: `down` removes containers AND networks. `stop` only stops. Data in named volumes survives both unless you add `-v`.
- **Project name**: Determines network and volume name prefixes. Change with `-p name` or `COMPOSE_PROJECT_NAME` env var. Matters when running multiple compose stacks.
- **`depends_on` is not enough**: By default it only waits for container start, not service readiness. Use `condition: service_healthy` with a HEALTHCHECK for real readiness.
- **Build context**: `build: .` uses the current directory as context. Large directories with no `.dockerignore` make builds slow.
- **Environment variable precedence**: shell env > `.env` file > `environment:` in compose > `env_file:`. Shell always wins.
- **`profiles`**: Services with a profile are not started by default. `docker compose --profile debug up` to include them.
- **Compose v1 vs v2**: `docker-compose` (hyphen) is v1 (deprecated). `docker compose` (space) is v2. Behavior differences exist; prefer v2.

## See Also
- **docker** — container runtime that Compose orchestrates; required for all Compose operations
- **podman** — daemonless container alternative with `podman compose` compatibility for Compose files

## References
See `references/` for:
- `compose-patterns.md` — complete working examples for common patterns
- `docs.md` — official documentation links
