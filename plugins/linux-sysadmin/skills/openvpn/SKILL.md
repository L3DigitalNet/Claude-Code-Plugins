---
name: openvpn
description: >
  OpenVPN server and client administration: PKI setup with Easy-RSA, server
  configuration, client config generation, routing, troubleshooting, and
  certificate management. Triggers on: openvpn, ovpn, easy-rsa, PKI, VPN
  server, openvpn config, .ovpn file.
globs:
  - "**/*.ovpn"
  - "**/openvpn/**/*.conf"
---

## Identity
- **Unit**: `openvpn@server.service` (the "server" part matches the config filename, e.g. `/etc/openvpn/server/server.conf` → `openvpn@server`)
- **Config**: `/etc/openvpn/server/server.conf` (server), `/etc/openvpn/client/` (client configs)
- **PKI (Easy-RSA)**: `/etc/easy-rsa/` or `/usr/share/easy-rsa/` depending on distro
- **Logs**: `journalctl -u openvpn@server`, `/var/log/openvpn/` (if `log-append` is set)
- **Distro install**: `apt install openvpn easy-rsa` / `dnf install openvpn easy-rsa`

## Key Operations

| Operation | Command |
|-----------|---------|
| Start / stop / restart | `systemctl start\|stop\|restart openvpn@server` |
| Check status | `systemctl status openvpn@server` |
| Follow logs | `journalctl -fu openvpn@server` |
| Initialize PKI | `cd /etc/easy-rsa && easyrsa init-pki` |
| Build CA | `easyrsa build-ca` (prompts for passphrase and CN) |
| Generate server cert | `easyrsa build-server-full server nopass` |
| Generate client cert | `easyrsa build-client-full client1 nopass` |
| Revoke client cert | `easyrsa revoke client1` |
| Regenerate CRL | `easyrsa gen-crl` (copy result to `/etc/openvpn/server/crl.pem`) |
| Generate DH params | `easyrsa gen-dh` (slow; prefer `dh none` + ECDH instead) |
| Generate TLS auth key | `openvpn --genkey secret /etc/openvpn/server/ta.key` |
| Show connected clients | Query management interface or `grep "CLIENT_LIST" /etc/openvpn/server/openvpn-status.log` |
| Reload config | `systemctl reload openvpn@server` (re-reads config without dropping connections) |

## Expected Ports
- **1194/udp** — default; preferred for performance
- **443/tcp** — common alternative to bypass restrictive firewalls
- **127.0.0.1:1194** (or custom) — management interface, if enabled
- Verify: `ss -ulnp | grep openvpn` (UDP) or `ss -tlnp | grep openvpn` (TCP)
- Firewall: `ufw allow 1194/udp` or `firewall-cmd --add-port=1194/udp --permanent`

## Health Checks
1. `systemctl is-active openvpn@server` → `active`
2. `sudo journalctl -u openvpn@server | grep "Initialization Sequence Completed"` → must be present
3. `ip addr show tun0` → tun0 interface exists with an IP in the VPN subnet
4. Client can ping the server's VPN IP (e.g. `ping 10.8.0.1` from a connected client)

## Common Failures

| Symptom | Likely cause | Check / Fix |
|---------|-------------|-------------|
| `TLS handshake failed` | Wrong `tls-auth` key direction or mismatched key | Server uses `tls-auth ta.key 0`; client must use `tls-auth ta.key 1`. Verify both sides use the same `ta.key` file. |
| `VERIFY ERROR: depth=0, error=certificate verify failed` | CN mismatch, expired cert, or revoked cert | Check `easyrsa show-cert <name>`; confirm server's `verify-x509-name` matches the cert CN |
| Traffic not routing through VPN | `ip_forward` disabled or missing NAT rule | `sysctl net.ipv4.ip_forward` must be `1`; check masquerade rule: `iptables -t nat -L POSTROUTING` |
| `Cannot open TUN/TAP dev /dev/net/tun` | TUN kernel module not loaded | `modprobe tun`; add `tun` to `/etc/modules` for persistence |
| All clients rejected (including non-revoked) | CRL has expired | Run `easyrsa gen-crl`, copy to `/etc/openvpn/server/crl.pem`, restart service |
| `Certificate date/time check failed` | Client clock is wrong | Check `date` on both sides; NTP must be running (`systemctl status systemd-timesyncd`) |
| `AUTH_FAILED` | Wrong credentials (if using `auth-user-pass`) or cert mismatch | Verify client cert CN and CA chain match server's CA |
| Service starts but clients cannot reach internet | Missing NAT masquerade or wrong interface name | `iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE`; replace `eth0` with actual WAN interface |

## Pain Points
- **Easy-RSA vs manual PKI**: Always use Easy-RSA. Manual `openssl` PKI is error-prone and Easy-RSA handles the required X.509 extension fields (keyUsage, extendedKeyUsage) correctly for OpenVPN.
- **TLS auth direction**: `tls-auth ta.key 0` on server, `tls-auth ta.key 1` on client. Wrong direction causes a silent TLS handshake failure with no useful error message — this is the most common misconfiguration.
- **CRL expiry**: Revocation lists have their own expiry date. When the CRL expires, OpenVPN rejects ALL clients — not just revoked ones. Renew regularly with `easyrsa gen-crl` and automate it with a cron job.
- **DH parameters**: Generating `dhparam 2048` takes minutes on slow hardware. Use `dh none` + `ecdh-curve prime256v1` instead for faster setup and better forward secrecy. Only use DH params if you need compatibility with very old OpenVPN clients.
- **ip_forward + NAT**: Same requirement as WireGuard. The server needs `net.ipv4.ip_forward = 1` in `/etc/sysctl.d/` and a NAT masquerade rule on the WAN interface. Without both, clients connect but cannot reach the internet.
- **UDP vs TCP**: UDP is faster and handles packet loss correctly. TCP 443 bypasses more firewalls but creates TCP-over-TCP meltdown under packet loss: the outer TCP retransmits before the inner TCP can recover, creating cascading slowdowns. Never choose TCP without a specific firewall bypass requirement.
- **Client config distribution**: `.ovpn` inline files embed the private key in plaintext. Treat them like passwords. Deliver over SFTP or a secure secrets manager — never email.
- **`tls-crypt` vs `tls-auth`**: `tls-crypt` (OpenVPN 2.4+) both authenticates and encrypts the TLS control channel, preventing even unauthenticated clients from triggering the TLS handshake. Prefer `tls-crypt` for new deployments.

## References
See `references/` for:
- `server.conf.annotated` — full server config with every directive explained
- `setup-patterns.md` — step-by-step: server setup, client generation, revocation, full/split tunnel
- `docs.md` — official documentation and community links
