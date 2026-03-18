---
name: mail-stack
description: >
  Complete mail server deployment — Postfix MTA, Dovecot IMAP, OpenDKIM signing,
  Let's Encrypt TLS via Certbot, and required DNS records (MX, SPF, DKIM, DMARC).
  End-to-end setup for sending and receiving email.
  MUST consult when installing, configuring, or troubleshooting a mail stack (Postfix, Dovecot, OpenDKIM).
triggerPhrases:
  - "mail server"
  - "email server"
  - "set up email"
  - "postfix dovecot"
  - "mail stack"
  - "self-hosted email"
  - "DKIM DMARC SPF"
  - "send and receive email"
last_verified: "2026-03"
---

## Overview

This is a **composite stack skill**. Each component has its own per-tool skill with full configuration reference and troubleshooting. This skill covers the glue: how the pieces integrate, the DNS records that tie everything together, and a working end-to-end deployment.

### Inbound Mail Flow

```
Internet                          Your Server
────────                          ───────────
Sender's MTA                      ┌─────────────────────┐
    │                             │  Postfix (:25)      │
    │  MX lookup → your domain    │  SMTP receiver      │
    │  connects to port 25        │                     │
    ├─────────────────────────────►│  ┌───────────────┐  │
    │                             │  │ OpenDKIM       │  │
    │                             │  │ (milter)       │  │
    │                             │  │ Verify inbound │  │
    │                             │  │ DKIM signature │  │
    │                             │  └───────┬───────┘  │
    │                             │          │          │
    │                             │          ▼          │
    │                             │  Postfix delivers   │
    │                             │  via LMTP           │
    │                             │          │          │
    │                             │          ▼          │
    │                             │  ┌───────────────┐  │
    │                             │  │ Dovecot       │  │
    │                             │  │ (:993 IMAPS)  │  │
    │                             │  │ Stores mail   │  │
    │                             │  │ in Maildir    │  │
    │                             │  └───────────────┘  │
    │                             └─────────────────────┘
    │                                        ▲
    │                             ┌──────────┴──────────┐
    │                             │  Mail client (IMAP) │
    │                             │  Reads mail via     │
    │                             │  Dovecot IMAPS      │
    │                             └─────────────────────┘
```

### Outbound Mail Flow

```
Mail Client                       Your Server                    Recipient
───────────                       ───────────                    ─────────
    │                             ┌─────────────────────┐
    │  Submits via port 587       │  Postfix (:587)     │
    │  (STARTTLS + SASL auth)     │  Submission port    │
    ├─────────────────────────────►│                     │
    │                             │  ┌───────────────┐  │
    │                             │  │ OpenDKIM       │  │
    │                             │  │ (milter)       │  │
    │                             │  │ Signs outbound │  │
    │                             │  │ with private   │  │
    │                             │  │ key            │  │
    │                             │  └───────┬───────┘  │
    │                             │          │          │
    │                             │          ▼          │       ┌──────────┐
    │                             │  Postfix sends      │       │Recipient │
    │                             │  via port 25 ───────┼──────►│  MTA     │
    │                             └─────────────────────┘       │          │
    │                                                           │ Checks:  │
    │                                                           │  SPF ✓   │
    │                                                           │  DKIM ✓  │
    │                                                           │  DMARC ✓ │
    │                                                           │  PTR ✓   │
    │                                                           └──────────┘
```

### TLS Certificate Chain

```
Certbot (Let's Encrypt)
    │
    ├── /etc/letsencrypt/live/mail.example.com/fullchain.pem
    │   /etc/letsencrypt/live/mail.example.com/privkey.pem
    │
    ├──► Postfix (smtpd_tls_cert_file / smtpd_tls_key_file)
    │
    └──► Dovecot (ssl_cert / ssl_key)
```

Both Postfix and Dovecot reference the same Certbot certificate files. A Certbot deploy hook reloads both services on renewal.

## Components

| Component | Role | Ports | Config |
|-----------|------|-------|--------|
| Postfix | MTA: sends and receives mail via SMTP | 25, 587, 465 | `/etc/postfix/main.cf`, `master.cf` |
| Dovecot | IMAP/POP3 server: stores mail, serves to clients | 993, 143 | `/etc/dovecot/dovecot.conf`, `conf.d/` |
| OpenDKIM | DKIM signing (outbound) and verification (inbound) | Unix socket or 8891 | `/etc/opendkim.conf` |
| Certbot | TLS certificate management via Let's Encrypt ACME | (none; runs periodically) | `/etc/letsencrypt/` |
| DNS records | MX, SPF, DKIM, DMARC, PTR | (not a service) | At your DNS provider |

## Prerequisites

Before installing any software, these DNS records and network conditions must be in place. Without them, the stack will run but mail will be rejected by recipients or never arrive.

### Required DNS Records

See `references/dns-records.md` for detailed examples. The minimum set:

| Record | Type | Purpose |
|--------|------|---------|
| `example.com` → `mail.example.com` | MX | Tells the internet where to deliver mail for your domain |
| `mail.example.com` → `203.0.113.10` | A | Points your mail hostname to the server IP |
| PTR for `203.0.113.10` → `mail.example.com` | PTR | Reverse DNS; set at hosting provider, not DNS provider |
| `v=spf1 mx -all` | TXT on `example.com` | Declares which IPs are authorized to send for your domain |
| `v=DKIM1; k=rsa; p=...` | TXT on `mail._domainkey.example.com` | Public key for DKIM signature verification |
| `v=DMARC1; p=reject; ...` | TXT on `_dmarc.example.com` | Policy for handling SPF/DKIM failures |

### Network Requirements

- **Port 25 open outbound**: Required for server-to-server mail delivery. Most cloud providers (AWS, GCP, Azure, DigitalOcean) block this by default. Request an unblock or use an SMTP relay service.
- **Port 25 open inbound**: Required to receive mail. Firewall must allow it.
- **Ports 587, 993 open inbound**: For client submission (STARTTLS) and IMAP access.
- **Static IP with clean reputation**: Check at https://mxtoolbox.com/blacklists.aspx before starting.
- **PTR record matching hostname**: `dig -x <your-ip>` must return `mail.example.com`. Set this at your hosting/VPS provider, not your DNS registrar.

## Quick Start

This walkthrough installs all components on a single Debian/Ubuntu server. Replace `example.com` and `mail.example.com` with your actual domain.

### Step 1: Set the hostname

```bash
sudo hostnamectl set-hostname mail.example.com
# Verify:
hostname -f
```

### Step 2: Obtain TLS certificate

```bash
sudo apt install certbot
# Stop any web server on port 80, then:
sudo certbot certonly --standalone -d mail.example.com
# Or if you have nginx running:
sudo apt install python3-certbot-nginx
sudo certbot --nginx -d mail.example.com
```

### Step 3: Install Postfix

```bash
sudo apt install postfix
# Select "Internet Site" when prompted
# Set system mail name to: example.com
```

Configure Postfix for TLS and submission:

```bash
# TLS settings
sudo postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/mail.example.com/fullchain.pem"
sudo postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/mail.example.com/privkey.pem"
sudo postconf -e "smtpd_tls_security_level = may"
sudo postconf -e "smtp_tls_security_level = may"
sudo postconf -e "smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"

# Hostname and domain
sudo postconf -e "myhostname = mail.example.com"
sudo postconf -e "mydomain = example.com"
sudo postconf -e "myorigin = /etc/mailname"
sudo postconf -e "mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain"

# Mailbox delivery via Dovecot LMTP
sudo postconf -e "mailbox_transport = lmtp:unix:private/dovecot-lmtp"
```

Enable the submission port (587) in `/etc/postfix/master.cf`. Uncomment or add:

```
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_sasl_type=dovecot
  -o smtpd_sasl_path=private/auth
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
```

### Step 4: Install Dovecot

```bash
sudo apt install dovecot-imapd dovecot-lmtpd
```

Configure mail location and TLS. Edit `/etc/dovecot/conf.d/10-mail.conf`:

```
mail_location = maildir:~/Maildir
```

Edit `/etc/dovecot/conf.d/10-ssl.conf`:

```
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.example.com/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.example.com/privkey.pem
ssl_min_protocol = TLSv1.2
```

Configure LMTP socket for Postfix delivery. Edit `/etc/dovecot/conf.d/10-master.conf`:

```
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
```

Configure auth socket for Postfix SASL. In the same file:

```
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
```

### Step 5: Install OpenDKIM

```bash
sudo apt install opendkim opendkim-tools

# Create key directory
sudo mkdir -p /etc/opendkim/keys/example.com

# Generate DKIM key pair (2048-bit RSA, selector "mail")
sudo opendkim-genkey -b 2048 -d example.com -s mail \
  -D /etc/opendkim/keys/example.com/

# Set ownership
sudo chown -R opendkim:opendkim /etc/opendkim/keys/
sudo chmod 600 /etc/opendkim/keys/example.com/mail.private
```

Edit `/etc/opendkim.conf`:

```
Mode                    sv          # sign and verify
Canonicalization        relaxed/simple
Domain                  example.com
Selector                mail
KeyFile                 /etc/opendkim/keys/example.com/mail.private
Socket                  local:/run/opendkim/opendkim.sock
PidFile                 /run/opendkim/opendkim.pid
TrustAnchorFile         /usr/share/dns/root.key
UserID                  opendkim
```

For multiple domains, use `KeyTable` and `SigningTable` files instead of `KeyFile`/`Domain`/`Selector`. See the `opendkim` skill for details.

Connect OpenDKIM to Postfix:

```bash
# Add postfix user to opendkim group
sudo adduser postfix opendkim

# Tell Postfix to use the OpenDKIM milter
sudo postconf -e "milter_protocol = 6"
sudo postconf -e "milter_default_action = accept"
sudo postconf -e "smtpd_milters = local:opendkim/opendkim.sock"
sudo postconf -e "non_smtpd_milters = \$smtpd_milters"
```

Publish the DKIM public key to DNS:

```bash
# Print the DNS TXT record value
sudo cat /etc/opendkim/keys/example.com/mail.txt
# Add this as a TXT record for: mail._domainkey.example.com
```

### Step 6: Set up DNS records

Add all records described in Prerequisites and `references/dns-records.md`. Wait for propagation (check with `dig`).

### Step 7: Configure Certbot auto-renewal hook

Create a deploy hook that reloads both Postfix and Dovecot when the certificate renews:

```bash
sudo tee /etc/letsencrypt/renewal-hooks/deploy/reload-mail.sh << 'EOF'
#!/bin/bash
systemctl reload postfix
systemctl reload dovecot
EOF
sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/reload-mail.sh
```

### Step 8: Start and enable all services

```bash
sudo systemctl enable --now postfix dovecot opendkim
sudo systemctl restart postfix   # pick up milter config

# Verify
sudo postfix check
doveconf -n | head -20
opendkim-testkey -d example.com -s mail -vvv
```

## Integration Points

### Postfix → Dovecot (LMTP delivery)

Postfix hands incoming mail to Dovecot for storage via LMTP over a Unix socket. Both sides must agree on the socket path:

- **Postfix** (`main.cf`): `mailbox_transport = lmtp:unix:private/dovecot-lmtp`
- **Dovecot** (`10-master.conf`): `unix_listener /var/spool/postfix/private/dovecot-lmtp`

The socket lives inside Postfix's chroot (`/var/spool/postfix/`). Dovecot creates it; Postfix connects. Ownership must be `user = postfix`, `group = postfix`.

If mail arrives at Postfix but never appears in the user's mailbox, check:
1. `journalctl -u postfix | grep lmtp` for delivery errors
2. `ls -la /var/spool/postfix/private/dovecot-lmtp` for socket existence and permissions
3. `doveconf -n | grep lmtp` to confirm the listener is configured

### Postfix → Dovecot (SASL authentication)

Mail clients authenticate via Postfix's submission port (587), but Postfix delegates the actual password check to Dovecot via a second Unix socket:

- **Postfix** (`master.cf` submission section): `smtpd_sasl_type = dovecot`, `smtpd_sasl_path = private/auth`
- **Dovecot** (`10-master.conf`): `unix_listener /var/spool/postfix/private/auth`

Same socket-path coordination as LMTP. If clients get "authentication failed" on submission, check `doveadm auth test <user>` first (Dovecot-side), then socket path/permissions.

### Postfix → OpenDKIM (milter protocol)

Postfix passes every message through OpenDKIM before delivery (inbound: verify signature) and before sending (outbound: add signature):

- **Postfix** (`main.cf`): `smtpd_milters = local:opendkim/opendkim.sock`
- **OpenDKIM** (`opendkim.conf`): `Socket local:/run/opendkim/opendkim.sock`

The `local:` prefix in Postfix means Unix socket relative to its chroot. If OpenDKIM's socket is at `/run/opendkim/opendkim.sock`, the Postfix value should be `local:opendkim/opendkim.sock` (which resolves to `/var/spool/postfix/opendkim/opendkim.sock` inside the chroot).

Common fix: symlink or bind-mount the socket directory into Postfix's chroot, or use an inet socket (`inet:127.0.0.1:8891`) to avoid chroot path issues entirely.

### Certbot → Postfix + Dovecot (shared TLS certificates)

Both Postfix and Dovecot reference the same Let's Encrypt certificate:

```
# Postfix (main.cf)
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.example.com/fullchain.pem
smtpd_tls_key_file  = /etc/letsencrypt/live/mail.example.com/privkey.pem

# Dovecot (10-ssl.conf)
ssl_cert = </etc/letsencrypt/live/mail.example.com/fullchain.pem
ssl_key  = </etc/letsencrypt/live/mail.example.com/privkey.pem
```

Note: Dovecot requires the `<` prefix before the path (it means "read from file"). Postfix does not.

The deploy hook in `/etc/letsencrypt/renewal-hooks/deploy/` reloads both services after renewal. Without this hook, renewed certificates sit on disk while the services continue using the old ones from memory.

### DNS Records → All Components

DNS is the glue that makes everything work for the outside world:

| Record | Used by |
|--------|---------|
| MX | Sending MTAs look up where to deliver mail for your domain |
| A record for mail hostname | Resolves the MX target to your server IP |
| PTR (reverse DNS) | Receiving MTAs verify the sending IP's identity |
| SPF (TXT) | Receiving MTAs check if your IP is authorized to send for the domain |
| DKIM (TXT) | Receiving MTAs verify the cryptographic signature OpenDKIM attached |
| DMARC (TXT) | Receiving MTAs apply your policy when SPF or DKIM fails |

## Testing

### Send a test email

```bash
# From the server, send to an external address
echo "Test message from mail.example.com" | mail -s "Test" you@gmail.com
```

### Check delivery in Postfix logs

```bash
journalctl -u postfix --since "5 minutes ago" | grep -E "status=|reject|error"
# Look for: status=sent (250 2.0.0 OK)
```

### Verify DKIM signature on received mail

Open the received email's raw headers (Gmail: "Show original"). Look for:

```
Authentication-Results: mx.google.com;
       dkim=pass header.d=example.com header.s=mail;
       spf=pass ...;
       dmarc=pass ...
```

All three (DKIM, SPF, DMARC) should show `pass`.

### Test with external tools

```bash
# MX record
dig +short MX example.com

# SPF record
dig +short TXT example.com | grep spf

# DKIM record
dig +short TXT mail._domainkey.example.com

# DMARC record
dig +short TXT _dmarc.example.com

# Reverse DNS
dig -x 203.0.113.10 +short

# OpenDKIM key verification
opendkim-testkey -d example.com -s mail -vvv
```

Online tools:
- https://mxtoolbox.com/SuperTool.aspx — comprehensive DNS, blacklist, SMTP tests
- https://www.mail-tester.com/ — send a test email and get a deliverability score
- https://www.checktls.com/ — verify TLS configuration

### Test IMAP access

```bash
# Connect via openssl
openssl s_client -connect mail.example.com:993
# After connection, type:
# a1 LOGIN username password
# a2 LIST "" "*"
# a3 LOGOUT
```

### Test SMTP submission

```bash
# Test port 587 with STARTTLS
openssl s_client -starttls smtp -connect mail.example.com:587
# After connection, type:
# EHLO test
# AUTH PLAIN <base64-encoded credentials>
# QUIT
```

## Common Stack-Level Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Mail sent but lands in spam | SPF, DKIM, or DMARC failing; PTR mismatch; new IP reputation | Check headers for `fail` results; verify all DNS records; use mail-tester.com |
| Mail not received from outside | MX record missing/wrong, port 25 blocked by firewall, Postfix not listening on public interface | `dig MX example.com`; `ss -tlnp | grep :25`; check `inet_interfaces` in main.cf |
| Client can't connect to IMAP | Port 993 firewalled, Dovecot not running, TLS cert issue | `ufw allow 993/tcp`; `systemctl status dovecot`; `openssl s_client -connect mail.example.com:993` |
| Client can't send (auth failed on 587) | SASL socket mismatch, Dovecot auth config wrong | Check `doveadm auth test <user>`; verify socket exists at `/var/spool/postfix/private/auth` |
| DKIM signature not added to outbound mail | OpenDKIM not running, milter socket mismatch, domain not in signing config | `systemctl status opendkim`; check `smtpd_milters` path; verify `InternalHosts` includes sending IP |
| TLS cert expired, clients rejecting connection | Certbot renewal failed or deploy hook missing | `certbot certificates`; `certbot renew --dry-run`; check deploy hook exists and is executable |
| Outbound mail stuck in queue | Port 25 blocked outbound (cloud provider default) | `nc -zv smtp.gmail.com 25`; request port 25 unblock or configure SMTP relay |
| Dovecot LMTP delivery fails | Socket path mismatch between Postfix and Dovecot | Compare `postconf mailbox_transport` with Dovecot's `service lmtp` listener path |

## See Also

- **certbot** — TLS certificate management details, challenge types, renewal hooks
- **sshd** — secure shell access to the mail server for administration
- **fail2ban** — rate-limit brute-force login attempts against Postfix and Dovecot
- **ufw** / **firewalld** — firewall rules for mail ports

## References

See `references/` for:
- `dns-records.md` — required DNS records with complete examples for a sample domain
- `docs.md` — official documentation links for each component
