# step-ca Common Patterns

Commands are for the `step` CLI (client) and `step-ca` (server). Replace `ca.internal` and
`9000` with your CA hostname and port. `$(step path)` expands to the step config directory
(default `~/.step`; override with `STEPPATH` env var).

---

## 1. Initialize a New CA

Run once on the CA host. Creates root + intermediate keypair, `ca.json`, and the default JWK provisioner.

```bash
step ca init \
  --name "My Homelab CA" \
  --dns "ca.internal" \
  --address ":9000" \
  --provisioner admin@example.com

# The init wizard prompts for:
#   - CA name (shown in cert issuer field)
#   - DNS names / IPs for the CA itself (not for issued certs)
#   - Listening address (host:port or :port)
#   - First provisioner name (email address style)
#   - Provisioner password (encrypts the intermediate private key)

# To also enable SSH certificate authority:
step ca init --ssh \
  --name "My Homelab CA" \
  --dns "ca.internal" \
  --address ":9000" \
  --provisioner admin@example.com

# Show the root fingerprint — needed for client bootstrap:
step certificate fingerprint $(step path)/certs/root_ca.crt
```

Start the CA after init:

```bash
# Foreground (for testing):
step-ca $(step path)/config/ca.json

# As a systemd service (after installing the unit file):
sudo systemctl enable --now step-ca
```

---

## 2. Install Root Cert on Clients

Clients must trust the root CA cert before any step-ca-issued cert will be valid.

### Linux (system trust store)

```bash
# Download the root cert from the CA (requires the fingerprint to verify authenticity):
step ca root root_ca.crt --ca-url https://ca.internal:9000 --fingerprint <root-fingerprint>

# Install into the OS trust store:
step certificate install root_ca.crt
# Equivalent on Debian/Ubuntu:
#   sudo cp root_ca.crt /usr/local/share/ca-certificates/my-ca.crt && sudo update-ca-certificates
# Equivalent on RHEL/Fedora:
#   sudo cp root_ca.crt /etc/pki/ca-trust/source/anchors/my-ca.crt && sudo update-ca-trust
```

### macOS

```bash
step certificate install root_ca.crt
# Adds to the System keychain and marks as trusted for TLS.
# Or manually: open root_ca.crt → Keychain Access → set "Always Trust"
```

### Windows (PowerShell, as Administrator)

```powershell
Import-Certificate -FilePath "root_ca.crt" -CertStoreLocation "Cert:\LocalMachine\Root"
```

### Docker containers

```dockerfile
# In the Dockerfile — copy and install the CA cert at build time.
COPY root_ca.crt /usr/local/share/ca-certificates/my-ca.crt
RUN update-ca-certificates
```

---

## 3. Issue and Use a Certificate

```bash
# Bootstrap first (one-time per host — see pattern 5):
step ca bootstrap --ca-url https://ca.internal:9000 --fingerprint <root-fingerprint>

# Issue a cert for a hostname:
step ca certificate myhost.internal myhost.crt myhost.key

# Issue with additional SANs (Subject Alternative Names):
step ca certificate myhost.internal myhost.crt myhost.key \
  --san myhost.internal \
  --san 192.168.1.10

# Issue with a specific provisioner and custom lifetime:
step ca certificate myhost.internal myhost.crt myhost.key \
  --provisioner admin@example.com \
  --not-after 720h

# Inspect the issued cert:
step certificate inspect myhost.crt

# Use the cert in nginx:
# ssl_certificate     /path/to/myhost.crt;
# ssl_certificate_key /path/to/myhost.key;
# ssl_trusted_certificate $(step path)/certs/root_ca.crt;
```

---

## 4. Configure ACME Provisioner

ACME provisioner lets ACME-compatible clients (Caddy, certbot with the step plugin,
`acme.sh`) automatically obtain and renew certs from step-ca.

```bash
# Add ACME provisioner (run on the CA host):
step ca provisioner add acme --type ACME

# Restart step-ca to pick up the new provisioner:
sudo systemctl restart step-ca

# List provisioners to confirm:
step ca provisioner list

# The ACME directory URL (for client configuration):
# https://ca.internal:9000/acme/acme/directory
# Pattern: https://<ca-host>:<port>/acme/<provisioner-name>/directory

# Test issuing via ACME (uses the step ACME provisioner):
step ca certificate --provisioner acme test.internal /tmp/test.crt /tmp/test.key
```

---

## 5. Configure a Service (Caddy or nginx) via ACME

### Caddy (recommended — zero manual cert management after bootstrap)

Caddy's built-in ACME client talks directly to step-ca. No certbot or external tool needed.

```bash
# On the Caddy host, bootstrap step so the root cert is trusted:
step ca bootstrap --ca-url https://ca.internal:9000 --fingerprint <root-fingerprint> --install
# --install also calls step certificate install on the root cert

# Verify the root is trusted:
curl https://ca.internal:9000/health   # should succeed without -k
```

```
# Caddyfile — tell Caddy to use your internal CA's ACME endpoint:
{
    # Point to your step-ca ACME directory.
    acme_ca https://ca.internal:9000/acme/acme/directory
}

myservice.internal {
    reverse_proxy localhost:3000
    # Caddy auto-issues and renews the cert via ACME — nothing else needed.
}
```

### nginx (manual cert management via step ca renew --daemon)

```bash
# Issue the cert:
step ca certificate myservice.internal /etc/nginx/ssl/myservice.crt /etc/nginx/ssl/myservice.key

# Start the renewal daemon (run as a systemd service — see pattern 6):
step ca renew --daemon \
  --exec "systemctl reload nginx" \
  /etc/nginx/ssl/myservice.crt \
  /etc/nginx/ssl/myservice.key
```

```nginx
server {
    listen 443 ssl;
    http2 on;
    server_name myservice.internal;

    ssl_certificate     /etc/nginx/ssl/myservice.crt;
    ssl_certificate_key /etc/nginx/ssl/myservice.key;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## 6. Certificate Renewal (Manual and Daemon)

step-ca certs are short-lived by default. Renewal uses the existing cert as proof of identity
(no password needed after initial issuance).

```bash
# One-shot manual renewal:
step ca renew myhost.crt myhost.key

# Force renewal even if cert is not near expiry:
step ca renew --force myhost.crt myhost.key

# Daemon mode — stays running, renews automatically at ~2/3 of lifetime,
# executes a command after each successful renewal:
step ca renew --daemon \
  --exec "systemctl reload myservice" \
  /etc/myservice/myservice.crt \
  /etc/myservice/myservice.key
```

Systemd unit for the renewal daemon (`/etc/systemd/system/step-renew-myservice.service`):

```ini
[Unit]
Description=step-ca certificate renewal for myservice
After=network-online.target step-ca.service

[Service]
Type=simple
# Run as the user that owns the cert files.
User=myservice
ExecStart=/usr/local/bin/step ca renew --daemon \
  --exec "systemctl reload myservice" \
  /etc/myservice/myservice.crt \
  /etc/myservice/myservice.key
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl enable --now step-renew-myservice
```

---

## 7. SSH Certificate Authority

SSH CA allows step-ca to sign SSH host and user keys, replacing long-lived `authorized_keys`
with short-lived SSH certificates.

```bash
# Initialize with SSH support (or add to existing CA):
step ca init --ssh --name "My CA" --dns ca.internal --address :9000 --provisioner admin@example.com

# Issue an SSH user certificate (valid 8h by default):
step ssh login user@example.com --provisioner admin@example.com

# Issue an SSH host certificate:
step ssh certificate myhost.internal /etc/ssh/ssh_host_ecdsa_key.pub \
  --host --provisioner admin@example.com

# Configure sshd to trust the CA for host auth (/etc/ssh/sshd_config):
#   HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#   TrustedUserCAKeys /etc/ssh/step_user_ca.pub

# Get the user CA public key for sshd:
step ssh config --roots > /etc/ssh/step_user_ca.pub

# Configure the SSH client to trust host certs (~/.ssh/known_hosts or /etc/ssh/ssh_known_hosts):
step ssh config --host --roots | tee -a ~/.ssh/known_hosts
```

---

## 8. Mutual TLS (mTLS) for Service-to-Service Auth

mTLS requires both sides to present a certificate issued by the same CA. Each service gets
its own cert; the CA root is the trust anchor for both.

```bash
# Issue certs for each service:
step ca certificate service-a.internal service-a.crt service-a.key
step ca certificate service-b.internal service-b.crt service-b.key
```

nginx upstream config with mTLS (service-a proxies to service-b and presents its cert):

```nginx
# /etc/nginx/conf.d/upstream-service-b.conf
upstream service_b {
    server service-b.internal:8443;
}

server {
    listen 443 ssl;
    server_name service-a.internal;

    ssl_certificate     /etc/service-a/service-a.crt;
    ssl_certificate_key /etc/service-a/service-a.key;

    location / {
        proxy_pass https://service_b;

        # Present service-a's cert to service-b (client cert for mTLS):
        proxy_ssl_certificate     /etc/service-a/service-a.crt;
        proxy_ssl_certificate_key /etc/service-a/service-a.key;

        # Verify service-b's cert against the shared CA root:
        proxy_ssl_trusted_certificate /etc/step/certs/root_ca.crt;
        proxy_ssl_verify on;
        proxy_ssl_verify_depth 2;
    }
}
```

Python (requests) example:

```python
import requests

response = requests.get(
    "https://service-b.internal:8443/api/data",
    cert=("service-a.crt", "service-a.key"),   # present our cert
    verify="root_ca.crt",                        # verify their cert against CA root
)
```

---

## 9. Short-Lived Certificate Workflow (Zero-Trust)

For zero-trust environments: issue certs with very short lifetimes; never renew, always
re-issue. Services authenticate to the CA (via OIDC, JWK, or cloud identity) to get a new
cert each time.

```bash
# Issue with a 1-hour lifetime:
step ca certificate myservice.internal myservice.crt myservice.key --not-after 1h

# Automate re-issuance via cron or a sidecar process.
# Example cron (re-issues every 50 minutes for a 1h cert):
# */50 * * * * step ca certificate myservice.internal /run/certs/myservice.crt /run/certs/myservice.key && systemctl reload myservice

# Configure short default lifetime in ca.json (under the provisioner's claims):
```

```json
{
  "type": "JWK",
  "name": "admin@example.com",
  "claims": {
    "minTLSCertDuration": "5m",
    "maxTLSCertDuration": "1h",
    "defaultTLSCertDuration": "1h"
  }
}
```

---

## 10. Integrate with Caddy (Full Zero-Config Internal HTTPS)

The simplest path to internal HTTPS for homelab services. Caddy handles everything after
the one-time bootstrap step.

```bash
# 1. On the CA host: ensure the ACME provisioner exists.
step ca provisioner list | grep -i acme || step ca provisioner add acme --type ACME
sudo systemctl restart step-ca

# 2. On the Caddy host: bootstrap and install the root cert.
step ca bootstrap \
  --ca-url https://ca.internal:9000 \
  --fingerprint $(step certificate fingerprint /path/to/root_ca.crt) \
  --install

# 3. Verify the root is trusted by curl (not just step):
curl https://ca.internal:9000/health

# 4. Configure Caddyfile.
```

```
# /etc/caddy/Caddyfile
{
    # Use your step-ca ACME endpoint globally.
    # Caddy caches certs in /var/lib/caddy/.local/share/caddy/
    acme_ca https://ca.internal:9000/acme/acme/directory
}

# Each site block automatically gets a cert from step-ca.
homeassistant.internal {
    reverse_proxy localhost:8123
}

grafana.internal {
    reverse_proxy localhost:3000
}

jellyfin.internal {
    reverse_proxy localhost:8096
}
```

```bash
# 5. Reload Caddy — it will obtain certs immediately:
sudo systemctl reload caddy

# Check Caddy's cert status:
curl -sI https://homeassistant.internal | grep -i "server\|strict"
```

Caddy renews certs automatically before they expire; no cron job or renewal daemon needed.
