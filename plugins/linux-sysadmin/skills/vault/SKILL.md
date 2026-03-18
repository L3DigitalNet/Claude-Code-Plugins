---
name: vault
description: >
  HashiCorp Vault secrets management: server deployment, seal/unseal operations,
  secret engines, authentication methods, policies, dynamic credentials, PKI,
  transit encryption, audit logging, and high availability configuration.
  MUST consult when installing, configuring, or troubleshooting vault.
triggerPhrases:
  - "vault"
  - "HashiCorp Vault"
  - "secrets management"
  - "vault server"
  - "vault seal"
  - "vault unseal"
  - "vault token"
  - "vault policy"
  - "vault secret"
  - "vault auth"
  - "dynamic credentials"
  - "vault transit"
  - "vault PKI"
  - "vault agent"
globs:
  - "**/vault.hcl"
  - "**/vault.json"
  - "**/vault-policy*.hcl"
last_verified: "2026-03"
---

## Identity

- **Unit**: `vault.service`
- **Config**: `/etc/vault.d/vault.hcl` (package install) or custom path
- **Logs**: `journalctl -u vault`, or audit device output (file, syslog, socket)
- **Data dir**: `/opt/vault/data/` (Raft integrated storage default)
- **API port**: 8200/tcp (also serves the web UI when `ui = true`)
- **Cluster port**: 8201/tcp (node-to-node Raft and request forwarding)
- **Install**: `apt install vault` / `dnf install vault` (after adding the HashiCorp repo), or download from https://releases.hashicorp.com/vault
- **License**: BSL 1.1 (source-available) since v1.15 (Aug 2023); internal use is unrestricted, but hosting Vault as a competing managed service is not permitted. Enterprise features (seal wrapping, replication, namespaces, Sentinel) require a paid license.

## Quick Start

```bash
# 1. Install (Debian/Ubuntu — add HashiCorp repo first)
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vault

# 2. Start a dev server (in-memory, auto-unsealed, NOT for production)
vault server -dev
# Dev server prints the root token and unseal key to stdout.
# In another terminal:
export VAULT_ADDR='http://127.0.0.1:8200'

# 3. Write a secret
vault kv put secret/myapp username="admin" password="s3cr3t"

# 4. Read it back
vault kv get secret/myapp
```

## Key Operations

| Task | Command |
|------|---------|
| Server status | `vault status` |
| Initialize (first time) | `vault operator init` |
| Unseal (provide threshold keys) | `vault operator unseal` |
| Seal (emergency) | `vault operator seal` |
| Login (token) | `vault login <token>` |
| Login (userpass) | `vault login -method=userpass username=admin` |
| Login (AppRole) | `vault write auth/approle/login role_id=... secret_id=...` |
| Write KV secret | `vault kv put secret/path key=value` |
| Read KV secret | `vault kv get secret/path` |
| Delete KV secret (soft) | `vault kv delete secret/path` |
| Destroy KV version (permanent) | `vault kv destroy -versions=1 secret/path` |
| List secrets | `vault kv list secret/` |
| Enable secrets engine | `vault secrets enable -path=kv kv-v2` |
| Enable auth method | `vault auth enable approle` |
| Write policy | `vault policy write my-policy my-policy.hcl` |
| List policies | `vault policy list` |
| Read policy | `vault policy read my-policy` |
| Enable audit device | `vault audit enable file file_path=/var/log/vault_audit.log` |
| List audit devices | `vault audit list` |
| Create token | `vault token create -policy=my-policy -ttl=1h` |
| Revoke token | `vault token revoke <token>` |
| Revoke lease | `vault lease revoke <lease-id>` |
| Raft cluster peers | `vault operator raft list-peers` |
| Raft snapshot | `vault operator raft snapshot save backup.snap` |
| Raft snapshot restore | `vault operator raft snapshot restore backup.snap` |

## Expected Ports

- **8200/tcp** -- API, CLI, and web UI. Verify: `ss -tlnp | grep :8200`
- **8201/tcp** -- cluster traffic (Raft replication, request forwarding between nodes). Only needed in multi-node clusters.

## Health Checks

1. `vault status` -- shows seal status, HA mode, Raft leader
2. `curl -s http://127.0.0.1:8200/v1/sys/health` -- returns JSON; HTTP 200 = active + unsealed, 429 = standby, 472 = DR secondary, 473 = performance standby, 501 = not initialized, 503 = sealed
3. `vault operator raft list-peers` -- confirms all Raft voters are present and one is leader

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Vault is sealed` after restart | Shamir unseal keys not provided | Run `vault operator unseal` with the required threshold of keys; consider auto-unseal for unattended restarts |
| `permission denied` on secret path | Token lacks required policy capabilities | Check `vault token lookup`; verify the attached policy grants the needed capabilities on the path |
| `token expired` / `invalid token` | Token TTL elapsed or token revoked | Re-authenticate; increase `token_ttl` / `token_max_ttl` on the auth role, or use Vault Agent for automatic renewal |
| `500 Internal Server Error` from API | Vault sealed, storage unavailable, or misconfigured backend | `vault status` to check seal state; `journalctl -u vault` for backend errors |
| `* server is not yet initialized` | `vault operator init` was never run | Run `vault operator init -key-shares=5 -key-threshold=3` (or your desired split) |
| Raft leader election loops | Clock skew between nodes, or network partitions | Sync clocks with NTP/chrony; check inter-node connectivity on port 8201 |
| Auto-unseal fails on startup | KMS key deleted/disabled, or IAM permissions revoked | Check `journalctl -u vault` for the seal provider error; verify KMS key status and credentials |
| `local node not found in raft configuration` | Node ID changed or data dir was wiped | Re-join with `vault operator raft join <leader-addr>` |
| `no route to host` on cluster join | Firewall blocking 8201, or wrong `cluster_addr` | Open 8201 between nodes; verify `cluster_addr` in config is a routable IP (not 127.0.0.1) |

## Pain Points

- **Unseal ceremony**: Shamir-sealed Vault requires manual key entry on every restart. For automated environments, configure auto-unseal with AWS KMS, GCP Cloud KMS, Azure Key Vault, or another Vault's Transit engine. Recovery keys generated during auto-unseal init cannot decrypt the root key directly; if the KMS key is lost, the cluster is unrecoverable.
- **Dev mode vs production**: `vault server -dev` is in-memory, auto-unsealed, HTTP-only, and uses a known root token. None of these properties carry over to production. The gap between dev and production config is large; plan for TLS, persistent storage, and unseal automation from the start.
- **Token TTL and renewal**: Every token has a TTL and a max TTL. Forgetting to renew a long-running service's token causes silent auth failures. Vault Agent with auto-auth handles this automatically and is the recommended approach for applications.
- **Storage backend choice**: Raft integrated storage is the recommended backend (replaces Consul for HA). Consul storage is deprecated as of Vault 1.18. File backend does not support HA. Migrate early if still on Consul.
- **Auto-unseal adds a hard dependency**: If the KMS or transit unseal provider is unreachable, Vault cannot start. Seal HA (Vault 1.16+, Enterprise) lets you configure multiple seal providers for redundancy.
- **KV v1 vs v2**: The dev server enables KV v2 at `secret/` by default. Production installs may have KV v1 or no engine mounted. KV v2 adds versioning but changes the API path structure (`data/`, `metadata/`, `delete/`, `undelete/`, `destroy/` subpaths). Policies must account for these subpaths.

## See Also

- `age` -- file encryption (simpler alternative for static secrets at rest)
- `openssl-cli` -- certificate inspection and manual PKI operations
- `step-ca` -- lightweight private CA (alternative to Vault PKI for certificate-only use cases)
- `certbot` -- ACME certificate management (public CA; Vault PKI is for internal CA)
- **keycloak** — identity provider; Vault can use OIDC from Keycloak for auth
- **consul** — service discovery and health checks; often deployed alongside Vault

## References

See `references/` for:
- `docs.md` -- verified official documentation links
- `vault.hcl.annotated` -- annotated production server configuration (listener, storage, seal, telemetry)
- `common-patterns.md` -- KV v2 CRUD, dynamic DB credentials, PKI certificate issuance, transit encrypt/decrypt, AppRole auth, policy examples, auto-unseal with AWS KMS and Transit
