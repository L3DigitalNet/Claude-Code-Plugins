---
name: certbot
description: >
  Certbot (Let's Encrypt) certificate management: obtaining, renewing, and
  revoking TLS certificates via ACME protocol. Triggers on: certbot,
  Let's Encrypt, letsencrypt, ACME certificate, SSL certificate, certbot nginx,
  certbot renew, acme.sh, certbot wildcard.
globs:
  - "**/letsencrypt/**/*.conf"
  - "**/letsencrypt/live/**"
  - "**/letsencrypt/renewal/**"
---

## Identity

- **CLI tool**: `certbot`
- **Certs**: `/etc/letsencrypt/live/<domain>/` (symlinks into `archive/`)
- **Renewal configs**: `/etc/letsencrypt/renewal/<domain>.conf`
- **Accounts**: `/etc/letsencrypt/accounts/`
- **Logs**: `/var/log/letsencrypt/letsencrypt.log`
- **Auto-renewal**: `certbot.timer` (systemd) or `/etc/cron.d/certbot` (cron-based installs)
- **Install options**: `snap install --classic certbot` (recommended), `apt install certbot` / `dnf install certbot`, or `pip install certbot`

## Key Operations

| Operation | Command |
|-----------|---------|
| Obtain cert (HTTP-01 via nginx plugin) | `sudo certbot --nginx -d example.com -d www.example.com` |
| Obtain cert (HTTP-01 via apache plugin) | `sudo certbot --apache -d example.com` |
| Obtain cert (standalone, port 80) | `sudo certbot certonly --standalone -d example.com` |
| Obtain cert (DNS-01 for wildcard) | `sudo certbot certonly --manual --preferred-challenges dns -d '*.example.com' -d example.com` |
| Obtain cert (webroot, no web server restart) | `sudo certbot certonly --webroot -w /var/www/html -d example.com` |
| Renew all certs | `sudo certbot renew` |
| Renew dry-run (no changes) | `sudo certbot renew --dry-run` |
| List all certs and expiry dates | `sudo certbot certificates` |
| Revoke a cert | `sudo certbot revoke --cert-path /etc/letsencrypt/live/example.com/cert.pem` |
| Delete a cert (remove from disk) | `sudo certbot delete --cert-name example.com` |
| Expand cert (add domains to existing) | `sudo certbot --nginx --expand -d example.com -d newdomain.com` |
| View cert details (expiry, SANs, issuer) | `openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -text` |
| Check cert expiry date only | `openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -noout -enddate` |
| Test renewal systemd timer | `sudo systemctl status certbot.timer` |
| Manually run renewal hooks | `sudo run-parts /etc/letsencrypt/renewal-hooks/deploy/` |
| Force renewal regardless of expiry | `sudo certbot renew --force-renewal --cert-name example.com` |
| Obtain cert using staging (no rate limits) | `sudo certbot certonly --staging --standalone -d example.com` |

## Expected State

- Certs live in `/etc/letsencrypt/live/<domain>/`: `cert.pem`, `chain.pem`, `fullchain.pem`, `privkey.pem` — all symlinks into `archive/`.
- `/etc/letsencrypt/renewal/<domain>.conf` exists for each cert with the renewal method and any plugin options.
- Auto-renewal is active: `systemctl is-active certbot.timer` returns `active`, or `crontab -l` / `/etc/cron.d/certbot` contains a renewal entry.
- Web server reloads after renewal: a deploy hook script exists in `/etc/letsencrypt/renewal-hooks/deploy/`.

## Health Checks

1. `sudo certbot certificates` — lists all certs with domain names and expiry dates; no cert should show `INVALID` or be expired.
2. `openssl x509 -in /etc/letsencrypt/live/<domain>/cert.pem -noout -enddate` — confirm expiry is more than 30 days out under normal operation (certbot renews at <30 days).
3. `sudo certbot renew --dry-run` — must complete with `Congratulations, all renewals succeeded` (or `No renewals were attempted` if nothing is near expiry).

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `Too many certificates already issued for this exact set of domains` | Hit the 5 certs/week duplicate limit | Use `--staging` to test; wait up to 7 days or use a different subdomain |
| `Problem binding to port 80` | nginx/Apache is already listening on port 80 | Use `--nginx` or `--apache` plugin instead of `--standalone`; or stop the web server first |
| `Connection refused` / `Timeout during connect` on HTTP-01 | Port 80 not reachable from internet | Check firewall (`ufw allow 80`), check NAT/router port forwarding, verify DNS points to this server |
| `DNS problem: NXDOMAIN looking up A for...` | DNS not yet propagated or wrong DNS record | Confirm `dig +short A example.com` returns the server IP; wait for DNS TTL |
| DNS-01 challenge: cert obtained but wrong IPs | Propagation delay between adding TXT record and certbot checking | Certbot prompts to wait; for automated DNS plugins use `--dns-<provider>-propagation-seconds 60` |
| Cert renewed but web server still serving old cert | Deploy hook not configured or hook script failed | Create `/etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh`; check hook exit codes in `/var/log/letsencrypt/letsencrypt.log` |
| Hook script runs but nginx doesn't reload | Hook script not executable | `chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh` |
| `snap certbot` vs OS package conflict | Two certbot installs competing | Remove OS package (`apt remove certbot`), use only the snap version; check `which certbot` |
| `Error: The requested nginx plugin does not appear to be installed` | Plugin package missing | `apt install python3-certbot-nginx` or reinstall via snap (`snap install --classic certbot`) |
| `certbot: command not found` after snap install | Snap binary not symlinked | `sudo ln -s /snap/bin/certbot /usr/bin/certbot` |

## Pain Points

- **Rate limits are per registered domain per week**: 50 certs/week per domain, 5 duplicate certs/week for identical domain sets. Use `--staging` for all development and testing to avoid burning the production quota. Staging certs are not trusted by browsers but do not count against rate limits.
- **HTTP-01 challenge requires port 80 open to the public internet**: Servers behind NAT, corporate firewalls, or without a public IP cannot use HTTP-01. Use DNS-01 instead, which proves domain ownership via a DNS TXT record with no inbound port requirement.
- **DNS-01 is the only option for wildcard certs**: `*.example.com` certificates cannot be obtained via HTTP-01 under any circumstances. DNS-01 requires either a supported DNS provider plugin (`certbot-dns-cloudflare`, etc.) or manual TXT record insertion.
- **Auto-renewal runs twice daily but only renews when under 30 days to expiry**: `certbot renew` checks all certs and skips any with more than 30 days remaining. This means a newly issued cert will not be renewed for ~60 days. Use `--force-renewal` only when genuinely needed — it still counts against rate limits.
- **Deploy hooks not configured by default**: Certbot renews the cert files but does not reload the web server unless a deploy hook is present. Without a hook, the web server keeps serving the old cert from its in-memory cache until it is manually restarted.
- **Cert files are symlinks into a versioned archive directory**: `/etc/letsencrypt/live/example.com/fullchain.pem` points to `/etc/letsencrypt/archive/example.com/fullchain3.pem` (or similar). Scripts that copy certs or check inodes must follow symlinks. Web server configs should always reference the `live/` paths, not `archive/`.

## References

See `references/` for:
- `common-patterns.md` — obtaining certs with nginx/apache/standalone/DNS-01, staging workflow, deploy hooks, pre/post hooks, cert inspection, and acme.sh comparison
- `docs.md` — official documentation, rate limit policy, DNS plugin list, staging environment, and external testing tools
