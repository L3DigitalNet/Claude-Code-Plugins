---
name: postfix
description: >
  Postfix MTA (mail transfer agent) administration: configuration, queue
  management, relay setup, TLS, SASL authentication, virtual domains, and
  deliverability troubleshooting.
  MUST consult when installing, configuring, or troubleshooting postfix.
triggerPhrases:
  - "postfix"
  - "MTA"
  - "mail server"
  - "sendmail postfix"
  - "SMTP server"
  - "postfix relay"
  - "main.cf"
  - "postfix queue"
  - "mailq"
  - "postqueue"
  - "smtpd"
  - "master.cf"
  - "mail relay"
  - "outbound mail"
  - "DKIM postfix"
globs:
  - "**/postfix/main.cf"
  - "**/postfix/master.cf"
  - "**/postfix/*.cf"
last_verified: "unverified"
---

## Identity
- **Unit**: `postfix.service` (systemd); master process is `/usr/lib/postfix/sbin/master`
- **Config**: `/etc/postfix/main.cf` (main parameters), `/etc/postfix/master.cf` (daemon table)
- **Queue dirs**: `/var/spool/postfix/` — subdirs: `active`, `deferred`, `hold`, `incoming`, `corrupt`
- **Logs**: `journalctl -u postfix`, `/var/log/mail.log` (Debian/Ubuntu), `/var/log/maillog` (RHEL/Fedora)
- **Ports**: 25/tcp (SMTP), 587/tcp (submission/MSA), 465/tcp (SMTPS legacy)
- **Distro install**: `apt install postfix` / `dnf install postfix`
- **Lookup table rebuild**: `postmap /etc/postfix/<table>` — required after editing hash-type maps

## Quick Start

```bash
sudo apt install postfix            # install (select "Internet Site" when prompted)
sudo systemctl enable postfix       # enable on boot
sudo systemctl start postfix        # start the service
sudo postfix check                  # validate config syntax
postconf myhostname mydomain        # verify key parameters
```

## Key Operations

| Task | Command |
|------|---------|
| Service status | `systemctl status postfix` |
| Start / stop / restart | `systemctl start\|stop\|restart postfix` |
| Reload config (no restart) | `sudo postfix reload` |
| Test config syntax | `sudo postfix check` |
| Show all active parameters | `postconf -n` (non-default only) or `postconf` (all) |
| Show single parameter value | `postconf myhostname` |
| Send test email | `echo "Test body" \| mail -s "Test subject" user@example.com` |
| Send test with sendmail syntax | `echo -e "Subject: Test\n\nBody" \| sendmail -v recipient@example.com` |
| Check queue (all messages) | `mailq` or `postqueue -p` |
| Queue message count | `postqueue -p \| tail -1` |
| Flush deferred queue now | `sudo postqueue -f` |
| Flush queue for one domain | `sudo postqueue -s example.com` |
| View message content | `sudo postcat -q <queue-id>` |
| Remove one message from queue | `sudo postsuper -d <queue-id>` |
| Remove all deferred messages | `sudo postsuper -d ALL deferred` |
| Hold a message | `sudo postsuper -h <queue-id>` |
| Release held message | `sudo postsuper -H <queue-id>` |
| Re-queue held messages | `sudo postsuper -H ALL hold` |
| Trace message routing | `sudo postmap -q user@example.com virtual` |
| Test SMTP connection locally | `telnet localhost 25` then `EHLO test` |
| Check if port 25 is reachable | `nc -zv mail.example.com 25` |
| Check outbound port 25 blocked | `nc -zv smtp.gmail.com 25` (timeout = ISP/cloud block) |
| View active SMTP connections | `ss -tnp \| grep :25` |
| Test postmap hash lookup | `postmap -q "key" hash:/etc/postfix/virtual` |
| View mail log live | `journalctl -u postfix -f` or `tail -f /var/log/mail.log` |

## Expected Ports

- **25/tcp** (SMTP): Server-to-server mail transfer; often blocked outbound by ISPs and cloud providers
- **587/tcp** (Submission/MSA): Authenticated client submission; use this for sending from mail clients
- **465/tcp** (SMTPS): Legacy implicit TLS submission; still used by some clients

Verify listening: `ss -tlnp | grep master`
Firewall (ufw): `sudo ufw allow 25,587/tcp`
Firewall (firewalld): `sudo firewall-cmd --add-service=smtp --permanent && sudo firewall-cmd --reload`

## Health Checks

1. `systemctl is-active postfix` → `active`
2. `sudo postfix check 2>&1` → no output means no errors
3. `postconf myhostname mydomain myorigin` → values match your actual hostname and domain
4. `echo "test" | sendmail -v root` → check `journalctl -u postfix -n 20` for delivery attempt

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Connection refused` on port 25 from outside | Cloud/ISP blocks outbound port 25 | `nc -zv smtp.gmail.com 25`; use SMTP relay (SendGrid, SES, Mailjet) on port 587 instead |
| `Relay access denied` | `inet_interfaces` or `mynetworks` too restrictive | `postconf inet_interfaces mynetworks`; add sending host to `mynetworks` or use SASL auth |
| `Unknown user in local recipient table` | Missing alias or `local_recipient_maps` too strict | Add to `/etc/aliases` then `newaliases`; or set `local_recipient_maps =` (empty) to disable check |
| Mail rejected by recipient (DNSBL) | Server IP on a spam blocklist | Check https://mxtoolbox.com/blacklists.aspx; request delisting or switch to relay service |
| Queue backing up, deferred messages growing | DNS resolution failure, destination unreachable, or rate limit | `postqueue -p` to see reason; `journalctl -u postfix | grep deferred`; check `defer_transports` |
| `TLS handshake failed` | Certificate expired, wrong path, or protocol mismatch | `postconf smtpd_tls_cert_file`; verify cert with `openssl x509 -in /path/to/cert.pem -noout -dates` |
| `fatal: open /etc/postfix/main.cf: No such file or directory` | Postfix not installed or config missing | `apt install postfix` / `dnf install postfix`; run `postfix check` |
| Mail delivered but lands in spam | Missing or failing SPF/DKIM/DMARC | Check headers of received mail; set up SPF DNS record, install opendkim, publish DMARC policy |
| Reverse DNS mismatch causing rejection | PTR record doesn't match `myhostname` | `dig -x <your-ip>`; update PTR with hosting provider to match `myhostname` in main.cf |
| `Postfix is already running` on start | Stale PID file | `rm /var/spool/postfix/pid/master.pid`; `systemctl start postfix` |

## Pain Points

- **Most cloud providers block outbound port 25** — AWS, GCP, Azure, DigitalOcean all restrict it by default. Configure Postfix as a null client relaying through an SMTP provider (SendGrid, SES, Mailjet) using port 587 with SASL. This is the standard homelab/cloud setup.
- **Deliverability requires SPF, DKIM, and DMARC** — running your own MTA without these guarantees spam folder delivery. SPF is a DNS TXT record, DKIM requires `opendkim`, DMARC ties them together. None of this is automatic.
- **`postmap` must be run after editing lookup tables** — changes to any `hash:` map file (virtual, transport, access, etc.) have no effect until you run `postmap /etc/postfix/<filename>`. Common source of "why isn't my alias working" confusion.
- **`main.cf` changes need `postfix reload`** — editing the file is not enough. `postfix reload` applies changes without dropping connections; `postfix check` validates before reloading.
- **Reverse DNS (PTR record) should match `myhostname`** — many receiving servers check that the connecting IP's PTR record matches the EHLO hostname. Mismatch triggers spam scoring or outright rejection. Set your PTR at the hosting provider level.
- **Greylisting at receiving servers delays first-time deliveries** — a new server sending to a well-protected domain may wait 5–30 minutes for the first message to be accepted. This is normal behavior, not a Postfix problem. Subsequent messages go through immediately.

## See Also

- **dovecot** — IMAP/POP3 server for receiving and storing mail delivered by Postfix
- **opendkim** — DKIM signing daemon integrated with Postfix via milter
- **certbot** — Automated TLS certificate management for Postfix SMTP encryption

## References
See `references/` for:
- `main.cf.annotated` — complete main.cf with every directive explained
- `common-patterns.md` — relay setup, null client, SASL, virtual domains, TLS, queue management
- `docs.md` — official documentation links
