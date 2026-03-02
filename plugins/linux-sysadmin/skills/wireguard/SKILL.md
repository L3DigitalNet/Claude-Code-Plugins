---
name: wireguard
description: >
  WireGuard VPN — key generation, peer configuration, server and client setup,
  routing, NAT/masquerading, troubleshooting, and wg-quick management. Triggers
  on: wireguard, wg, wg-quick, vpn tunnel, peer config, AllowedIPs,
  wireguard server.
globs:
  - "**/wireguard/*.conf"
  - "**/wg*.conf"
---

## Identity
- **Kernel module**: `wireguard` (built into kernel 5.6+; backported to 5.4 via DKMS)
- **Config**: `/etc/wireguard/wg0.conf` (interface name matches filename: `wg0`)
- **Manage via**: `wg-quick up wg0` / `wg-quick down wg0` / `wg` (status and stats)
- **Unit**: `wg-quick@wg0.service` (systemd unit for persistent operation)
- **Install**: `apt install wireguard` / `dnf install wireguard-tools` (kernel module usually pre-included on modern distros)

## Key Generation

```bash
# Generate server keys
wg genkey | tee server_private.key | wg pubkey > server_public.key

# Generate client keys
wg genkey | tee client_private.key | wg pubkey > client_public.key

# Optional: pre-shared key (adds post-quantum resistance layer)
wg genpsk > preshared.key

chmod 600 server_private.key client_private.key preshared.key
```

Private keys never leave the host they were generated on. Public keys are shared freely. Pre-shared keys (PSKs) are symmetric secrets shared between exactly two peers — one PSK per peer pair, stored in both configs.

## Key Operations

| Goal | Command |
|------|---------|
| Bring interface up | `sudo wg-quick up wg0` |
| Bring interface down | `sudo wg-quick down wg0` |
| Enable on boot | `sudo systemctl enable wg-quick@wg0` |
| Start now + on boot | `sudo systemctl enable --now wg-quick@wg0` |
| Show all interface status | `sudo wg show` |
| Show specific interface | `sudo wg show wg0` |
| Show current running config | `sudo wg showconf wg0` |
| Check handshake timestamps | `sudo wg show wg0 latest-handshakes` |
| Show transfer stats | `sudo wg show wg0 transfer` |
| Add peer at runtime | `sudo wg set wg0 peer <pubkey> allowed-ips 10.0.0.3/32` |
| Save runtime changes to file | `sudo wg-quick save wg0` |
| Reload config without down/up | `sudo wg syncconf wg0 <(wg-quick strip wg0)` |

## Expected Ports
- **51820/udp** — default; set via `ListenPort` in `[Interface]`
- WireGuard is UDP-only. TCP is not supported.
- Verify listening: `ss -ulnp | grep wireguard`
- Allow through firewall: `ufw allow 51820/udp` or `firewall-cmd --add-port=51820/udp --permanent`

## Health Checks

1. `sudo wg show` — lists all interfaces and peers; confirms the interface is up
2. `sudo wg show wg0 latest-handshakes` — epoch timestamps; any value > 0 means the peer has connected; values more than ~3 minutes in the past mean the connection is idle or broken
3. Ping across the tunnel (e.g., `ping 10.0.0.2` from the server to the first client's tunnel IP)
4. `journalctl -u wg-quick@wg0 -n 50` — startup errors, PostUp script failures
5. `sudo wg show wg0 transfer` — bytes sent/received; zero RX means no traffic is returning

## Common Failures

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `wg show` shows peer but no handshake | Firewall blocking UDP 51820 on server, or wrong public key pasted | Open UDP port on server; verify keys match exactly |
| Handshake occurs but no traffic flows | `ip_forward` disabled on server; PostUp NAT rule missing | `sysctl -w net.ipv4.ip_forward=1`; verify PostUp iptables rule |
| Handshake times out repeatedly | Client endpoint wrong (wrong IP or port) | Confirm server's public IP and ListenPort; check `Endpoint` line |
| DNS leaks outside the tunnel | DNS server not set in client `[Interface]`, or DNS not reachable via tunnel | Set `DNS = <server-tunnel-ip>` in client config; run DNS server on server |
| Mobile client drops after idle | NAT table on router expires UDP mapping | Add `PersistentKeepalive = 25` to client's `[Peer]` (server entry) |
| Split tunnel routes wrong traffic | AllowedIPs too broad or overlapping between peers | AllowedIPs is a routing table — each IP range can appear in only one peer |
| `wg-quick: Permission denied` on startup | `wg0.conf` permissions are not 600 | `chmod 600 /etc/wireguard/wg0.conf` |
| `RTNETLINK answers: Operation not supported` | WireGuard kernel module not loaded | `modprobe wireguard`; on older kernels install `wireguard-dkms` |

## Pain Points

- **AllowedIPs is a routing table**: Each peer's `AllowedIPs` determines which destination IPs get routed through that peer's tunnel. `0.0.0.0/0, ::/0` = all traffic (full VPN). Specific subnets = split tunnel. Common mistake: overlapping `AllowedIPs` between two peers — WireGuard will accept the config but routing becomes undefined.

- **No auto-discovery**: Every peer must be explicitly added to every other peer's config. There is no central auth server or certificate authority. Adding a new client means editing the server config and reloading it.

- **UDP only**: WireGuard strictly uses UDP. If a network blocks all UDP (restrictive hotel/corporate firewall), WireGuard will not work. Unlike OpenVPN, there is no TCP fallback.

- **Handshake timeout = dead connection**: `wg show` shows `latest handshake` as a Unix timestamp. If it is more than 3 minutes ago, the tunnel is likely broken. `PersistentKeepalive = 25` sends a keepalive every 25 seconds to maintain NAT mappings and detect dead connections faster.

- **ip_forward required on server**: For the server to route traffic between peers (or to the internet), `net.ipv4.ip_forward = 1` must be active. Set persistently in `/etc/sysctl.d/99-wireguard.conf` with `net.ipv4.ip_forward = 1`; activate with `sysctl -p`.

- **File permissions**: `/etc/wireguard/wg0.conf` must be mode 600 (owner-read-only). `wg-quick` warns and may refuse to start if permissions are too open. The file contains the private key in plaintext.

- **Runtime changes vs. file changes**: `wg set` modifies the running interface immediately but does not persist to `wg0.conf`. Use `wg-quick save wg0` to write runtime state back to the file, or use `wg syncconf wg0 <(wg-quick strip wg0)` to apply file changes without taking the interface down.

## References
See `references/` for:
- `wg0.conf.annotated` — fully annotated server and client config examples
- `setup-patterns.md` — step-by-step guides for common deployment scenarios
- `docs.md` — official documentation and community resources
