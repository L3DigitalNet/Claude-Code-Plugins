---
name: coredns
description: >
  CoreDNS DNS server administration: Corefile syntax, plugin chain configuration,
  Kubernetes cluster DNS, recursive resolution, authoritative zones, metrics,
  health endpoints, and troubleshooting. Triggers on: coredns, CoreDNS, Corefile,
  kubernetes DNS, coredns plugin, DNS with CoreDNS, cluster DNS, forward plugin,
  kubernetes plugin, coredns reload, corefile validate.
globs:
  - "**/Corefile"
  - "**/coredns/**"
  - "**/coredns.yaml"
  - "**/coredns-configmap*"
---

## Identity
- **Binary**: `/usr/local/bin/coredns` (standalone), `/usr/bin/coredns` (package install)
- **Unit**: `coredns.service` (when run as a systemd service)
- **Corefile**: `/etc/coredns/Corefile` (standalone), ConfigMap `coredns` in namespace `kube-system` (Kubernetes)
- **Logs**: `journalctl -u coredns` (systemd), `kubectl logs -n kube-system -l k8s-app=kube-dns` (k8s)
- **Kubernetes deployment**: `kubectl -n kube-system get deployment coredns`
- **Distro install**: `apt install coredns` / `dnf install coredns` / binary from https://github.com/coredns/coredns/releases
- **Docker**: `docker run coredns/coredns -conf /Corefile`

## Key Operations

| Operation | Command |
|-----------|---------|
| Check service status | `systemctl status coredns` |
| Reload config (no restart) | `kill -SIGUSR1 $(pidof coredns)` or `systemctl reload coredns` |
| Validate Corefile syntax | `coredns -conf /etc/coredns/Corefile -validate` |
| Query health endpoint | `curl -s http://localhost:8080/health` |
| Query readiness endpoint | `curl -s http://localhost:8181/ready` |
| View Prometheus metrics | `curl -s http://localhost:9153/metrics` |
| Check specific metric | `curl -s http://localhost:9153/metrics \| grep coredns_dns_requests_total` |
| Check logs (systemd) | `journalctl -u coredns -f` |
| Test DNS query (UDP) | `dig @127.0.0.1 example.com A` |
| Test DNS query (TCP) | `dig +tcp @127.0.0.1 example.com A` |
| Override Kubernetes DNS | Edit ConfigMap: `kubectl -n kube-system edit configmap coredns` |
| Reload k8s CoreDNS | `kubectl -n kube-system rollout restart deployment/coredns` |
| Check plugin build list | `coredns -plugins` |
| Trace a query | Add `log` plugin to zone block; watch `journalctl -u coredns -f` |

## Expected Ports

- **53/UDP** — DNS queries (primary)
- **53/TCP** — DNS queries (fallback for large responses, zone transfers)
- **9153/TCP** — Prometheus metrics (requires `prometheus` plugin in Corefile)
- **8080/TCP** — Health check endpoint (requires `health` plugin)
- **8181/TCP** — Readiness endpoint (requires `ready` plugin)
- Verify listening: `ss -ulnp | grep coredns` (UDP) and `ss -tlnp | grep coredns` (TCP)

## Health Checks

1. `systemctl is-active coredns` → `active`
2. `curl -sf http://localhost:8080/health` → response body `OK`
3. `curl -sf http://localhost:8181/ready` → response body `OK` (all plugins initialized)
4. `dig @127.0.0.1 . SOA +noall +comments` → status `NOERROR` confirms DNS is answering

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `plugin/forward: no nameservers found` | `forward` block has no upstream or upstream unreachable | Verify upstream IPs: `dig @8.8.8.8 google.com`; check firewall allows outbound 53 |
| Loop detected, CoreDNS restarting | `loop` plugin detected forwarding back to itself | Check `/etc/resolv.conf` — if it points to 127.0.0.1 and CoreDNS forwards there, a loop forms; use a real upstream |
| Kubernetes service DNS not resolving | `kubernetes` plugin not loaded, or wrong cluster domain | Confirm `kubernetes cluster.local in-addr.arpa ip6.arpa` line exists in Corefile and CoreDNS pod is running |
| Metrics endpoint returns 404 or connection refused | `prometheus` plugin not in Corefile, or wrong port | Add `prometheus :9153` to the server block; confirm port in `ss` output |
| Config reload drops in-flight queries | SIGUSR1 reload is not instantaneous; brief query loss possible under high load | For zero-drop reloads in k8s, use a rolling restart with `PodDisruptionBudget` |
| Plugin not available at runtime | Plugin not compiled into the binary | Run `coredns -plugins` to list compiled plugins; custom plugins require building with `xcorefile` |
| `SERVFAIL` on all queries | Corefile syntax error or upstream unreachable | Run `coredns -conf /etc/coredns/Corefile -validate`; check upstream reachability |

## Pain Points

- **Plugin chain execution order is critical**: plugins in a zone block execute top-to-bottom. `cache` must come before `forward`; `rewrite` must come before `forward`. Wrong order silently changes behavior.
- **`forward` replaces `proxy` (v1.5+)**: the `proxy` plugin was removed in CoreDNS 1.5. All configs using `proxy` must be migrated to `forward`. The syntax is similar but not identical — `health_check` becomes `health_check <interval>` in `forward`.
- **`health` vs `ready` vs `prometheus` endpoints are separate**: `health` (:8080) answers once the server is up. `ready` (:8181) waits until all plugins signal readiness (e.g., Kubernetes plugin has synced). Kubernetes liveness uses `health`; readiness uses `ready`. Mixing them causes premature or delayed traffic routing.
- **Kubernetes `ClusterDNS` must point to CoreDNS service IP**: kubelet's `--cluster-dns` flag (or `clusterDNS` in kubelet config) must match the `kube-dns` Service ClusterIP. Mismatch silently leaves pods using the node's resolver instead of CoreDNS.
- **Compiling custom plugins requires `xcorefile`**: CoreDNS uses a `plugin.cfg` file and a `make` build to include plugins. The `xcorefile` tool automates this. Standard binaries and distro packages do not include third-party plugins.
- **`loop` plugin is safety-critical in Kubernetes**: without it, a misconfigured upstream pointing back at CoreDNS creates an infinite loop that exhausts resources. The `loop` plugin detects this and kills the server — alarming but correct behavior.
- **Zone block scoping**: a query matches the most-specific zone. `.` (dot) is the catch-all. If you define `example.com` and `.`, queries for `example.com` hit the first block only. Plugins in `.` do not run for `example.com` queries unless explicitly repeated.

## References

See `references/` for:
- `Corefile.annotated` — complete Corefile with every plugin and directive explained
- `docs.md` — official documentation and community links
