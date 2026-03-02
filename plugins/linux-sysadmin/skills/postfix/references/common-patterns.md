# Postfix Common Patterns

Each section below is a complete, copy-paste-ready configuration for a specific task.
After any main.cf change, run `sudo postfix check` then `sudo postfix reload`.
After editing any `hash:` map file, run `postmap /etc/postfix/<filename>`.

---

## 1. Relay Through an SMTP Provider (SendGrid / SES / Mailjet)

The most common homelab and cloud server setup. Postfix accepts local mail and
forwards everything outbound through an authenticated relay. Avoids port 25 blocks
and gives you a reputable sending IP.

**`/etc/postfix/main.cf`** — add or change these lines:

```
# Send all outbound mail through the relay; [brackets] skip MX lookup.
relayhost = [smtp.sendgrid.net]:587

# Use SASL to authenticate to the relay.
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous

# Require TLS to the relay (credentials go over the wire).
smtp_tls_security_level = encrypt

# Don't deliver locally — relay everything (null client variant).
# Remove this line if you want local mailbox delivery too.
default_transport = smtp
```

**`/etc/postfix/sasl_passwd`** — credentials file:

For SendGrid (use API key as password, literal string "apikey" as username):
```
[smtp.sendgrid.net]:587    apikey:YOUR-SENDGRID-API-KEY
```

For AWS SES (use SMTP credentials from IAM, not your AWS console password):
```
[email-smtp.us-east-1.amazonaws.com]:587    YOUR-SES-SMTP-USERNAME:YOUR-SES-SMTP-PASSWORD
```

For Mailjet:
```
[in-v3.mailjet.com]:587    YOUR-MAILJET-API-KEY:YOUR-MAILJET-SECRET-KEY
```

Secure the file and build the hash:

```bash
sudo chmod 600 /etc/postfix/sasl_passwd
sudo postmap /etc/postfix/sasl_passwd
sudo postfix reload
```

---

## 2. Null Client (Send System Notifications Only)

The server only sends local mail (cron jobs, alerts, monitoring) outbound through
a relay. It never receives mail from the internet and has no local mailboxes.
This is the minimal secure configuration for most servers.

**`/etc/postfix/main.cf`**:

```
# Identity
myhostname = server1.example.com
myorigin = $mydomain

# Only listen on localhost — no external connections accepted.
inet_interfaces = loopback-only

# Don't deliver locally; relay everything.
mydestination =
local_transport = error:local mail delivery is disabled

# Relay all mail through your SMTP provider (see Pattern 1 for credentials).
relayhost = [smtp.sendgrid.net]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt

# Send root's mail to a real address.
# Also set in /etc/aliases: root: admin@example.com, then run newaliases.
```

**`/etc/aliases`**:

```
root:    admin@example.com
```

```bash
sudo newaliases && sudo postfix reload
```

---

## 3. Full Inbound + Outbound Mail Server (Basics)

Receives mail for your domain and delivers to local Maildir mailboxes. Use
Dovecot alongside this for IMAP access.

**`/etc/postfix/main.cf`**:

```
myhostname = mail.example.com
mydomain = example.com
myorigin = $mydomain

# Listen on all interfaces.
inet_interfaces = all
inet_protocols = ipv4

# Accept mail destined for these domains as local delivery.
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# Deliver to ~/Maildir/ (Dovecot will read this).
home_mailbox = Maildir/

# Trusted networks (local only for a standalone server).
mynetworks = 127.0.0.0/8

# TLS for inbound connections.
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.example.com/fullchain.pem
smtpd_tls_key_file  = /etc/letsencrypt/live/mail.example.com/privkey.pem
smtpd_tls_security_level = may
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Opportunistic TLS for outbound connections.
smtp_tls_security_level = may
smtp_tls_loglevel = 1

# Basic anti-spam restrictions.
smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    reject_rbl_client zen.spamhaus.org
```

DNS records needed (replace 1.2.3.4 with your server IP):
```
# A record
mail.example.com.  IN  A     1.2.3.4

# MX record (points to A record, not IP)
example.com.       IN  MX 10 mail.example.com.

# SPF (basic — allow only this server)
example.com.       IN  TXT   "v=spf1 mx -all"

# PTR record: set at your hosting provider to "mail.example.com"
```

---

## 4. SASL Authentication for the Submission Port (587)

Allows mail clients (Thunderbird, Mutt, etc.) to submit mail after authenticating.
Requires Dovecot to provide the SASL socket.

**Dovecot** (`/etc/dovecot/conf.d/10-master.conf`) — expose the auth socket to Postfix:

```
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0660
    user = postfix
    group = postfix
  }
}
```

**`/etc/postfix/main.cf`** — enable SASL:

```
smtpd_sasl_auth_enable = yes
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_security_options = noanonymous

smtpd_recipient_restrictions =
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination
```

**`/etc/postfix/master.cf`** — enable the submission service (uncomment and adjust):

```
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
```

```bash
sudo systemctl restart dovecot
sudo postfix reload
```

Test SASL authentication from the command line:

```bash
# Encode credentials: base64("\0user@example.com\0password")
echo -ne '\0user@example.com\0password' | base64
# Connect and test:
openssl s_client -starttls smtp -connect mail.example.com:587
# Then in the session:
EHLO test
AUTH PLAIN <base64-string>
```

---

## 5. Virtual Alias Domains

Map addresses in hosted domains to real delivery addresses without needing Unix
accounts for each one. Suitable for simple forwarding setups.

**`/etc/postfix/main.cf`**:

```
virtual_alias_maps = hash:/etc/postfix/virtual
```

**`/etc/postfix/virtual`**:

```
# Format: <virtual-address>    <real-delivery-address>
# Catch-all for a domain:
@oldomain.com                  admin@example.com

# Specific address mappings:
info@example.org               user1@example.com
sales@example.org              user2@example.com, user3@example.com

# Forward to external address:
alerts@example.com             oncall@company.com
```

```bash
sudo postmap /etc/postfix/virtual
sudo postfix reload
```

Test that the lookup works before reloading:

```bash
postmap -q "info@example.org" hash:/etc/postfix/virtual
```

---

## 6. SPF, DKIM, and DMARC Setup Overview

All three are required for reliable delivery to Gmail, Outlook, and other major
providers. Postfix itself doesn't handle DKIM signing — that requires `opendkim`.

**SPF** (DNS TXT record — no software needed):

```
# Allow only your MX server to send for this domain.
example.com.  IN  TXT  "v=spf1 mx -all"

# Allow a specific IP:
example.com.  IN  TXT  "v=spf1 ip4:1.2.3.4 -all"

# Allow a relay (e.g., SendGrid):
example.com.  IN  TXT  "v=spf1 include:sendgrid.net -all"
```

**DKIM** (requires `opendkim`):

```bash
# Install
apt install opendkim opendkim-tools

# Generate a key pair
opendkim-genkey -b 2048 -d example.com -s mail -D /etc/opendkim/keys/example.com/

# The .txt file contains the DNS TXT record to publish:
cat /etc/opendkim/keys/example.com/mail.txt

# DNS record format:
mail._domainkey.example.com.  IN  TXT  "v=DKIM1; k=rsa; p=<public-key>"
```

See the `opendkim` skill (if available) for full Postfix milter integration instructions.

**DMARC** (DNS TXT record — tells receivers what to do on SPF/DKIM failure):

```
# Start with p=none (monitoring only) before moving to quarantine or reject.
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=none; rua=mailto:dmarc@example.com"

# After verifying reports, tighten to quarantine then reject:
_dmarc.example.com.  IN  TXT  "v=DMARC1; p=reject; rua=mailto:dmarc@example.com"
```

Check alignment with: https://dmarcanalyzer.com or https://mxtoolbox.com/dmarc.aspx

---

## 7. Queue Management

```bash
# Show all queued messages with reason for deferral.
mailq
postqueue -p

# Count queued messages.
postqueue -p | grep -c "^[A-F0-9]"

# Flush all deferred messages now (retry immediately).
sudo postqueue -f

# Flush deferred mail for a specific destination domain.
sudo postqueue -s example.com

# View the full content of a specific queued message (get ID from mailq output).
sudo postcat -q A1B2C3D4E5

# Delete a specific message from the queue.
sudo postsuper -d A1B2C3D4E5

# Delete ALL deferred messages (use carefully).
sudo postsuper -d ALL deferred

# Delete all messages in ALL queues (use with extreme caution).
sudo postsuper -d ALL

# Hold a message (moves it to hold queue; won't be retried until released).
sudo postsuper -h A1B2C3D4E5

# Release all held messages back to the active/deferred queue.
sudo postsuper -H ALL hold

# Requeue a message (useful after fixing a config issue).
sudo postsuper -r A1B2C3D4E5
```

---

## 8. Testing Mail Flow

```bash
# Send a test email via mail command (requires mailutils/bsd-mailx).
echo "Test body from $(hostname)" | mail -s "Postfix test $(date)" you@example.com

# Send via sendmail directly (no mail command needed).
echo -e "To: you@example.com\nSubject: Test\n\nTest body" | sendmail -v you@example.com

# Watch the mail log in real time while sending.
journalctl -u postfix -f &
echo "test" | sendmail you@example.com

# Test SMTP manually (port 25).
telnet localhost 25
# Then:
EHLO test.local
MAIL FROM:<test@example.com>
RCPT TO:<you@example.com>
DATA
Subject: Manual test
.
QUIT

# Test submission port with STARTTLS (requires openssl).
openssl s_client -starttls smtp -connect localhost:587

# Verify MX records for a domain.
dig MX example.com

# Check if your server's sending IP has good reputation.
# Visit https://mxtoolbox.com/blacklists.aspx and enter your IP.

# Verify SPF record.
dig TXT example.com | grep spf

# Check what a remote server sees when your Postfix connects.
# (Sends a test to a mailbox you control, then view the Received headers.)
```

---

## 9. Reject Spam with Common Restrictions

Add these to `smtpd_recipient_restrictions` in order. Each `reject_*` line is
evaluated in sequence; the first match wins.

```
smtpd_recipient_restrictions =
    # Always permit trusted networks first.
    permit_mynetworks,
    permit_sasl_authenticated,

    # Reject clients with invalid HELO names (common spam indicator).
    reject_invalid_helo_hostname,
    reject_non_fqdn_helo_hostname,

    # Reject if sender domain doesn't exist in DNS.
    reject_unknown_sender_domain,

    # Reject if recipient domain doesn't exist in DNS.
    reject_unknown_recipient_domain,

    # Block IPs listed in the Spamhaus zen blocklist.
    # Check https://www.spamhaus.org/zen/ for usage policy.
    reject_rbl_client zen.spamhaus.org,

    # Block IPs listed in the Barracuda reputation list.
    # reject_rbl_client b.barracudacentral.org,

    # Final gate: reject relay attempts from unauthorized senders.
    reject_unauth_destination
```

**Note**: `reject_rbl_client` causes a DNS lookup per connection. High-volume
servers should run a local caching DNS resolver to reduce latency.

---

## 10. TLS Configuration

**Minimum recommended TLS setup** for a public-facing mail server:

```
# Server certificate and key (Let's Encrypt recommended).
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.example.com/fullchain.pem
smtpd_tls_key_file  = /etc/letsencrypt/live/mail.example.com/privkey.pem

# Offer STARTTLS on port 25; require it on port 587 (set in master.cf).
smtpd_tls_security_level = may

# Disable broken protocol versions.
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
smtp_tls_protocols  = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1

# Log TLS summary (level 1) for all inbound/outbound connections.
smtpd_tls_loglevel = 1
smtp_tls_loglevel  = 1

# TLS session cache to reduce handshake overhead.
smtpd_tls_session_cache_database = btree:${data_directory}/smtpd_scache
smtp_tls_session_cache_database  = btree:${data_directory}/smtp_scache

# Opportunistic TLS outbound (use TLS if available; don't require it).
smtp_tls_security_level = may
```

Check certificate expiry:
```bash
openssl x509 -in /etc/letsencrypt/live/mail.example.com/fullchain.pem -noout -dates
```

Test TLS negotiation to your server from outside:
```bash
openssl s_client -starttls smtp -connect mail.example.com:25
# Check the output for: Protocol, Cipher, and certificate chain
```

Online TLS checker: https://checktls.com or https://mxtoolbox.com/SuperTool.aspx
