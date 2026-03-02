# OpenVPN Setup Patterns

Each section below is a complete, sequential guide. Commands assume Debian/Ubuntu;
adjust package names and paths for RHEL/Fedora (`nogroup` → `nobody`, `apt` → `dnf`).

---

## 1. Server Setup with Easy-RSA

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

# Initialize the PKI directory structure
easyrsa init-pki

# Build the Certificate Authority. Sets the CA key passphrase and CN.
# Use a strong passphrase — you'll need it each time you sign certs.
easyrsa build-ca

# Build the server certificate and key (nopass = no key passphrase)
easyrsa build-server-full server nopass

# Generate TLS authentication/encryption key
openvpn --genkey secret /etc/openvpn/server/ta.key

# Option A: Use ECDH (recommended — fast, no pre-computation needed)
# Set "dh none" and "ecdh-curve prime256v1" in server.conf.

# Option B: Generate DH parameters (slow — can take several minutes on low-power hardware)
# easyrsa gen-dh
# cp /etc/easy-rsa/pki/dh.pem /etc/openvpn/server/dh.pem

# Copy PKI artifacts to the OpenVPN server directory
cp /etc/easy-rsa/pki/ca.crt          /etc/openvpn/server/
cp /etc/easy-rsa/pki/issued/server.crt /etc/openvpn/server/
cp /etc/easy-rsa/pki/private/server.key /etc/openvpn/server/

# Generate an initial CRL (required if crl-verify is set in server.conf)
easyrsa gen-crl
cp /etc/easy-rsa/pki/crl.pem /etc/openvpn/server/

# Write server.conf (see server.conf.annotated for full reference)
# Minimum viable config:
cat > /etc/openvpn/server/server.conf << 'EOF'
port 1194
proto udp
dev tun
ca   /etc/openvpn/server/ca.crt
cert /etc/openvpn/server/server.crt
key  /etc/openvpn/server/server.key
dh   none
ecdh-curve prime256v1
crl-verify /etc/openvpn/server/crl.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 10.8.0.1"
keepalive 10 120
tls-crypt /etc/openvpn/server/ta.key
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
auth SHA256
tls-version-min 1.2
user nobody
group nogroup
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
verb 3
explicit-exit-notify 1
EOF

# Enable IP forwarding (persist across reboots)
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-openvpn.conf
sysctl -p /etc/sysctl.d/99-openvpn.conf

# Add NAT masquerade rule — replace eth0 with your actual WAN interface
# For iptables:
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eth0 -j MASQUERADE
# Persist with iptables-persistent:
apt install iptables-persistent
netfilter-persistent save

# For firewalld:
# firewall-cmd --add-masquerade --permanent
# firewall-cmd --reload

# Open firewall port
ufw allow 1194/udp
# OR for firewalld:
# firewall-cmd --add-port=1194/udp --permanent && firewall-cmd --reload

# Enable and start the service
# The "@server" suffix matches the filename: /etc/openvpn/server/server.conf
systemctl enable --now openvpn@server

# Verify
systemctl is-active openvpn@server
ip addr show tun0
journalctl -u openvpn@server | grep "Initialization Sequence Completed"
```

---

## 2. Client Certificate and Config Generation

Creates a client key pair and packages it into a self-contained `.ovpn` inline file.
The inline format embeds the CA, cert, key, and TLS key directly in the file so the
client needs only this single file.

```bash
cd /etc/easy-rsa

# Generate client certificate and key (nopass = no passphrase on the key)
# Replace "client1" with the client's name (e.g. "alice-laptop")
easyrsa build-client-full client1 nopass

# Gather PKI artifacts
CA_CERT=/etc/easy-rsa/pki/ca.crt
CLIENT_CERT=/etc/easy-rsa/pki/issued/client1.crt
CLIENT_KEY=/etc/easy-rsa/pki/private/client1.key
TLS_KEY=/etc/openvpn/server/ta.key
SERVER_IP="your.server.ip.or.hostname"
SERVER_PORT=1194

# Generate inline .ovpn file
cat > /tmp/client1.ovpn << EOF
client
dev tun
proto udp
remote ${SERVER_IP} ${SERVER_PORT}
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
$(cat ${CA_CERT})
</ca>
<cert>
$(openssl x509 -in ${CLIENT_CERT})
</cert>
<key>
$(cat ${CLIENT_KEY})
</key>
<tls-crypt>
$(cat ${TLS_KEY})
</tls-crypt>
EOF

echo "Client config written to /tmp/client1.ovpn"
echo "Transfer this file securely — it contains the private key."
```

Deliver the `.ovpn` file via SFTP, a secrets manager, or another secure channel.
Delete it from `/tmp` after delivery.

---

## 3. Client Certificate Revocation

Prevents a specific client from connecting. Steps must be done in order — the CRL
must be updated on the server before the revocation takes effect.

```bash
cd /etc/easy-rsa

# Revoke the client certificate (prompts for confirmation)
easyrsa revoke client1

# Regenerate the CRL after every revocation
easyrsa gen-crl

# Deploy the new CRL to the server config directory
cp /etc/easy-rsa/pki/crl.pem /etc/openvpn/server/crl.pem
chmod 644 /etc/openvpn/server/crl.pem

# Restart the service to pick up the new CRL
systemctl restart openvpn@server

# Verify: the revoked client should now be rejected at connect time
# Check log for: "VERIFY ERROR: ... certificate is revoked"
```

**CRL expiry**: Easy-RSA generates CRLs with a 180-day validity by default. Set a
cron job to renew before expiry. An expired CRL rejects ALL clients, not just revoked ones.

```bash
# Add to crontab (runs monthly on the 1st at 03:00)
echo "0 3 1 * * root cd /etc/easy-rsa && easyrsa gen-crl && cp pki/crl.pem /etc/openvpn/server/crl.pem && systemctl restart openvpn@server" \
  > /etc/cron.d/openvpn-crl-renew
```

---

## 4. Full Tunnel Client Config

Routes all client traffic (internet + LAN) through the VPN. The server pushes a
default gateway redirect, so the client's internet traffic exits from the server's
WAN interface.

Server-side additions to `server.conf`:

```bash
# Push a default gateway redirect to all clients
push "redirect-gateway def1 bypass-dhcp"

# Push DNS servers — clients use these for all queries while connected
push "dhcp-option DNS 10.8.0.1"   # your VPN-side resolver
push "dhcp-option DNS 1.1.1.1"     # fallback
```

The masquerade rule set up in step 1 handles the NAT for internet traffic. Confirm it
is in place:

```bash
iptables -t nat -L POSTROUTING -n -v | grep MASQUERADE
```

Client config — no additional directives needed beyond the base config from step 2.
The `redirect-gateway` push from the server takes effect automatically.

---

## 5. Split Tunnel

Routes only specific subnets through the VPN. The client's internet traffic continues
to use its local gateway. Remove the `redirect-gateway` push and replace it with
explicit route pushes.

Server-side `server.conf`:

```bash
# Do NOT include: push "redirect-gateway def1 bypass-dhcp"

# Push only the subnets clients should reach through the VPN
push "route 192.168.1.0 255.255.255.0"   # internal LAN
push "route 10.10.0.0 255.255.0.0"        # another internal range

# Push DNS only if you want VPN clients to use your internal resolver for those domains
push "dhcp-option DNS 192.168.1.1"
```

Client config — add `route-nopull` if you want the client to override all server-pushed
routes with locally configured ones (uncommon; typically the server controls routing):

```bash
# client1.ovpn — only needed if the client needs to selectively ignore pushed routes
# route-nopull
# route 192.168.1.0 255.255.255.0 vpn_gateway   # then add specific routes manually
```

For most split-tunnel deployments, configure routes only on the server side — the
client honors whatever the server pushes without any client-side changes.
