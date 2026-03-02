# OpenVPN Setup Patterns

Each section below is a complete, sequential guide. Commands assume Debian/Ubuntu;
adjust package names and paths for RHEL/Fedora (`nogroup` → `nobody`, `apt` → `dnf`).

---

## 1. PKI Setup with Easy-RSA 3

Installs OpenVPN, initializes the PKI, issues a server certificate, and starts the
service. Run all commands as root or with `sudo`.

```bash
# Install packages
apt install openvpn easy-rsa

# Create Easy-RSA working directory
make-cadir /etc/easy-rsa
cd /etc/easy-rsa

# Optional: edit vars to set default DN fields (avoids repeated prompts)
# Edit /etc/easy-rsa/vars — set EASYRSA_REQ_COUNTRY, EASYRSA_REQ_ORG, etc.
# Example:
#   set_var EASYRSA_REQ_COUNTRY   "US"
#   set_var EASYRSA_REQ_ORG       "MyOrg"
#   set_var EASYRSA_REQ_EMAIL     "admin@example.com"
#   set_var EASYRSA_CA_EXPIRE     3650
#   set_var EASYRSA_CERT_EXPIRE   825

# Initialize the PKI directory structure
easyrsa init-pki

# Build the Certificate Authority. Sets the CA key passphrase and CN.
# Use a strong passphrase — required each time you sign certificates.
easyrsa build-ca

# Build the server certificate and key (nopass = no passphrase on the private key)
easyrsa build-server-full server nopass

# Build a client certificate (repeat for each client)
easyrsa build-client-full client1 nopass

# Option A (recommended): Use ECDH — no pre-computation, better forward secrecy.
# Set "dh none" and "ecdh-curve prime256v1" in server.conf.

# Option B: Generate DH parameters (slow — minutes on low-power hardware)
easyrsa gen-dh
cp /etc/easy-rsa/pki/dh.pem /etc/openvpn/server/dh.pem

# Generate TLS key for tls-crypt (OpenVPN 2.4+, preferred) or tls-auth
openvpn --genkey secret /etc/openvpn/server/ta.key

# Copy PKI artifacts to the OpenVPN server directory
cp /etc/easy-rsa/pki/ca.crt               /etc/openvpn/server/
cp /etc/easy-rsa/pki/issued/server.crt    /etc/openvpn/server/
cp /etc/easy-rsa/pki/private/server.key   /etc/openvpn/server/

# Generate an initial CRL (required when crl-verify is in server.conf)
easyrsa gen-crl
cp /etc/easy-rsa/pki/crl.pem /etc/openvpn/server/
```

---

## 2. Server Config Skeleton

Minimum viable `server.conf` with the critical directives annotated.

```
# /etc/openvpn/server/server.conf

port 1194
proto udp           # UDP preferred for performance; use tcp 443 to bypass strict firewalls
dev tun             # Routed VPN (layer 3); use "tap" only for bridged/layer-2 setups

# PKI artifacts — paths must match what was copied in step 1
ca   /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key  /etc/openvpn/server/server.key

# DH: "none" uses ECDH (fast, recommended). Use a dh.pem path if you generated one.
dh   none
ecdh-curve prime256v1

# Certificate revocation — required to honor easyrsa revoke
crl-verify /etc/openvpn/server/crl.pem

# VPN subnet: server takes .1, clients receive .2, .3, etc. (by default)
server 10.8.0.0 255.255.255.0

# Persist IP assignments across restarts (clients keep the same VPN IP)
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# Route all traffic through VPN (full tunnel); remove for split tunnel — see section 7/8
push "redirect-gateway def1 bypass-dhcp"

# DNS pushed to clients — use your resolver or a public one
push "dhcp-option DNS 10.8.0.1"
push "dhcp-option DNS 1.1.1.1"

keepalive 10 120    # ping every 10s; assume client dead after 120s

# tls-crypt: authenticates + encrypts TLS control channel (OpenVPN 2.4+)
# Prevents unauthenticated clients from triggering a TLS handshake at all.
# Use "tls-auth ta.key 0" here (and "tls-auth ta.key 1" on clients) for older setups.
tls-crypt /etc/openvpn/server/ta.key

# Cipher negotiation: GCM ciphers preferred; CBC for legacy client compatibility
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
tls-version-min 1.2

# Drop privileges after startup
user nobody
group nogroup

# Survive restarts without re-reading the key file
persist-key
persist-tun

# Status and logging
status /var/log/openvpn/openvpn-status.log
log-append /var/log/openvpn/openvpn.log
verb 3              # 0=silent, 4=debug TLS, 6=very verbose

# Notify clients when the server is going down (UDP only)
explicit-exit-notify 1
```

Enable IP forwarding and add a NAT masquerade rule so clients can reach the internet:

```bash
# Persist IP forwarding across reboots
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

# NAT masquerade — replace eth0 with your actual WAN interface name
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
apt install iptables-persistent && netfilter-persistent save

# For firewalld (RHEL/Fedora):
# firewall-cmd --add-masquerade --permanent && firewall-cmd --reload

# Open the VPN port
ufw allow 1194/udp
# For firewalld: firewall-cmd --add-port=1194/udp --permanent && firewall-cmd --reload

# Start the service — the "@server" suffix matches the config filename
systemctl enable --now openvpn@server

# Verify
systemctl is-active openvpn@server
ip addr show tun0
journalctl -u openvpn@server | grep "Initialization Sequence Completed"
```

---

## 3. Client Config (.ovpn) Structure

A `.ovpn` inline file embeds all certs and keys directly. The client needs this one
file and nothing else. It contains the private key — treat it like a password.

```
# client1.ovpn — inline format

client                          # This is a client config (not a server)
dev tun
proto udp
remote your.server.ip 1194      # Server IP or hostname and port
resolv-retry infinite           # Keep retrying if DNS resolution fails at startup
nobind                          # Don't bind to a specific local port

persist-key
persist-tun

remote-cert-tls server          # Verify the server presents a cert with TLS server usage
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
tls-version-min 1.2
verb 3

# Inline CA certificate — the full PEM block
<ca>
-----BEGIN CERTIFICATE-----
... (contents of ca.crt) ...
-----END CERTIFICATE-----
</ca>

# Inline client certificate — strip the "bag attributes" header, use just the cert block
<cert>
-----BEGIN CERTIFICATE-----
... (contents of client1.crt, cert block only) ...
-----END CERTIFICATE-----
</cert>

# Inline client private key
<key>
-----BEGIN PRIVATE KEY-----
... (contents of client1.key) ...
-----END PRIVATE KEY-----
</key>

# Inline TLS key — direction is implicit with tls-crypt (no "1" needed)
# If using tls-auth instead, add: key-direction 1
<tls-crypt>
-----BEGIN OpenVPN Static key V1-----
... (contents of ta.key) ...
-----END OpenVPN Static key V1-----
</tls-crypt>
```

---

## 4. Distributing Client Configs

Package all PKI material into a single `.ovpn` inline bundle using a script. Run on
the server; deliver the resulting file securely, then delete it.

```bash
#!/usr/bin/env bash
# generate-client.sh <client-name> <server-host> [server-port]
# Outputs an inline .ovpn file to stdout.

CLIENT="${1:?Usage: $0 <client-name> <server-host> [port]}"
SERVER_HOST="${2:?}"
SERVER_PORT="${3:-1194}"
PKI_DIR=/etc/easy-rsa/pki
TLS_KEY=/etc/openvpn/server/ta.key
PROTO=udp

cat <<EOF
client
dev tun
proto ${PROTO}
remote ${SERVER_HOST} ${SERVER_PORT}
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
tls-version-min 1.2
verb 3

<ca>
$(cat "${PKI_DIR}/ca.crt")
</ca>
<cert>
$(openssl x509 -in "${PKI_DIR}/issued/${CLIENT}.crt")
</cert>
<key>
$(cat "${PKI_DIR}/private/${CLIENT}.key")
</key>
<tls-crypt>
$(cat "${TLS_KEY}")
</tls-crypt>
EOF
```

Usage:

```bash
# Generate the config and save it
bash generate-client.sh alice-laptop vpn.example.com > /tmp/alice-laptop.ovpn

# Deliver via SFTP (never email — the file contains a private key)
sftp alice@alice-laptop.example.com <<< "put /tmp/alice-laptop.ovpn"

# Delete from server after delivery
rm /tmp/alice-laptop.ovpn
```

---

## 5. Road Warrior Pattern

Single OpenVPN server, multiple roaming clients each connecting from different networks.
This is the most common use case: laptop users connecting from hotels, home networks, etc.

The standard `server.conf` from section 2 already implements this pattern. Key properties:

- Server uses `server 10.8.0.0 255.255.255.0` — each client gets a unique VPN IP
- `ifconfig-pool-persist` keeps the same IP per client across reconnects
- `push "redirect-gateway def1"` sends all client traffic through the VPN (optional — remove for split tunnel)
- Each client has a unique cert/key pair; revocation is per-client via the CRL

```bash
# Each new road warrior client follows section 6 (adding a new client)
# Multiple clients can be connected simultaneously — no per-client server changes required
```

For clients that need a static VPN IP (e.g. for firewall rules on the server side):

```bash
# In server.conf, enable per-client config directory:
client-config-dir /etc/openvpn/server/ccd

# Create a file named exactly after the client's CN (e.g. "alice-laptop"):
mkdir -p /etc/openvpn/server/ccd
echo "ifconfig-push 10.8.0.10 255.255.255.0" > /etc/openvpn/server/ccd/alice-laptop
```

---

## 6. Site-to-Site

Connects two office LANs so hosts on each side can reach the other without any VPN
client software. One site runs the OpenVPN server; the other runs the client.

Topology: Office A (192.168.1.0/24) ← VPN → Office B (192.168.2.0/24).

**Server side (Office A):**

```
# server.conf additions for site-to-site
# Assign fixed VPN IPs to the client (required for route pushing to work reliably)
client-config-dir /etc/openvpn/server/ccd
route 192.168.2.0 255.255.255.0   # Route Office B's LAN through the VPN tunnel
```

```bash
# CCD entry for the Office B client — assigns fixed VPN endpoint IPs
# First IP is the client's VPN IP; second is the server's VPN IP in that /30
echo "ifconfig-push 10.8.0.2 10.8.0.1
iroute 192.168.2.0 255.255.255.0" > /etc/openvpn/server/ccd/office-b-client
```

**Client side (Office B):**

```
# office-b.ovpn additions
route 192.168.1.0 255.255.255.0   # Route Office A's LAN through the VPN
```

**Routing on both gateways:**

```bash
# On the Office A gateway: route 192.168.2.0/24 via the OpenVPN server's LAN IP
# On the Office B gateway: route 192.168.1.0/24 via the OpenVPN client's LAN IP

# On the VPN server (Office A gateway):
ip route add 192.168.2.0/24 via 10.8.0.2   # via the client's VPN IP
# Persist via /etc/network/interfaces, nmcli, or a systemd-network route file

# Enable forwarding on both gateways (same as section 2):
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf
```

---

## 7. Routing All Traffic Through VPN (Full Tunnel)

Pushes a default gateway redirect to clients. All client internet traffic exits from
the server's WAN interface. Requires NAT masquerade on the server.

```bash
# In server.conf:
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 10.8.0.1"   # VPN-side resolver — prevents DNS leaks
push "dhcp-option DNS 1.1.1.1"     # fallback
```

DNS leak prevention: the `dhcp-option DNS` pushes override the client's local DNS
while connected. If the client OS does not honor pushed DNS (common on some Linux
distributions), also configure the resolver manually in the client config:

```
# client.ovpn — force DNS via script (Linux only, requires openvpn-update-resolv-conf)
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf
```

Verify NAT is in place before expecting clients to reach the internet:

```bash
iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
sysctl net.ipv4.ip_forward   # must print "net.ipv4.ip_forward = 1"
```

---

## 8. Split Tunneling

Routes only specific subnets through the VPN. The client's default internet traffic
uses its local gateway. Remove `redirect-gateway` and push explicit routes instead.

```bash
# In server.conf — do NOT include redirect-gateway:
push "route 192.168.1.0 255.255.255.0"   # internal office LAN
push "route 10.10.0.0 255.255.0.0"        # another internal range

# Push DNS only for internal domains if you have an internal resolver:
push "dhcp-option DNS 192.168.1.1"
# push "dhcp-option DOMAIN internal.example.com"  # optional split-DNS domain
```

No changes required on the client side — the client honors whatever routes the server
pushes. For clients that need to override all pushed routes entirely:

```
# client.ovpn — prevents applying any server-pushed routes
route-nopull
# Then add routes manually:
route 192.168.1.0 255.255.255.0 vpn_gateway
```

---

## 9. Adding a New Client

Complete workflow for provisioning a new client certificate and config.

```bash
cd /etc/easy-rsa

# Step 1: Generate the client certificate and key
# Use a meaningful name — it becomes the CN and is used for CCD and revocation
easyrsa build-client-full alice-laptop nopass

# Step 2: Generate the .ovpn inline config
bash /etc/openvpn/server/generate-client.sh alice-laptop vpn.example.com \
  > /tmp/alice-laptop.ovpn

# Step 3: Deliver the file securely, then delete it
# Options: SFTP, scp, a secrets manager (Vault, 1Password), encrypted email
sftp alice@alice-laptop.example.com <<< "put /tmp/alice-laptop.ovpn"
rm /tmp/alice-laptop.ovpn

# No server restart required — new clients connect using the existing CA
```

To revoke a client later:

```bash
cd /etc/easy-rsa

# Revoke the certificate (prompts for confirmation)
easyrsa revoke alice-laptop

# Regenerate and deploy the CRL — this is what blocks the revoked client
easyrsa gen-crl
cp /etc/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
chmod 644 /etc/openvpn/server/crl.pem
systemctl restart openvpn@server

# Verify: revoked client should see "VERIFY ERROR: certificate is revoked" in logs
```

CRL expiry: Easy-RSA generates CRLs with a 180-day validity. Automate renewal so an
expired CRL does not accidentally block all clients:

```bash
# /etc/cron.d/openvpn-crl-renew — runs monthly on the 1st at 03:00
0 3 1 * * root cd /etc/easy-rsa && easyrsa gen-crl \
  && cp pki/crl.pem /etc/openvpn/server/crl.pem \
  && systemctl restart openvpn@server
```

---

## 10. Troubleshooting

### Verbosity levels

```bash
# Temporarily increase verbosity without editing server.conf:
# Send SIGUSR1 to reload, or edit verb in server.conf and restart

# verb 3 — normal operation, shows connect/disconnect events
# verb 4 — shows TLS negotiation detail (useful for handshake failures)
# verb 6 — shows every packet; very noisy, use only for short debugging sessions

# In server.conf or client.ovpn:
verb 4
```

### Log locations

```bash
# systemd journal (preferred on modern systems):
journalctl -u openvpn@server -f           # follow live
journalctl -u openvpn@server --since "10 min ago"   # recent entries only

# File log (if log-append is set in server.conf):
tail -f /var/log/openvpn/openvpn.log

# Connection status (connected clients, bytes in/out):
cat /var/log/openvpn/openvpn-status.log
grep "CLIENT_LIST" /var/log/openvpn/openvpn-status.log
```

### TLS handshake failures

```bash
# Symptom: "TLS handshake failed" with no further detail at verb 3
# Increase to verb 4 and look for the specific error.

# Most common causes:
# 1. tls-auth direction mismatch:
#    Server must use: tls-auth ta.key 0
#    Client must use: tls-auth ta.key 1
#    (With tls-crypt there is no direction argument — both sides use the same line)

# 2. Wrong ta.key on client:
#    The client's ta.key must be byte-for-byte identical to the server's ta.key.
#    Regenerating the server's ta.key invalidates all existing client configs.

# 3. Cipher mismatch:
#    OpenVPN 2.5+ uses data-ciphers; older clients may only understand cipher (single value).
#    Add to server.conf to support legacy clients: data-ciphers-fallback AES-256-CBC

# 4. TLS version mismatch:
#    "tls-version-min 1.2" on the server rejects clients negotiating TLS 1.0/1.1.
#    Older OpenVPN clients (< 2.3.3) may not support TLS 1.2.
```

### Routing issues

```bash
# Client connects but cannot reach the internet:
# 1. Check IP forwarding
sysctl net.ipv4.ip_forward          # must be 1

# 2. Check NAT masquerade
iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
# If missing: iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
# Replace eth0 with actual WAN interface: ip route | grep default

# 3. Check that tun0 has an IP
ip addr show tun0                   # should show 10.8.0.1

# 4. Trace the path from a client
# On the client: traceroute 8.8.8.8 — first hop should be 10.8.0.1

# Client connects but cannot reach LAN hosts:
# Check that LAN hosts have a route back to 10.8.0.0/24 via the VPN server.
# If not, either add routes on LAN hosts or set the VPN server as the LAN gateway.
```

### Other common checks

```bash
# TUN module not loaded:
modprobe tun
echo "tun" >> /etc/modules          # load on boot

# Certificate verify error:
# Shows cert CN and error — compare against "easyrsa show-cert <name>"
openssl verify -CAfile /etc/easy-rsa/pki/ca.crt /etc/easy-rsa/pki/issued/client1.crt

# Check cert expiry:
openssl x509 -in /etc/easy-rsa/pki/issued/client1.crt -noout -dates

# Check CRL expiry (an expired CRL blocks everyone):
openssl crl -in /etc/openvpn/server/crl.pem -noout -nextupdate

# Management interface (if enabled in server.conf with "management 127.0.0.1 1194"):
telnet 127.0.0.1 1194
> status        # list connected clients
> kill client1  # disconnect a specific client
> quit
```
