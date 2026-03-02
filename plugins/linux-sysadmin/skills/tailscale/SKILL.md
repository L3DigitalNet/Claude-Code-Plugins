---
name: tailscale
description: >
  Third-person description with trigger phrases. Tailscale zero-config mesh
  VPN — installation, authentication, exit nodes, subnet routing, MagicDNS,
  ACLs, Taildrop, and troubleshooting. Triggers on: tailscale, tailnet,
  magic dns, exit node, subnet router, tailscale up, ts CLI.
---

## Identity
- **Unit**: `tailscaled.service`
- **CLI**: `tailscale` (client commands) + `tailscaled` (daemon)
- **Config**: `/etc/default/tailscaled` (daemon flags); ACLs managed via Tailscale admin console (HuJSON)
- **State**: `/var/lib/tailscale/`
- **Logs**: `journalctl -u tailscaled`
- **Install**: `curl -fsSL https://tailscale.com/install.sh | sh` (review before running) or package repo at `pkgs.tailscale.com`

## Key Operations

| Goal | Command |
|------|---------|
| Authenticate / bring up | `tailscale up` |
| Authenticate headless | `tailscale up --authkey=<key>` |
| Check status | `tailscale status` |
| Show Tailscale IP | `tailscale ip -4` |
| Ping a peer | `tailscale ping <peer-name-or-ip>` |
| Bring interface down | `tailscale down` |
| Deauthenticate device | `tailscale logout` |
| Send file (Taildrop) | `tailscale file cp <file> <peer>:` |
| SSH to peer | `tailscale ssh <peer>` |
| Set exit node | `tailscale set --exit-node=<peer-name>` |
| Clear exit node | `tailscale set --exit-node=` |
| Advertise as exit node | `tailscale up --advertise-exit-node` |
| Advertise subnet routes | `tailscale up --advertise-routes=192.168.1.0/24` |
| Accept routes from peers | `tailscale up --accept-routes` |
| Disable MagicDNS | `tailscale up --accept-dns=false` |
| Re-enable MagicDNS | `tailscale up --accept-dns=true` |
| Check for updates | `tailscale update --check` |
| Apply update | `tailscale update` |
| Show version | `tailscale version` |

## Expected State
- `tailscale status` shows self and connected peers
- `tailscale ip` returns a `100.x.x.x` address (Tailscale's CGNAT range: `100.64.0.0/10`)
- Interface `tailscale0` is present in `ip link show`

## Health Checks
1. `systemctl is-active tailscaled` → `active`
2. `tailscale status` → shows self entry and peer list
3. `tailscale ping <peer>` → `pong from <peer> (<ip>) via <relay/direct> in Xms`
4. `tailscale ip -4` → returns a `100.x.x.x` address

## Common Failures

| Symptom | Likely cause | Check / Fix |
|---------|-------------|-------------|
| `tailscale: command not found` or daemon not running | Not installed or `tailscaled` stopped | `systemctl start tailscaled`; reinstall if needed |
| `tailscale status` shows "NeedsLogin" | Device not authenticated | `tailscale up` and complete browser auth, or use `--authkey` |
| MagicDNS names not resolving (`<device>.ts.net`) | MagicDNS disabled or `accept-dns=false` | `tailscale up --accept-dns=true`; check admin console DNS settings |
| Subnet routes not reachable | IP forwarding disabled, routes not approved, or clients not accepting | Enable `net.ipv4.ip_forward`; approve routes in admin console; run `tailscale up --accept-routes` on clients |
| Exit node not routing traffic | Exit node not approved or client not selecting it | Approve in admin console; `tailscale set --exit-node=<name>` on client |
| UDP 41641 blocked by firewall | Firewall blocking Tailscale's data plane port | Open UDP 41641; Tailscale falls back to DERP relay but performance degrades |
| Device shows as expired | Auth key or session expired | `tailscale up --force-reauth` or re-authenticate via admin console |

## Pain Points

- **Subnet routing requires three steps**: The server advertises (`tailscale up --advertise-routes=192.168.1.0/24`), an admin approves the routes in the admin console, and clients enable `tailscale up --accept-routes`. All three must be true for routing to work.

- **Exit node requires three steps**: The device advertises (`--advertise-exit-node`), an admin approves it in the console, and clients select it (`tailscale set --exit-node=<name>`). Missing any step means no traffic is rerouted.

- **`ip_forward` is required for subnet routing and exit nodes**: The advertising device must have IP forwarding enabled.
  ```bash
  echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  ```

- **MagicDNS**: Tailscale assigns `<device>.<tailnet>.ts.net` names to each device. Split DNS (forwarding only tailnet names through Tailscale) is configurable in the admin console under DNS settings. Disabling MagicDNS entirely (`--accept-dns=false`) is the escape hatch if Tailscale's DNS overrides conflict with local resolver setup.

- **Tailscale SSH**: Tailscale can manage SSH access without a running `sshd`, using Tailscale identity for authentication. Enable with `tailscale up --ssh`. SSH keys and `authorized_keys` are not involved — access is governed by ACLs in the admin console. This is additive: existing `sshd` continues to work.

- **CGNAT range conflict**: Tailscale uses `100.64.0.0/10`. This range is also used by some ISPs for carrier-grade NAT and may conflict with other VPNs (e.g., WireGuard tunnels, OpenVPN). If there is a conflict, check the Tailscale docs for custom address range options (available on paid plans).

- **Funnel**: `tailscale funnel 443` exposes a local port on the public internet via Tailscale's infrastructure, reachable at `https://<device>.<tailnet>.ts.net`. For development and testing only — not intended for production traffic. Must be enabled per-device in the admin console.

- **`tailscale up` rewrites flags**: Running `tailscale up` with a subset of flags resets unspecified flags to defaults. Always pass all desired flags together, or use `tailscale set` for individual flag changes without resetting others.

## References
See `references/` for:
- `configuration.md` — `tailscale up` flags, daemon config, ACL structure, and setup patterns
- `docs.md` — official documentation links
