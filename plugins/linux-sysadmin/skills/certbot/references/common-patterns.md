# Certbot Common Patterns

Commands and configs are copy-paste-ready. Replace `example.com` with your domain.
All `certbot` commands require `sudo` unless running as root.

---

## 1. Obtain Cert with the nginx Plugin

The nginx plugin modifies your nginx config automatically to handle the ACME challenge
and to inject `ssl_certificate` / `ssl_certificate_key` directives after issuance.
nginx must already be running and serving the domain.

```bash
# Single domain
sudo certbot --nginx -d example.com

# Multiple domains (all end up in one cert as SANs)
sudo certbot --nginx -d example.com -d www.example.com -d api.example.com

# Non-interactive (CI/automation) — supply email and agree to ToS flags
sudo certbot --nginx -d example.com \
  --non-interactive \
  --agree-tos \
  --email admin@example.com
```

After issuance, certbot writes the cert paths into your nginx server block. Verify:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

---

## 2. Obtain Cert with the Apache Plugin

Same behavior as the nginx plugin but modifies Apache virtual host configs.

```bash
sudo certbot --apache -d example.com -d www.example.com \
  --non-interactive \
  --agree-tos \
  --email admin@example.com
```

---

## 3. Standalone Mode (Stop Web Server Temporarily)

Certbot spins up its own temporary HTTP server on port 80 to answer the ACME challenge.
Stop your web server first, then start it again afterward. Use a deploy hook (pattern 6)
to automate the reload step.

```bash
# Stop nginx, obtain cert, restart nginx
sudo systemctl stop nginx
sudo certbot certonly --standalone -d example.com --agree-tos --email admin@example.com
sudo systemctl start nginx
```

For automation, use pre/post hooks instead (see pattern 8).

---

## 4. DNS-01 Challenge for Wildcard Certs

DNS-01 proves domain control by placing a TXT record. Required for wildcard certs
(`*.example.com`). Works from servers with no public IP or closed port 80.

### Manual DNS (provider-agnostic)

Certbot prompts you to create a `_acme-challenge.example.com` TXT record, then waits
for you to press Enter after DNS propagation. Suitable for one-off issuance; cannot
be used for automated renewal.

```bash
sudo certbot certonly \
  --manual \
  --preferred-challenges dns \
  -d '*.example.com' \
  -d example.com \
  --agree-tos \
  --email admin@example.com
```

### Automated DNS (Cloudflare example)

Install the DNS plugin, create an API credentials file, then run certbot with the plugin.

```bash
# Install plugin (snap-based certbot)
sudo snap install certbot-dns-cloudflare

# Create credentials file (keep this private)
mkdir -p ~/.secrets/certbot
cat > ~/.secrets/certbot/cloudflare.ini << 'EOF'
dns_cloudflare_api_token = YOUR_API_TOKEN_HERE
EOF
chmod 600 ~/.secrets/certbot/cloudflare.ini

# Obtain wildcard cert
sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials ~/.secrets/certbot/cloudflare.ini \
  --dns-cloudflare-propagation-seconds 60 \
  -d '*.example.com' \
  -d example.com \
  --agree-tos \
  --email admin@example.com
```

Other DNS plugins follow the same pattern: `--dns-route53`, `--dns-digitalocean`,
`--dns-google`, `--dns-linode`, etc. See `docs.md` for the full plugin list.

---

## 5. Use Staging to Avoid Rate Limits

Always use staging when testing workflows, CI pipelines, or new server configurations.
Staging certs are signed by a fake CA — browsers will reject them — but issuance does
not count against the production rate limit (5 duplicate certs/week per domain).

```bash
# Test the full issuance flow without consuming rate limit quota
sudo certbot certonly --staging --standalone -d example.com --agree-tos --email admin@example.com

# Inspect the staging cert to confirm the workflow worked
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -issuer -enddate

# Once the workflow is confirmed, delete the staging cert and re-issue against production
sudo certbot delete --cert-name example.com
sudo certbot certonly --standalone -d example.com --agree-tos --email admin@example.com
```

---

## 6. Deploy Hook to Reload Web Server After Renewal

Without a deploy hook, the web server keeps serving the old cert after certbot renews it.
Deploy hooks run after every successful renewal. Place executable scripts in
`/etc/letsencrypt/renewal-hooks/deploy/`.

```bash
# Create a deploy hook for nginx
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh << 'EOF'
#!/bin/bash
# Reload nginx after cert renewal so the new cert takes effect.
# certbot sets RENEWED_DOMAINS and RENEWED_LINEAGE env vars if needed for filtering.
systemctl reload nginx
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
```

For Apache:

```bash
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh << 'EOF'
#!/bin/bash
systemctl reload apache2
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-apache.sh
```

Test that the hook runs correctly without waiting for actual renewal:

```bash
sudo run-parts /etc/letsencrypt/renewal-hooks/deploy/
```

---

## 7. Expand an Existing Cert to Add Domains

Adding a new domain to an existing cert (without `--expand`) creates a new cert and
leaves the old one active. Use `--expand` to add SANs to the existing lineage.

```bash
# The -d list must include ALL domains — existing and new
sudo certbot --nginx --expand \
  -d example.com \
  -d www.example.com \
  -d newsubdomain.example.com
```

After expansion, verify that nginx is serving the updated cert:

```bash
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -text | grep -A1 'Subject Alternative'
```

---

## 8. Renew with Pre/Post Hooks (Stop and Start Web Server)

Use pre/post hooks when using standalone mode for renewal. Pre hooks run before the
challenge attempt; post hooks run after regardless of success or failure.

```bash
# One-off renewal with inline hooks
sudo certbot renew \
  --pre-hook "systemctl stop nginx" \
  --post-hook "systemctl start nginx"
```

To make hooks permanent for a specific cert, edit its renewal config:

```ini
# /etc/letsencrypt/renewal/example.com.conf
[renewalparams]
pre_hook = systemctl stop nginx
post_hook = systemctl start nginx
```

Or place scripts in the hook directories (applied to all certs):

```
/etc/letsencrypt/renewal-hooks/pre/     # runs before challenge
/etc/letsencrypt/renewal-hooks/post/    # runs after challenge (success or failure)
/etc/letsencrypt/renewal-hooks/deploy/  # runs only on successful renewal
```

---

## 9. Certificate Inspection

```bash
# Full cert details (issuer, validity, SANs, key type)
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -text

# Expiry date only
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -enddate

# Subject Alternative Names (domains covered by the cert)
openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -ext subjectAltName

# Check what a live server is actually serving (not what's on disk)
echo | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -noout -enddate -issuer

# Verify fullchain.pem against privkey.pem (moduli must match)
openssl x509 -noout -modulus -in /etc/letsencrypt/live/example.com/fullchain.pem | md5sum
openssl rsa  -noout -modulus -in /etc/letsencrypt/live/example.com/privkey.pem   | md5sum

# List all certs certbot knows about with expiry dates
sudo certbot certificates
```

---

## 10. acme.sh as an Alternative

`acme.sh` is a shell-only ACME client that requires no root, supports more DNS providers
natively, and does not depend on Python or snapd. It stores certs in `~/.acme.sh/`.

Quick comparison:

| Feature | certbot | acme.sh |
|---------|---------|---------|
| Language | Python | Bash |
| Root required | Yes (for system paths) | No |
| DNS provider plugins | ~30 via pip | 150+ built-in |
| Web server plugin | nginx, apache | None (manual or hooks) |
| Default install | snap / apt / dnf | `curl | sh` |
| Cert storage | `/etc/letsencrypt/` | `~/.acme.sh/` |
| systemd timer | Yes (snap/apt) | Cron entry (self-installs) |

Install and issue with acme.sh (Cloudflare DNS example):

```bash
curl https://get.acme.sh | sh -s email=admin@example.com

# Cloudflare API token
export CF_Token="YOUR_TOKEN"
~/.acme.sh/acme.sh --issue --dns dns_cf -d example.com -d '*.example.com'

# Install cert to a path nginx can read, with a reload hook
~/.acme.sh/acme.sh --install-cert -d example.com \
  --cert-file      /etc/ssl/example.com/cert.pem \
  --key-file       /etc/ssl/example.com/privkey.pem \
  --fullchain-file /etc/ssl/example.com/fullchain.pem \
  --reloadcmd      "systemctl reload nginx"
```

Use certbot when you want system-level integration (systemd timer, nginx/apache plugins,
`/etc/letsencrypt/` layout). Use acme.sh when running without root, when your DNS
provider is not in certbot's plugin list, or when you prefer a no-dependency shell tool.
