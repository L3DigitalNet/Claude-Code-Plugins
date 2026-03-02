# Certbot Documentation

## Official Certbot

- User guide: https://eff-certbot.readthedocs.io/en/stable/
- Getting started: https://certbot.eff.org/instructions
- CLI reference: https://eff-certbot.readthedocs.io/en/stable/using.html
- Pre/post/deploy hooks: https://eff-certbot.readthedocs.io/en/stable/using.html#pre-and-post-validation-hooks
- Renewal configuration: https://eff-certbot.readthedocs.io/en/stable/using.html#modifying-the-renewal-configuration-file

## Let's Encrypt

- How it works (ACME overview): https://letsencrypt.org/how-it-works/
- Rate limits (per domain, per week): https://letsencrypt.org/docs/rate-limits/
- Staging environment (use for testing): https://letsencrypt.org/docs/staging-environment/
  - Staging ACME URL: `https://acme-staging-v02.api.letsencrypt.org/directory`
- Certificate types (DV only, no OV/EV): https://letsencrypt.org/docs/certificate-compatibility/
- FAQ: https://letsencrypt.org/docs/faq/

## ACME Protocol

- RFC 8555 (ACME): https://datatracker.ietf.org/doc/html/rfc8555
- Challenge types (HTTP-01, DNS-01, TLS-ALPN-01): https://letsencrypt.org/docs/challenge-types/

## DNS Plugins

- Full plugin list (certbot-dns-*): https://eff-certbot.readthedocs.io/en/stable/using.html#dns-plugins
- certbot-dns-cloudflare: https://certbot-dns-cloudflare.readthedocs.io/
- certbot-dns-route53 (AWS): https://certbot-dns-route53.readthedocs.io/
- certbot-dns-digitalocean: https://certbot-dns-digitalocean.readthedocs.io/
- certbot-dns-google (Cloud DNS): https://certbot-dns-google.readthedocs.io/
- certbot-dns-linode: https://certbot-dns-linode.readthedocs.io/

## Alternative ACME Clients

- acme.sh (shell-only, 150+ DNS providers): https://github.com/acmesh-official/acme.sh
- Caddy (built-in automatic HTTPS): https://caddyserver.com/docs/automatic-https
- Traefik (built-in automatic HTTPS): https://doc.traefik.io/traefik/https/acme/

## Testing and Verification

- SSL Labs server test (grades cert and TLS config): https://www.ssllabs.com/ssltest/
- Let's Debug (diagnoses HTTP-01 failures): https://letsdebug.net/
- SSL Shopper cert checker: https://www.sslshopper.com/ssl-checker.html

## Distribution-Specific

- Arch Linux certbot wiki: https://wiki.archlinux.org/title/Certbot
- Debian/Ubuntu: https://certbot.eff.org/instructions?ws=nginx&os=debianbuster
- Fedora/RHEL: https://certbot.eff.org/instructions?ws=nginx&os=fedora

## Man pages

- `man certbot`
