# WireGuard Setup Patterns

Step-by-step guides for common WireGuard deployment scenarios. All commands
assume Debian/Ubuntu unless noted; substitute `dnf` for `apt` on RHEL/Fedora.

---

## 1. Server Setup

A fresh WireGuard server: single host with a stable public IP that peers connect to.

**Enable IP forwarding** (required for routing between peers or to the internet):

```bash
# Apply immediately (does not survive reboot)
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -w net.ipv6.conf.all.forwarding=1

# Persist across reboots
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-wireguard.conf
echo "net.ipv6.conf.all.forwarding = 1" | sudo tee -a /etc/sysctl.d/99-wireguard.conf
sudo sysctl -p /etc/sysctl.d/99-wireguard.conf
```

**Install WireGuard**:

```bash
sudo apt update && sudo apt install wireguard
```

**Generate server keys**:

```bash
cd /etc/wireguard
sudo wg genkey | sudo tee server_private.key | sudo wg pubkey | sudo tee server_public.key
sudo chmod 600 server_private.key
```

**Write server config** — replace `<server-private-key>` with the contents of `server_private.key`
and `ens3` with the name of your actual outbound network interface (`ip route | grep default`):

```ini
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <server-private-key>
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ens3 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ens3 -j MASQUERADE
```

```bash
sudo chmod 600 /etc/wireguard/wg0.conf
```

**Open firewall port**:

```bash
# ufw (Ubuntu/Debian)
sudo ufw allow 51820/udp

# firewalld (RHEL/Fedora/Rocky)
sudo firewall-cmd --add-port=51820/udp --permanent
sudo firewall-cmd --reload
```

**Enable and start the service**:

```bash
sudo systemctl enable --now wg-quick@wg0
sudo wg show   # should show wg0 interface with no peers yet
```

---

## 2. Add a Peer (Client)

Repeat for each new client. Keys are generated on the client machine.

**On the client — generate keys**:

```bash
# Can be done anywhere; keys are just strings
wg genkey | tee client_private.key | wg pubkey > client_public.key
wg genpsk > preshared.key   # optional
chmod 600 client_private.key preshared.key
```

**On the server — add the [Peer] block**:

```bash
# Append to /etc/wireguard/wg0.conf
sudo tee -a /etc/wireguard/wg0.conf <<EOF

# client-laptop (alice)
[Peer]
PublicKey = <client-public-key>
PresharedKey = <preshared-key>
AllowedIPs = 10.0.0.2/32
EOF
```

**Reload server config without dropping existing connections**:

```bash
sudo wg syncconf wg0 <(sudo wg-quick strip wg0)
# wg-quick strip removes PostUp/PostDown lines that wg syncconf cannot handle
```

**On the client — write config**:

```ini
# /etc/wireguard/wg0.conf  (or import into a WireGuard app as a QR/file)
[Interface]
Address = 10.0.0.2/32
PrivateKey = <client-private-key>
DNS = 10.0.0.1

[Peer]
PublicKey = <server-public-key>
PresharedKey = <preshared-key>
Endpoint = <server-public-ip>:51820
AllowedIPs = 10.0.0.0/24
PersistentKeepalive = 25
```

**Bring up the client**:

```bash
sudo wg-quick up wg0
ping 10.0.0.1   # should reach the server's tunnel IP
```

---

## 3. Full Tunnel (All Traffic Through VPN)

Route all client internet traffic through the VPN server. Requires NAT masquerading
on the server (already covered in pattern 1 PostUp rules).

**Server config** — no change from pattern 1 if PostUp masquerade rules are present.

Verify ip_forward is active:

```bash
sysctl net.ipv4.ip_forward   # should print 1
```

**Client config** — change `AllowedIPs` to catch all traffic:

```ini
[Peer]
PublicKey = <server-public-key>
Endpoint = <server-public-ip>:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
```

The `0.0.0.0/0` route would normally also capture the server's public IP, creating a
routing loop. `wg-quick` automatically handles this by injecting a host route (`/32`) for
the server's endpoint IP via the default gateway before bringing the tunnel up. Do not
add this route manually.

**Verify no leak**:

```bash
# With tunnel up — should show the server's public IP, not your ISP's
curl https://ifconfig.me

# DNS leak check
dig +short myip.opendns.com @resolver1.opendns.com
```

---

## 4. Split Tunnel

Only route specific subnets through the VPN; all other traffic uses the local internet
connection directly. The server config is identical to pattern 1.

**Client `AllowedIPs`** — list only the subnets that should go through the tunnel:

```ini
[Peer]
PublicKey = <server-public-key>
Endpoint = <server-public-ip>:51820
# Route only the VPN subnet and a corporate LAN:
AllowedIPs = 10.0.0.0/24, 192.168.10.0/24
PersistentKeepalive = 25
```

No masquerade PostUp is needed on the server for pure split-tunnel (the client talks
to hosts on the server's local network, not to the internet via the server). Add
masquerade only if clients also need to reach the internet through the server.

Use the [AllowedIPs calculator](https://www.procustodibus.com/blog/2021/03/wireguard-allowedips-calculator/)
to derive the exact CIDR list for "everything except X" scenarios (e.g., exclude your
ISP's DNS from the tunnel).

---

## 5. Road Warrior (Mobile Clients)

Mobile devices (phones, laptops on untrusted networks) that roam between networks.
Key concerns: NAT traversal, DNS privacy, and quick reconnect on network changes.

**Server side** — same as pattern 1. Consider:

```bash
# If clients roam to networks with restrictive firewalls that block unusual UDP ports,
# try port 443 or 53 (UDP) as ListenPort — less likely to be blocked.
# Only works if nothing else on the server uses those ports.
```

**Client config for a phone**:

```ini
[Interface]
Address = 10.0.0.5/32
PrivateKey = <phone-private-key>
# Route DNS through the tunnel to prevent leaks on untrusted networks
DNS = 10.0.0.1

[Peer]
PublicKey = <server-public-key>
PresharedKey = <preshared-key>
Endpoint = <server-public-ip>:51820
# Full tunnel: all traffic goes through VPN (recommended for road warrior)
AllowedIPs = 0.0.0.0/0, ::/0
# Keepalive prevents NAT tables from dropping idle connections;
# essential for mobile clients where data may be idle for minutes
PersistentKeepalive = 25
```

**Generate QR code for mobile import** (install `qrencode`):

```bash
sudo apt install qrencode
# Print the client config as a QR code in the terminal
qrencode -t ansiutf8 < /path/to/client-phone.conf
# Or write to a PNG (scan with WireGuard mobile app)
qrencode -t png -o client-phone.png < /path/to/client-phone.conf
```

---

## 6. Site-to-Site

Connect two separate networks so hosts on each side can reach the other without
individual client VPN configs. Both endpoints act as peers to each other.

**Topology**:

```
Site A LAN: 192.168.1.0/24    Site B LAN: 192.168.2.0/24
Server A (public IP: 1.2.3.4) ←→ Server B (public IP: 5.6.7.8)
VPN IP: 10.10.0.1/30              VPN IP: 10.10.0.2/30
```

**Server A config**:

```ini
[Interface]
Address = 10.10.0.1/30
ListenPort = 51820
PrivateKey = <server-a-private-key>
# Enable IP forwarding (sysctl net.ipv4.ip_forward=1 separately)
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT

[Peer]
# Server B
PublicKey = <server-b-public-key>
Endpoint = 5.6.7.8:51820
# Route Site B's LAN AND Server B's tunnel IP through this peer
AllowedIPs = 10.10.0.2/32, 192.168.2.0/24
PersistentKeepalive = 25
```

**Server B config**:

```ini
[Interface]
Address = 10.10.0.2/30
ListenPort = 51820
PrivateKey = <server-b-private-key>
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT

[Peer]
# Server A
PublicKey = <server-a-public-key>
Endpoint = 1.2.3.4:51820
AllowedIPs = 10.10.0.1/32, 192.168.1.0/24
PersistentKeepalive = 25
```

**Add static routes on each LAN** so hosts know to send cross-site traffic to their
local WireGuard server (the gateway). Or enable OSPF/BGP via the tunnel if you have
many subnets (out of scope for basic WireGuard setup).

```bash
# On a host in Site A's LAN that wants to reach Site B:
sudo ip route add 192.168.2.0/24 via 192.168.1.254  # 192.168.1.254 = Server A's LAN IP

# On Site A's router, add the route so all hosts benefit:
# (syntax varies by router OS — set next-hop to Server A's LAN IP)
```

**Verify**:

```bash
# From a host in Site A:
ping 192.168.2.10   # should reach a host in Site B

# Check the tunnel itself:
sudo wg show wg0 latest-handshakes   # should show Server B with a recent timestamp
```
