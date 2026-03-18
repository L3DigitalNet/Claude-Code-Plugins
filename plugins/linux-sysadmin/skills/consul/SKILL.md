---
name: consul
description: >
  HashiCorp Consul service discovery, service mesh, and KV store: agent deployment
  (server/client modes), service registration, health checks, DNS interface, ACL
  system, Connect (service mesh with sidecar proxies and intentions), prepared
  queries, snapshots, and cluster management.
  MUST consult when installing, configuring, or troubleshooting consul.
triggerPhrases:
  - "consul"
  - "HashiCorp Consul"
  - "consul agent"
  - "consul server"
  - "consul client"
  - "consul service mesh"
  - "consul connect"
  - "consul service discovery"
  - "consul dns"
  - "consul kv"
  - "consul acl"
  - "consul intention"
  - "consul snapshot"
  - "consul prepared query"
  - "consul health check"
  - "consul catalog"
  - "consul members"
globs:
  - "**/consul.hcl"
  - "**/consul.json"
  - "**/consul.d/*.hcl"
  - "**/consul.d/*.json"
last_verified: "2026-03"
---

## Identity

- **Unit**: `consul.service`
- **Binary**: `/usr/bin/consul`
- **Config dir**: `/etc/consul.d/` (package install default)
- **Data dir**: `/opt/consul/data/` (or as configured via `data_dir`)
- **Logs**: `journalctl -u consul`
- **Web UI**: http://localhost:8500/ui (when `ui_config.enabled = true`)
- **DNS**: queries on port 8600 in the `.consul` domain
- **Agent modes**: server (participates in Raft consensus, stores state) or client (forwards RPCs to servers, runs health checks locally)
- **Install**: `apt install consul` / `dnf install consul` (after adding the HashiCorp repo), or download from https://releases.hashicorp.com/consul
- **Current version**: 1.22.x
- **License**: BSL 1.1 (source-available) since v1.17 (Aug 2023); the last MPL 2.0 release was 1.16.x. Internal use is unrestricted, but hosting Consul as a competing managed service is not permitted. Enterprise features (admin partitions, namespaces, automated upgrades, audit logging, redundancy zones) require a paid license.

## Quick Start

```bash
# 1. Install (Debian/Ubuntu -- add HashiCorp repo first)
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install consul

# 2. Start a dev agent (in-memory, no ACLs, NOT for production)
consul agent -dev

# 3. In another terminal, verify the agent is running
consul members

# 4. Register a service via the HTTP API
curl --request PUT --data '{
  "Name": "web",
  "Port": 8080,
  "Check": {"HTTP": "http://localhost:8080/health", "Interval": "10s"}
}' http://127.0.0.1:8500/v1/agent/service/register

# 5. Query the service via DNS
dig @127.0.0.1 -p 8600 web.service.consul SRV

# 6. Read/write KV data
consul kv put config/db/host "db.internal"
consul kv get config/db/host
```

## Key Operations

| Task | Command |
|------|---------|
| Start agent (server mode) | `consul agent -config-dir=/etc/consul.d/` |
| Cluster members | `consul members` |
| Join a cluster | `consul join <ip>` |
| Leave cluster gracefully | `consul leave` |
| Register service (file) | Place JSON/HCL in config dir, then `consul reload` |
| Register service (API) | `curl -X PUT -d @svc.json http://127.0.0.1:8500/v1/agent/service/register` |
| Deregister service | `consul services deregister -id=<service-id>` |
| List services | `consul catalog services` |
| List nodes | `consul catalog nodes` |
| DNS service lookup (A) | `dig @127.0.0.1 -p 8600 web.service.consul` |
| DNS service lookup (SRV) | `dig @127.0.0.1 -p 8600 web.service.consul SRV` |
| DNS node lookup | `dig @127.0.0.1 -p 8600 mynode.node.consul` |
| KV put | `consul kv put path/key value` |
| KV get | `consul kv get path/key` |
| KV delete | `consul kv delete path/key` |
| KV list | `consul kv get -recurse prefix/` |
| KV export/import | `consul kv export prefix/ > backup.json` / `consul kv import @backup.json` |
| Bootstrap ACLs | `consul acl bootstrap` |
| Create ACL policy | `consul acl policy create -name=mypolicy -rules=@policy.hcl` |
| Create ACL token | `consul acl token create -description="svc token" -policy-name=mypolicy` |
| Set agent token | `consul acl set-agent-token agent <token>` |
| Create intention (allow) | `consul intention create web api` |
| Create intention (deny) | `consul intention create -deny '*' secrets-svc` |
| List intentions | `consul intention list` |
| Snapshot save | `consul snapshot save backup.snap` |
| Snapshot restore | `consul snapshot restore backup.snap` |
| Snapshot inspect | `consul snapshot inspect backup.snap` |
| Raft peers | `consul operator raft list-peers` |
| Force leader election | `consul operator raft remove-peer -address=<addr>` |
| Reload config | `consul reload` |
| Agent info | `consul info` |
| Monitor logs | `consul monitor -log-level=debug` |

## Expected Ports

| Port | Protocol | Purpose | Verify |
|------|----------|---------|--------|
| 8500 | TCP | HTTP API + web UI | `ss -tlnp \| grep :8500` |
| 8501 | TCP | HTTPS API (disabled by default) | `ss -tlnp \| grep :8501` |
| 8600 | TCP/UDP | DNS interface | `dig @127.0.0.1 -p 8600 consul.service.consul` |
| 8300 | TCP | Server RPC (server-to-server) | `ss -tlnp \| grep :8300` |
| 8301 | TCP/UDP | Serf LAN gossip (all agents) | `ss -tlnp \| grep :8301` |
| 8302 | TCP/UDP | Serf WAN gossip (servers only, cross-datacenter) | `ss -tlnp \| grep :8302` |
| 8502 | TCP | gRPC API (Consul Dataplane, disabled by default) | `ss -tlnp \| grep :8502` |
| 8503 | TCP | gRPC TLS (Consul Dataplane, enabled on servers by default) | `ss -tlnp \| grep :8503` |

Only servers need 8300 and 8302. All agents need 8301. Open 8500/8501 only to trusted networks or behind a reverse proxy.

## Health Checks

Consul supports several health check types, all of which transition through three states: `passing`, `warning`, `critical`.

1. **HTTP**: GET/POST to an endpoint; 2xx = passing, 429 = warning, anything else = critical.
2. **TCP**: Connection attempt to host:port; success = passing.
3. **Script/Exec**: Run a command; exit 0 = passing, exit 1 = warning, any other = critical.
4. **TTL**: Service must heartbeat within the TTL window via the HTTP API (`/v1/agent/check/pass/:id`).
5. **gRPC**: Uses the gRPC health checking protocol.
6. **H2ping**: HTTP/2 ping check.
7. **Docker**: Execute a command inside a running container.
8. **Alias**: Mirrors the health state of another service or node.
9. **UDP**: Send a datagram and check for a response.
10. **OS Service**: Check the status of a system service.

Services that fail their health check (or whose node fails a system check) are automatically excluded from DNS and API query results.

Key parameters: `interval` (how often to run), `timeout` (how long to wait), `deregister_critical_service_after` (auto-deregister after sustained critical state).

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `No cluster leader` | Fewer than `bootstrap_expect` servers joined, or Raft election failed | Verify all servers are running and can reach each other on port 8300; check `consul operator raft list-peers` |
| `Error joining: dial tcp ... connection refused` | Target node not running or firewall blocking 8301 | Start the target agent; open TCP+UDP 8301 between all agents |
| `ACL not found` / `Permission denied` | ACLs enabled but token missing or insufficient | Set `CONSUL_HTTP_TOKEN` or pass `-token`; verify the token's policy grants the required resource |
| `rpc error: Permission denied` on agent startup | Agent token not set after ACL bootstrap | Create an agent token with `consul acl token create -node-identity=...` and apply it |
| `Coordinate update blocked by ACLs` | Client agent lacks `node:write` for its own node name | Attach a policy with `node "<name>" { policy = "write" }` to the agent token |
| Service not appearing in DNS | Health check failing, or service not registered | `consul catalog services` to confirm registration; check health with `curl http://127.0.0.1:8500/v1/health/service/<name>` |
| DNS returns no results (`NXDOMAIN`) | Querying wrong domain, or agent DNS not listening | Confirm domain is `.consul` and target port is 8600; `dig @127.0.0.1 -p 8600 consul.service.consul` |
| `Raft peer not found` after node replacement | Old node ID still in Raft config | Remove the stale peer: `consul operator raft remove-peer -id=<old-id>` |
| Snapshot restore fails | Version mismatch or corrupt snapshot | Restore into the same Consul version that created the snapshot; run `consul snapshot inspect` to validate |
| `Cannot connect to upstream` in service mesh | Sidecar proxy not running, or intention denying traffic | Check `consul connect envoy` is running; verify intentions with `consul intention check <src> <dst>` |
| High memory/CPU on servers | Too many blocking queries, watches, or health checks | Tune check intervals; reduce watch frequency; scale server resources |

## Pain Points

- **Server vs client confusion**: servers participate in Raft consensus and store all state; clients are lightweight forwarders that run health checks locally. Every node in the datacenter should run a Consul agent (either mode). A cluster needs 3 or 5 servers for fault tolerance (never an even number).
- **DNS port 8600 vs 53**: Consul's DNS listens on 8600, not the standard port 53. To integrate with system DNS, configure your resolver (systemd-resolved, dnsmasq, unbound) to forward the `.consul` domain to 127.0.0.1:8600. Without this, applications cannot resolve `*.service.consul` names natively.
- **ACL bootstrap is one-shot**: `consul acl bootstrap` can only be called once. If the bootstrap token is lost, you must follow the ACL reset procedure (place a reset file in the data dir and restart). Plan to store the bootstrap token securely from the start.
- **Default-allow vs default-deny**: Without ACLs, everything is allowed. After enabling ACLs with `default_policy = "deny"`, every agent, service, and KV path needs an explicit token. Roll out ACLs incrementally: enable with `default_policy = "allow"` first, create tokens, then switch to `"deny"`.
- **Gossip encryption is all-or-nothing**: Once you set the `encrypt` key, all agents must use the same key. Rotating gossip encryption keys requires a multi-step process (install new key on all agents, then make it primary, then remove old key). Plan this before first deployment.
- **Connect/service mesh adds operational overhead**: Each service gets an Envoy sidecar proxy, which consumes memory and CPU. Intentions replace traditional firewall rules but require their own management. Start with service discovery and health checks; add the mesh when you actually need mTLS or L7 traffic management.
- **Prepared queries are API-only**: There is no CLI for creating or managing prepared queries; you must use the HTTP API (`/v1/query`). They are stored in the Raft log and included in snapshots.
- **Snapshot security**: Snapshots contain ACL tokens, KV data, and service catalog entries in a gzipped tar archive. Store them encrypted and access-controlled. Community Edition has no automated snapshot agent; script `consul snapshot save` via cron.

## See Also

- `vault` -- secrets management (frequently paired with Consul for service tokens and dynamic credentials)
- `etcd` -- distributed KV store (alternative for configuration and coordination)
- `terraform` -- infrastructure as code (Consul provider for service catalog and KV management)
- `tailscale` -- mesh VPN (alternative network layer; can complement or replace Consul Connect for encrypted inter-node communication)
- `coredns` -- DNS server (can use Consul as a backend for service discovery)
- `traefik` -- reverse proxy (has native Consul Catalog provider for automatic service routing)

## References

See `references/` for:
- `docs.md` -- verified official documentation links
- `common-patterns.md` -- server config, service registration, ACL setup, KV operations, Connect mesh, prepared queries, DNS forwarding, and snapshots
- `consul.hcl.annotated` -- annotated server configuration with every directive explained, default values, and guidance on when to change them
