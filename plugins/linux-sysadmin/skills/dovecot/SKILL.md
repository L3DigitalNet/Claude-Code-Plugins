---
name: dovecot
description: >
  Dovecot IMAP/POP3 server administration: configuration, authentication,
  mail storage, SSL/TLS, quota, LMTP delivery, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting dovecot.
triggerPhrases:
  - "dovecot"
  - "IMAP server"
  - "POP3 server"
  - "dovecot mail"
  - "dovecot SSL"
  - "mail delivery agent"
  - "MDA dovecot"
  - "LMTP dovecot"
  - "doveadm"
  - "doveconf"
  - "imap-login"
  - "pop3-login"
  - "passdb"
  - "userdb"
  - "Maildir dovecot"
globs:
  - "**/dovecot.conf"
  - "**/dovecot/**/*.conf"
  - "**/conf.d/*.conf"
last_verified: "unverified"
---

## Identity
- **Unit**: `dovecot.service`
- **Config**: `/etc/dovecot/dovecot.conf`, `/etc/dovecot/conf.d/` (include-based)
- **Logs**: `journalctl -u dovecot`, `/var/log/dovecot.log` (if configured)
- **Mail storage**: Maildir (`~/Maildir/`) or mbox (`/var/mail/`)
- **Ports**: 143 (IMAP), 993 (IMAPS), 110 (POP3), 995 (POP3S), 24 (LMTP local)
- **User**: `dovecot` (daemon processes), `dovenull` (login process pre-auth)
- **Distro install**: `apt install dovecot-imapd dovecot-pop3d` / `dnf install dovecot`

## Quick Start

```bash
sudo apt install dovecot-imapd dovecot-pop3d   # install IMAP and POP3 support
sudo systemctl enable dovecot                   # enable on boot
sudo systemctl start dovecot                    # start the service
doveconf -n                                     # verify effective config (non-defaults)
doveadm auth test <username>                    # test user authentication
```

## Key Operations

| Task | Command |
|------|---------|
| Status | `systemctl status dovecot` |
| Test / dump config | `doveconf -n` (non-defaults only); `doveconf -a` (all settings) |
| Reload after config change | `sudo systemctl reload dovecot` |
| Restart | `sudo systemctl restart dovecot` |
| Test user authentication | `doveadm auth test <username>` |
| List user's mailboxes | `doveadm mailbox list -u <user>` |
| Force IMAP index resync | `doveadm force-resync -u <user> INBOX` |
| Check user quota | `doveadm quota get -u <user>` |
| Recalculate quota | `doveadm quota recalc -u <user>` |
| Fetch message headers | `doveadm fetch -u <user> 'text.header' mailbox INBOX all` |
| Change log verbosity at runtime | `doveadm log reopen` (after editing `log_debug` in conf) |
| Show running services | `doveadm service status` |
| Kick active session | `doveadm kick <username>` |
| Who is logged in | `doveadm who` |

## Expected Ports
- 143/tcp (IMAP STARTTLS), 993/tcp (IMAPS)
- 110/tcp (POP3 STARTTLS), 995/tcp (POP3S)
- 24/tcp or Unix socket (LMTP — local delivery from Postfix)
- Verify: `ss -tlnp | grep dovecot`
- Firewall: `sudo ufw allow 143,993/tcp` (and 110/995 if POP3 needed)

## Health Checks
1. `systemctl is-active dovecot` → `active`
2. `doveconf -n 2>&1` → no errors; `ssl` should not be `no` on a production server
3. `doveadm auth test <user>` → `auth succeeded`
4. `ss -tlnp | grep ':143\|:993\|:110\|:995'` → dovecot listed on expected ports

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Authentication failed` | Wrong passdb lookup, PAM not configured, or password mismatch | `doveadm auth test <user>`; check `/etc/dovecot/conf.d/10-auth.conf` passdb driver; inspect PAM config in `/etc/pam.d/dovecot` |
| `Mailbox doesn't exist` | Wrong `mail_location` or namespace path, mail not yet delivered | Check `mail_location` in `10-mail.conf`; verify the Maildir exists: `ls ~/Maildir/` |
| TLS handshake fails / `SSL_accept() failed` | Cert or key path wrong, file unreadable by dovecot user, or protocol mismatch | `doveconf ssl_cert ssl_key`; check file permissions; verify cert chain with `openssl verify` |
| `Permission denied` on mailbox dir | Mail directory owned by wrong user or restrictive umask | `ls -la ~/Maildir`; check `mail_privileged_group` in `10-mail.conf` |
| LMTP rejects connections from Postfix | Socket path mismatch, wrong permissions, or service not enabled | Compare `lmtp_socket_path` in Postfix `master.cf` with `service lmtp` socket path in `10-master.conf`; check socket ownership |
| `Quota exceeded` | User over limit; quota dict not synced | `doveadm quota get -u <user>`; `doveadm quota recalc -u <user>` to force recount |
| passdb / userdb mismatch: auth succeeds but mail not found | passdb and userdb use different user/home resolution | Ensure userdb returns correct `home` field; test with `doveadm user <username>` |
| Login process crashes immediately | `disable_plaintext_auth = yes` with non-TLS client | Client must use STARTTLS or connect to port 993; or temporarily allow plaintext for debugging |
| `login: Disconnected: Inactivity` | Client idle timeout | Normal for broken clients; check `auth_failure_delay` and `login_max_inactivity` if occurring excessively |

## Pain Points
- **conf.d is include-based**: Dovecot splits config across `10-auth.conf`, `10-mail.conf`, `10-master.conf`, etc. A setting in the wrong file or commented out in a non-obvious include silently falls back to the default. Use `doveconf -n` to see the effective resolved config — not the raw file.
- **Maildir vs mbox**: Maildir (`~/Maildir/`) is the standard for modern setups — one file per message, safe for concurrent access. mbox is a single file per folder and prone to corruption under load. The choice is permanent once mail is delivered; migration requires `doveadm backup`.
- **LMTP requires Postfix integration**: Dovecot does not receive mail directly. Postfix must be configured to hand off to Dovecot's LMTP socket or port. Socket path and permissions must match on both sides; a mismatch produces silent delivery failures logged only in Postfix.
- **auth-master socket permissions**: Services that authenticate against Dovecot (e.g., Postfix SASL) use the `auth-userdb` or `auth-master` socket. The socket must be writable by the Postfix user (`postfix` or `mail`). This is set via `mode`, `user`, and `group` under `service auth` in `10-master.conf`.
- **SSL is not optional**: `ssl = no` disables encryption entirely. On any network-exposed server, set `ssl = required` and configure valid cert/key paths. Using self-signed certs requires clients to accept the cert — use Let's Encrypt or a proper CA for production. The cert file must include the full chain.

## See Also

- **postfix** — MTA that delivers mail to Dovecot via LMTP
- **opendkim** — DKIM signing/verification for mail passing through Postfix before Dovecot delivery

## References
See `references/` for:
- `dovecot.conf.annotated` — annotated config covering all key conf.d files
- `docs.md` — official documentation and integration guides
