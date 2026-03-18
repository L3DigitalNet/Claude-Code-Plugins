---
name: rabbitmq
description: >
  RabbitMQ message broker administration: installation, queue/exchange/binding
  management, clustering, quorum queues, shovel/federation, TLS, user/vhost
  permissions, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting rabbitmq.
triggerPhrases:
  - "rabbitmq"
  - "RabbitMQ"
  - "rabbitmqctl"
  - "rabbitmq-plugins"
  - "AMQP broker"
  - "message broker"
  - "message queue rabbitmq"
  - "quorum queue"
  - "rabbitmq cluster"
  - "rabbitmq management"
  - "rabbitmq federation"
  - "rabbitmq shovel"
globs:
  - "**/rabbitmq.conf"
  - "**/rabbitmq/**/*.conf"
  - "**/rabbitmq-env.conf"
  - "**/advanced.config"
  - "**/enabled_plugins"
last_verified: "2026-03"
---

## Identity
- **Unit**: `rabbitmq-server.service`
- **Config**: `/etc/rabbitmq/rabbitmq.conf` (sysctl format), `/etc/rabbitmq/advanced.config` (Erlang term format)
- **Env config**: `/etc/rabbitmq/rabbitmq-env.conf`
- **Config dir**: `/etc/rabbitmq/conf.d/` (drop-in overrides, loaded alphabetically)
- **Logs**: `journalctl -u rabbitmq-server`, `/var/log/rabbitmq/`
- **Data dir**: `/var/lib/rabbitmq/mnesia/`
- **Erlang cookie**: `/var/lib/rabbitmq/.erlang.cookie` (server), `$HOME/.erlang.cookie` (CLI)
- **Enabled plugins**: `/etc/rabbitmq/enabled_plugins`
- **User**: runs as system user `rabbitmq`
- **Distro install**: Use Team RabbitMQ apt/yum repos (distro packages are outdated)

## Quick Start

```bash
# --- Install via official RabbitMQ apt repository (Ubuntu/Debian) ---
sudo apt-get install curl gnupg apt-transport-https -y

# Import signing key
curl -1sLf "https://keys.openpgp.org/vks/v1/by-fingerprint/0A9AF2115F4687BD29803A206B73A36E6026DFCA" | \
  sudo gpg --dearmor | sudo tee /usr/share/keyrings/com.rabbitmq.team.gpg > /dev/null

# Add repos (replace "noble" with your release codename: jammy, bookworm, etc.)
sudo tee /etc/apt/sources.list.d/rabbitmq.list <<EOF
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-erlang/ubuntu/noble noble main
deb [arch=amd64 signed-by=/usr/share/keyrings/com.rabbitmq.team.gpg] https://deb1.rabbitmq.com/rabbitmq-server/ubuntu/noble noble main
EOF

sudo apt-get update -y
sudo apt-get install -y erlang-base erlang-asn1 erlang-crypto erlang-eldap \
  erlang-ftp erlang-inets erlang-mnesia erlang-os-mon erlang-parsetools \
  erlang-public-key erlang-runtime-tools erlang-snmp erlang-ssl \
  erlang-syntax-tools erlang-tftp erlang-tools erlang-xmerl
sudo apt-get install -y rabbitmq-server

# --- Enable management UI and start ---
sudo rabbitmq-plugins enable rabbitmq_management
sudo systemctl enable --now rabbitmq-server

# --- Create admin user (guest only works from localhost) ---
sudo rabbitmqctl add_user admin 'StrongPassword'
sudo rabbitmqctl set_user_tags admin administrator
sudo rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

# --- Verify ---
sudo rabbitmqctl status
sudo rabbitmq-diagnostics check_running
curl -s -u admin:StrongPassword http://localhost:15672/api/overview | head -c 200
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status rabbitmq-server` |
| Node status (detailed) | `rabbitmqctl status` |
| Cluster status | `rabbitmqctl cluster_status` |
| List enabled plugins | `rabbitmq-plugins list --enabled` |
| Enable a plugin | `rabbitmq-plugins enable rabbitmq_management` |
| Disable a plugin | `rabbitmq-plugins disable rabbitmq_shovel` |
| List users | `rabbitmqctl list_users` |
| Add user | `rabbitmqctl add_user <user> <pass>` |
| Delete user | `rabbitmqctl delete_user <user>` |
| Set user tags | `rabbitmqctl set_user_tags <user> administrator` |
| Change password | `rabbitmqctl change_password <user> <newpass>` |
| List vhosts | `rabbitmqctl list_vhosts` |
| Add vhost | `rabbitmqctl add_vhost <vhost>` |
| Delete vhost | `rabbitmqctl delete_vhost <vhost>` |
| Set permissions | `rabbitmqctl set_permissions -p <vhost> <user> ".*" ".*" ".*"` |
| List permissions | `rabbitmqctl list_permissions -p <vhost>` |
| List queues | `rabbitmqctl list_queues -p <vhost> name messages consumers type` |
| List exchanges | `rabbitmqctl list_exchanges -p <vhost> name type` |
| List bindings | `rabbitmqctl list_bindings -p <vhost>` |
| List connections | `rabbitmqctl list_connections name peer_host state` |
| List channels | `rabbitmqctl list_channels name consumer_count messages_unacknowledged` |
| Purge a queue | `rabbitmqctl purge_queue <queue> -p <vhost>` |
| Delete a queue | `rabbitmqctl delete_queue <queue> -p <vhost>` |
| Close all connections | `rabbitmqctl close_all_connections "maintenance"` |
| Set a policy | `rabbitmqctl set_policy -p <vhost> <name> <pattern> <definition> --apply-to queues` |
| List policies | `rabbitmqctl list_policies -p <vhost>` |
| Export definitions | `rabbitmqctl export_definitions /tmp/definitions.json` |
| Import definitions | `rabbitmqctl import_definitions /tmp/definitions.json` |
| Rotate log files | `rabbitmqctl rotate_logs` |
| Full server report | `rabbitmqctl report` |
| Set memory watermark | `rabbitmqctl set_vm_memory_high_watermark 0.6` |
| Set disk free limit | `rabbitmqctl set_disk_free_limit 1GB` |
| Environment vars | `rabbitmqctl environment` |
| Effective config | `rabbitmq-diagnostics environment` |

## Expected Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| **5672** | AMQP | Client connections (AMQP 0-9-1 / 1.0) |
| **5671** | AMQPS | Client connections with TLS |
| **15672** | HTTP | Management UI and HTTP API |
| **15671** | HTTPS | Management UI with TLS |
| **25672** | Erlang dist | Inter-node communication (clustering) |
| **4369** | EPMD | Erlang port mapper daemon (peer discovery) |
| **35672-35682** | TCP | CLI tools communication with nodes |
| **1883** | MQTT | MQTT clients (plugin: `rabbitmq_mqtt`) |
| **8883** | MQTTS | MQTT clients with TLS |
| **61613** | STOMP | STOMP clients (plugin: `rabbitmq_stomp`) |
| **61614** | STOMPS | STOMP clients with TLS |
| **5552** | Stream | RabbitMQ Stream protocol |
| **5551** | Stream+TLS | RabbitMQ Stream protocol with TLS |
| **15692** | HTTP | Prometheus metrics (plugin: `rabbitmq_prometheus`) |

Verify: `ss -tlnp | grep -E 'beam|epmd'`

Firewall: Expose only 5672/5671 to application networks. Restrict 4369, 25672, 35672-35682 to cluster-internal traffic. Expose 15672 only to admin networks or behind a reverse proxy.

## Health Checks

Staged verification (each step builds on the previous):

```bash
# 1. Runtime responsive
rabbitmq-diagnostics ping

# 2. Application running, no resource alarms
rabbitmq-diagnostics check_running
rabbitmq-diagnostics check_local_alarms

# 3. Listener ports accepting connections
rabbitmq-diagnostics check_port_connectivity

# 4. Virtual hosts operational
rabbitmq-diagnostics check_virtual_hosts

# 5. Cluster connectivity (all nodes reachable)
rabbitmq-diagnostics cluster_status

# 6. Key metrics snapshot
rabbitmqctl status | grep -A5 -E 'memory|disk_free|file_descriptors'
```

For container/orchestrator liveness probes, use `rabbitmq-diagnostics check_port_connectivity` (returns exit code 0 on success). For readiness probes, use `rabbitmq-diagnostics check_local_alarms`.

**Note**: `node_health_check` is deprecated and a no-op in modern versions. Do not use it.

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `guest` user cannot log in remotely | `guest` restricted to localhost by default | Create a new admin user with `rabbitmqctl add_user`; or set `loopback_users = none` in rabbitmq.conf (not recommended for production) |
| Memory alarm triggered, publishers blocked | `vm_memory_high_watermark` exceeded | Check `rabbitmqctl status` for memory breakdown; increase watermark, add RAM, or reduce queue backlog |
| Disk alarm triggered, publishers blocked | Free disk below `disk_free_limit` | Free space in `/var/lib/rabbitmq/`; raise `disk_free_limit` to trigger earlier |
| `Error while waiting for Mnesia tables` | Corrupt Mnesia database or stale cluster state | Stop node, `rabbitmqctl force_boot` then start; or `rabbitmqctl reset` to rejoin cluster as fresh node |
| Network partition detected | Nodes lost contact for >60s (net tick timeout) | Choose partition strategy (`pause_minority` or `autoheal`); manually restart minority-side nodes if using `ignore` mode |
| Node won't rejoin cluster after partition | Stale Mnesia state from split-brain | Stop the node, `rabbitmqctl forget_cluster_node rabbit@stale-node` from a running node, then `rabbitmqctl reset` on the stale node and rejoin |
| `beam.smp` high CPU/memory | Large message backlog, many connections, or queue sync storms | Monitor queue depths; enable `rabbitmq_prometheus`; check for consumers not acking; set `consumer_timeout` |
| TLS handshake failures | Certificate mismatch, expired cert, or wrong CA | `openssl s_client -connect host:5671 -tls1_2`; check `ssl_options.*` in rabbitmq.conf; `rabbitmqctl eval 'ssl:clear_pem_cache().'` after cert rotation |
| Queues stuck in `minority` state | Quorum queue lost majority of replicas | Bring back offline nodes; if permanently lost, `rabbitmq-queues delete_member <queue> <node>` |
| Connection refused on port 5672 | Listener not bound or firewall blocking | `rabbitmq-diagnostics listeners`; check `listeners.tcp.default` in config; `ss -tlnp \| grep 5672` |
| Shovel/federation link down | URI wrong, remote unreachable, or auth failure | `rabbitmqctl shovel_status` / `rabbitmqctl federation_status`; check URIs and credentials |
| File descriptor limit exhausted | Too many connections for OS ulimit | Set `ulimit -n 65536` for rabbitmq user in `/etc/default/rabbitmq-server` or systemd override; verify with `rabbitmqctl status` |

## Pain Points

- **Default `guest` user is localhost-only.** Fresh installs ship with `guest`/`guest` but it only works from 127.0.0.1. Create a real admin user immediately after installation. Relying on `loopback_users = none` in production is a security risk.

- **Distro packages are severely outdated.** Debian/Ubuntu repository versions lag many releases behind and often hit end-of-life. Always use Team RabbitMQ's official apt/yum repos or Docker images.

- **File descriptor limits default to 1024.** The OS default is far too low for a message broker. Set at least 65536 for the `rabbitmq` user via systemd `LimitNOFILE` or `/etc/security/limits.conf`. Failure to do this causes silent connection refusals under load.

- **Classic mirrored queues are removed in 4.0.** They were deprecated in 3.9 and fully removed in 4.0. All new deployments should use quorum queues, which provide better throughput and stronger data safety via Raft consensus. Existing mirrored queues must be migrated.

- **Two-node clusters are strongly discouraged.** Quorum-based features (quorum queues, Raft) need a majority. In a two-node cluster, losing one node means losing quorum. Always deploy 3, 5, or 7 nodes.

- **Erlang cookie mismatch breaks clustering silently.** All cluster nodes and CLI tools must share the same `/var/lib/rabbitmq/.erlang.cookie` value. Cookie files must be mode 600 owned by `rabbitmq`. A mismatch causes cryptic "nodedown" errors.

- **Config changes require a node restart.** Unlike Redis or NGINX, most RabbitMQ config changes (rabbitmq.conf) take effect only after restarting the node. Plan rolling restarts for cluster-wide changes.

- **Partition handling defaults to `ignore`.** The default strategy takes no action during network partitions, risking split-brain. Production clusters should set `cluster_partition_handling = pause_minority` (for racks/AZs) or `autoheal` (for continuity over consistency).

## See Also

- **mosquitto** -- Lightweight MQTT broker; RabbitMQ also supports MQTT via plugin but Mosquitto is purpose-built for IoT
- **redis** -- In-memory data store often used for simple pub/sub and task queues; RabbitMQ provides richer routing and delivery guarantees
- **kafka** -- Distributed event streaming platform; better for high-throughput log/event pipelines where RabbitMQ's routing flexibility isn't needed

## References
See `references/` for:
- `docs.md` -- Official documentation links for every major topic
- `common-patterns.md` -- Vhost/user setup, queue declaration, clustering, quorum queues, shovel, federation, TLS, and monitoring examples
- `rabbitmq.conf.annotated` -- annotated new-style (sysctl) configuration with every directive explained, default values, and guidance on when to change them
