# Environment Profile Reference

This file contains everything needed to discover, read, write, and validate `environment.json`. It is loaded by the `/nominal:preflight` command when building or validating a profile.

## File location

`.claude/nominal/environment.json` in the user's repository.

## Schema conventions

These conventions apply across all Nominal data files.

**Reserved keys.** `_schema_version` records the Nominal plugin version that produced the file. `_discovery_note` is a sibling annotation for any field where discovery was inconclusive; it describes what was looked for and what would help resolve it. All other keys prefixed with `_` are human annotations and are ignored by the plugin.

**Null handling.** Any field may be `null`. A null field means discovery did not find a value or the category does not apply. Null fields are stored in the file (not omitted) so their presence is visible. They are accompanied by a `_discovery_note` sibling when discovery was attempted but inconclusive. During verification runs, null fields are skipped, not flagged as failures.

**Timestamps.** All timestamps are ISO 8601 UTC (e.g. `2026-03-25T14:30:00Z`).

**String arrays vs. objects.** Where a field contains a list of simple names (e.g. dependency references), use a string array. Where entries carry their own attributes, use an array of objects.

## Top-level structure

```json
{
  "_schema_version": "1.0.0",
  "{environment_name}": { /* environment object */ }
}
```

- `_schema_version`: string. Nominal plugin version that produced this file. Used for migration detection.
- `{environment_name}`: One entry per named environment. Key is a short human-readable name (e.g. `"atlas"`, `"prod-web"`, `"homelab-proxmox"`).

When only one environment exists, there is still a single named key. There is no "default" or unnamed mode.

## Environment object

Each named environment contains the following categories. Categories are stored under specific JSON keys; use them exactly as shown.

### Metadata (top-level fields in the environment object)

These fields live directly in the environment object, not in a nested key.

| Field | Type | Purpose |
|-------|------|---------|
| `description` | string or null | Human-readable description. Used in output headers. |
| `first_discovered` | timestamp | When this environment was first profiled. |
| `last_validated` | timestamp | When the most recent validation or refresh completed. |

### 1. Host (`host`)

CIS Controls v8 Control 1, ITIL CMDB CI attributes.

| Field | Type | Purpose |
|-------|------|---------|
| `hostname` | string or null | System hostname as reported by OS. |
| `os_name` | string or null | OS distribution name (e.g. `"Debian"`, `"Ubuntu"`, `"Alpine"`). |
| `os_version` | string or null | OS version string. |
| `architecture` | string or null | CPU architecture (e.g. `"x86_64"`, `"aarch64"`). |
| `kernel_version` | string or null | Kernel version string. |
| `virtualization_type` | string or null | One of: `"bare_metal"`, `"proxmox_lxc"`, `"proxmox_vm"`, `"docker_host"`, `"kubernetes_node"`, `"cloud_vm"`, or a descriptive string. |
| `_discovery_note` | string or null | Notes on ambiguous host detection. |

### 2. Network (`network`)

NIST SP 800-190 Section 3.3, CIS Controls v8 Control 12.

| Field | Type | Purpose |
|-------|------|---------|
| `topology` | string or null | Network layout: `"flat"`, `"vlan_segmented"`, `"cloud_vpc"`, `"hybrid"`, or descriptive string. |
| `private_bridge_or_overlay` | string or null | Name of private bridge or overlay (e.g. `"vmbr1"`, `"docker0"`, `"flannel"`). |
| `private_subnet` | string or null | Subnet CIDR for the private network (e.g. `"10.10.10.0/24"`). |
| `vpn_tool` | string or null | VPN tool in use (e.g. `"WireGuard"`, `"Tailscale"`), or null if none. |
| `firewall_tool` | string or null | Firewall management tool (e.g. `"ufw"`, `"iptables"`, `"nftables"`). |
| `_discovery_note` | string or null | |

### 3. Ingress (`ingress`)

NIST SP 800-215.

| Field | Type | Purpose |
|-------|------|---------|
| `reverse_proxy_tool` | string or null | Tool name (e.g. `"Caddy"`, `"nginx"`, `"Traefik"`, `"HAProxy"`). |
| `config_path` | string or null | Filesystem path to the reverse proxy configuration. |
| `access_model` | object or null | Describes which access tiers exist. |
| `access_model.tiers` | string array | Tier names that exist (e.g. `["public", "auth_gated", "vpn_only"]`). |
| `access_model.description` | string or null | Prose description if the simple list is insufficient. |
| `_discovery_note` | string or null | |

### 4. SSL / Certificates (`ssl`)

Let's Encrypt ACME best practices, CA/Browser Forum.

| Field | Type | Purpose |
|-------|------|---------|
| `cert_tool` | string or null | Certificate management tool (e.g. `"Certbot"`, `"acme.sh"`, `"Caddy"`, `"cloud_acm"`). |
| `config_path` | string or null | Filesystem path to cert tool config or cert storage. |
| `renewal_mechanism` | string or null | How renewal triggers: `"systemd_timer"`, `"cron"`, `"daemon"`, `"managed"`, or descriptive string. |
| `_discovery_note` | string or null | |

### 5. Monitoring (`monitoring`)

Google SRE Four Golden Signals, SRE PRR observability gate.

| Field | Type | Purpose |
|-------|------|---------|
| `metrics_tool` | string or null | Metrics platform (e.g. `"Netdata"`, `"Prometheus"`, `"Datadog"`). |
| `metrics_status_check` | string or null | How to verify metrics tool is actively collecting (URL, service name, command hint). |
| `uptime_tool` | string or null | Uptime/synthetic monitoring tool (e.g. `"Uptime Kuma"`, `"Pingdom"`). |
| `uptime_status_check` | string or null | How to verify uptime tool is running with recent results. |
| `log_aggregation_tool` | string or null | Log aggregation platform (e.g. `"Loki"`, `"Elasticsearch"`), or null if none. |
| `log_status_check` | string or null | How to verify log aggregation is receiving logs. |
| `_discovery_note` | string or null | |

### 6. Backup (`backup`)

ITIL PIR backup verification.

| Field | Type | Purpose |
|-------|------|---------|
| `backup_tool` | string or null | Backup tool (e.g. `"restic"`, `"Borg"`, `"Proxmox Backup Server"`, `"Velero"`). |
| `targets` | string array or null | Backup destinations (e.g. `["/mnt/backup", "s3://bucket-name"]`). |
| `pre_dump_scripts` | string array or null | Scripts that must run before backup (e.g. database dumps). |
| `last_run_check` | string or null | How to determine when the last successful backup ran. |
| `_discovery_note` | string or null | |

### 7. Secrets (`secrets`)

HashiCorp 18-point checklist, OWASP Secrets Management Cheat Sheet.

| Field | Type | Purpose |
|-------|------|---------|
| `approach` | string or null | Management approach: `"env_file"`, `"hashicorp_vault"`, `"cloud_secrets_manager"`, `"docker_secrets"`, or descriptive string. |
| `canonical_location` | string or null | Where secrets live (e.g. `"/opt/stacks/.env"`, `"vault://secret/prod"`). |
| `_discovery_note` | string or null | |

### 8. Security tooling (`security_tooling`)

CIS Controls v8 Control 10, Control 13.

| Field | Type | Purpose |
|-------|------|---------|
| `fim_tool` | string or null | File integrity monitoring tool (e.g. `"AIDE"`, `"rkhunter"`, `"Tripwire"`). |
| `fim_baseline_update_method` | string or null | How to update FIM baseline (e.g. `"aide --update"`, `"rkhunter --propupd"`). |
| `ips_tool` | string or null | Intrusion prevention tool (e.g. `"Fail2ban"`, `"CrowdSec"`). |
| `ips_status_check` | string or null | How to verify IPS is active (service status, jail count). |
| `_discovery_note` | string or null | |

### 9. VCS (`vcs`)

ITIL change record closure.

| Field | Type | Purpose |
|-------|------|---------|
| `tool` | string or null | VCS tool (e.g. `"git"`). |
| `remote` | string or null | Remote repository URL. |
| `config_tracked_paths` | string array or null | Key paths where infrastructure configuration lives. |
| `_discovery_note` | string or null | |

### 10. Services inventory (`services`)

ITIL CMDB, Google SRE PRR, CIS Controls v8 Control 4.

The `services` key holds a flat array of service objects directly. The path is `environment.{name}.services[0].name`, not `environment.{name}.services.services[0].name`.

**Service object fields:**

| Field | Type | Purpose |
|-------|------|---------|
| `name` | string | Human-readable service name. Must be unique within the environment. |
| `role` | string or null | What this service does (e.g. `"password manager"`, `"file sync"`). |
| `host_address` | string or null | IP or hostname where the service runs. |
| `ports` | integer array or null | Port(s) the service listens on. |
| `access_tier` | string or null | Which access tier applies (e.g. `"public"`, `"auth_gated"`, `"vpn_only"`). |
| `dependencies` | string array or null | Names of other services this depends on (references to `name` fields). |
| `health_endpoint` | string or null | URL or command to check service health. |
| `monitoring_collector` | string or null | Which monitoring tool collects data for this service, if different from environment default. |

---

## Discovery model

### Full discovery pass (first run or `/preflight refresh`)

Use available system introspection tools to build the profile. The approach is intelligent, not scripted; adapt to what is available. There is no timeout.

General discovery sequence:
1. **Host:** `uname -a`, `lsb_release -a` or `cat /etc/os-release`, `hostnamectl`, `systemd-detect-virt`
2. **Services:** `systemctl list-units --type=service --state=running`, `ss -tlnp`
3. **Containerization:** `pct list` / `qm list` (Proxmox), `docker ps`, `kubectl get nodes`
4. **Network:** `ip route`, `ip addr`, firewall status (`ufw status`, `iptables -L`, `nft list ruleset`)
5. **Tooling:** Process name and config path detection for reverse proxy, monitoring, backup, cert management, secrets management, security tooling
6. **Service roles and dependencies:** systemd unit files (`After=`, `Requires=` directives), config file analysis

### Profile validation pass (every subsequent `/preflight`)

Streamlined spot-check: hosts reachable, primary services running, reverse proxy responding, monitoring active, firewall active, backup last run within expected window. Runs in seconds to minutes.

### Friction model

Make intelligent decisions and minimize user questions. Do not ask field-by-field. Ask only when:
- The full Post-Discovery Confirmation summary is ready (one structured prompt)
- A structural discrepancy requires a human decision
- An abort is about to execute
- The `/postflight` trigger type needs confirmation

Ambiguous detections are best-guessed, flagged with `_discovery_note`, and included in the summary for user review.

---

## Schema version and migration

The profile carries a `_schema_version` field tied to the Nominal plugin version. When reading a profile, compare the schema version to the current plugin version. If they differ, apply necessary field migrations intelligently before proceeding. Minor version differences are handled silently; major structural changes prompt a re-validation pass.

---

## Post-Discovery Confirmation (Template 0)

After the Mission Survey completes and before writing `environment.json`, present this structured summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀  NOMINAL — MISSION SURVEY COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Mission parameters discovered. Here's what was found:

HOST
  OS:               {os name and version}
  Virtualization:   {type or "bare metal"}
  Hostname:         {hostname}

NETWORK
  Topology:         {flat / segmented / cloud}
  Firewall:         {tool name}
  VPN:              {tool name or "none detected"}

INGRESS
  Reverse proxy:    {tool name}
  Access model:     {tiers or description}

TOOLING
  SSL/certs:        {tool name}
  Monitoring:       {metrics tool} / {uptime tool} / {logs tool or "none"}
  Backup:           {tool name} → {targets}
  Secrets:          {approach and canonical location}
  VCS:              {tool and remote}

SERVICES ({count} detected)
  {name}  {role}  {address:port}  {access tier}
  ...

UNRESOLVED ({count} fields where discovery was inconclusive)
  ⚠️  {field}: {what was looked for, what would help}
  ...

Mission parameters will be written to:
  .claude/nominal/environment.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Present via AskUserQuestion with options:
- **Confirm and continue** — write environment.json and proceed to go/no-go poll
- **Get full details** — write a detailed markdown summary of all fields before confirming
- **Correct something** — user describes what is wrong; update and re-present

If unresolved fields exist, note them but do not block. Store as `null` with `_discovery_note`.

## Refresh Confirmation (Template 0b)

After `/preflight refresh` completes a full re-discovery on an existing profile, show a diff view:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚀  NOMINAL — MISSION SURVEY COMPLETE (REFRESH)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Environment  {name}
Previous parameters dated: {last validated date}

CHANGES DETECTED
  ✅  {category}: no change
  ⚠️  {category}: CHANGED
      Was:  {previous value}
      Now:  {newly discovered value}
  ℹ️  {category}: NEW (not previously recorded)
      Now:  {newly discovered value}

UNCHANGED ({count} categories confirmed same)

UNRESOLVED ({count} fields)
  ⚠️  {field}: {discovery note}

Updated parameters will be written to:
  .claude/nominal/environment.json

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Present via AskUserQuestion with options:
- **Confirm — apply changes** — write updated environment.json and proceed
- **Get full details** — write a complete before/after comparison
- **Discard** — keep existing profile unchanged, exit refresh
