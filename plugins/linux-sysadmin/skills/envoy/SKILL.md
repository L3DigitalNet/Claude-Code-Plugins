---
name: envoy
description: >
  Envoy proxy administration: L4/L7 proxy and service mesh data plane,
  listener/cluster/route configuration, xDS dynamic discovery, admin interface,
  access logging, circuit breaking, rate limiting, health checks, TLS termination,
  and Istio integration.
  MUST consult when installing, configuring, or troubleshooting envoy.
triggerPhrases:
  - "envoy"
  - "Envoy"
  - "envoy proxy"
  - "envoy config"
  - "envoy listener"
  - "envoy cluster"
  - "envoy route"
  - "xDS"
  - "envoy admin"
  - "envoy sidecar"
  - "service mesh"
  - "envoy circuit breaker"
  - "envoy filter"
  - "envoy.yaml"
  - "http_connection_manager"
globs:
  - "**/envoy.yaml"
  - "**/envoy.yml"
  - "**/envoy-config.yaml"
  - "**/envoy-config.yml"
  - "**/bootstrap.yaml"
last_verified: "2026-03"
---

## Identity

- **Binary**: `envoy`
- **Config**: `/etc/envoy/envoy.yaml` (or custom path via `-c`)
- **Logs**: stdout/stderr by default; access log path configurable per listener
- **Admin interface**: port 9901 (default, bind to 127.0.0.1 in production)
- **Install**: Docker (`envoyproxy/envoy:v1.32-latest`), `apt install envoy` (some distros), binary from getenvoy.io/func-e, or compiled from source
- **Version check**: `envoy --version`

## Quick Start

```bash
# Run with Docker
docker run --rm -p 10000:10000 -p 9901:9901 \
  -v $(pwd)/envoy.yaml:/etc/envoy/envoy.yaml \
  envoyproxy/envoy:v1.32-latest

# Or install and run directly
envoy -c /etc/envoy/envoy.yaml

# Check admin interface
curl http://localhost:9901/server_info
curl http://localhost:9901/clusters
```

## Key Operations

| Task | Command |
|------|---------|
| Start with config | `envoy -c /etc/envoy/envoy.yaml` |
| Start with log level | `envoy -c /etc/envoy/envoy.yaml -l debug` |
| Validate config | `envoy --mode validate -c /etc/envoy/envoy.yaml` |
| Hot restart | `envoy -c /etc/envoy/envoy.yaml --restart-epoch 1` |
| Server info | `curl http://localhost:9901/server_info` |
| List clusters | `curl http://localhost:9901/clusters` |
| List listeners | `curl http://localhost:9901/listeners` |
| Dump full config | `curl http://localhost:9901/config_dump` |
| Filter config dump | `curl 'http://localhost:9901/config_dump?resource=dynamic_listeners'` |
| View stats | `curl http://localhost:9901/stats` |
| Stats as Prometheus | `curl http://localhost:9901/stats/prometheus` |
| Stats filtered | `curl 'http://localhost:9901/stats?filter=cluster\.'` |
| Readiness check | `curl http://localhost:9901/ready` |
| Set health to failing | `curl -X POST http://localhost:9901/healthcheck/fail` |
| Restore health | `curl -X POST http://localhost:9901/healthcheck/ok` |
| Change log level | `curl -X POST 'http://localhost:9901/logging?level=info'` |
| Drain listeners | `curl -X POST 'http://localhost:9901/drain_listeners?graceful'` |
| Quit server | `curl -X POST http://localhost:9901/quitquitquit` |

## Expected Ports

- **Listener ports** -- user-defined (e.g., 10000, 80, 443); depends on configuration
- **9901/tcp** -- Admin interface (default; must be restricted to localhost/internal)
- Verify: `ss -tlnp | grep envoy`
- The admin interface exposes sensitive data and allows runtime modification. Never bind to 0.0.0.0 in production.

## Health Checks

1. `curl -sf http://localhost:9901/ready` -> 200 (LIVE state), 503 otherwise
2. `curl -sf http://localhost:9901/server_info | jq .state` -> `LIVE`
3. `curl -sf http://localhost:9901/clusters | grep -c 'health_flags::'` -> check for healthy upstreams
4. `curl -sf http://localhost:9901/stats | grep 'server.live'` -> `1`

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Config fails validation | YAML syntax or proto schema error | `envoy --mode validate -c envoy.yaml`; check `@type` fields match proto paths |
| Listener won't bind | Port already in use or insufficient permissions | `ss -tlnp \| grep <port>`; for ports < 1024, use `CAP_NET_BIND_SERVICE` or run as root |
| Cluster shows all hosts unhealthy | Upstream unreachable or health check misconfigured | `curl http://localhost:9901/clusters` to see health flags; verify upstream is reachable from Envoy |
| 503 responses | No healthy upstreams or circuit breaker tripped | Check cluster health via admin; review `circuit_breakers` thresholds |
| 404 on valid paths | Route not matching | `curl http://localhost:9901/config_dump` to inspect route config; check virtual_hosts domains and route match prefixes |
| TLS handshake failure | Certificate mismatch or missing chain | Verify cert paths in transport_socket config; `openssl s_client -connect <host>:<port>` to test |
| xDS config not updating | Management server unreachable or version mismatch | Check xDS cluster connectivity; `curl http://localhost:9901/config_dump` for last received version |
| High memory usage | Large number of clusters/endpoints or access log buffering | Review cluster count; tune `overload_manager`; check access log flush interval |
| `upstream_rq_timeout` spike | Backend too slow | Increase `timeout` on route; check backend health; tune `connect_timeout` on cluster |

## Pain Points

- **Configuration is verbose and proto-typed.** Every filter and config block requires a `typed_config` with an `@type` field pointing to the protobuf message type (e.g., `type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager`). This is necessary for extensibility but makes hand-written configs error-prone.
- **Static vs dynamic config.** Static configs are defined entirely in `envoy.yaml` at startup. Dynamic configs use xDS APIs (LDS, RDS, CDS, EDS, SDS) where a management server pushes configuration updates. Most production deployments use dynamic config via a control plane (Istio, Gloo, etc.). You need at least a static bootstrap config that points to the xDS management server.
- **Envoy is a data plane, not a control plane.** Envoy itself doesn't make routing decisions based on service discovery; it receives configuration from a control plane. Istio's istiod, Gloo, or Envoy Gateway serve as control planes that configure Envoy via xDS.
- **Circuit breakers have modest defaults.** Default thresholds are 1024 for `max_connections`, `max_pending_requests`, and `max_requests`. These are per-cluster. For high-traffic services, increase them or set them explicitly. Circuit breaker stats are exposed at `cluster.<name>.circuit_breakers.<priority>.*`.
- **Admin interface is powerful and dangerous.** The `/quitquitquit` endpoint shuts down Envoy. `/healthcheck/fail` makes health checks fail (useful for draining). `/logging` changes log levels at runtime. Protect it aggressively.
- **Hot restart preserves connections.** Envoy supports hot restart (`--restart-epoch N`) where a new process takes over from the old one, draining existing connections. This is how you update config without dropping connections, but it requires shared memory between old and new processes.

## See Also

- **traefik** -- Auto-discovery reverse proxy; simpler config model, good for Docker/Kubernetes without a service mesh
- **nginx** -- Traditional reverse proxy/web server; less dynamic than Envoy but more widely deployed
- **haproxy** -- High-performance L4/L7 load balancer; competes with Envoy for pure load-balancing workloads

## References

See `references/` for:
- `common-patterns.md` -- static proxy setup, circuit breaking, rate limiting, access logging, TLS termination, xDS bootstrap, health checks
- `docs.md` -- official documentation links
