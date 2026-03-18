---
name: opendkim
description: >
  OpenDKIM daemon administration: DKIM key generation, signing and verification,
  Postfix milter integration, DNS TXT record publishing, and troubleshooting.
  MUST consult when installing, configuring, or troubleshooting opendkim.
triggerPhrases:
  - "opendkim"
  - "DKIM"
  - "email signing"
  - "DKIM key"
  - "mail authentication"
  - "SPF DKIM DMARC"
  - "opendkim Postfix"
globs:
  - "**/opendkim.conf"
  - "**/opendkim/**"
last_verified: "unverified"
---

## Identity
- **Unit**: `opendkim.service`
- **Daemon**: `opendkim`
- **Config**: `/etc/opendkim.conf`
- **Key directory**: `/etc/opendkim/keys/`
- **Socket**: `/run/opendkim/opendkim.sock` (unix) or `127.0.0.1:8891` (inet)
- **User**: `opendkim`
- **Milter group**: `opendkim` (Postfix user must be a member)
- **Logs**: `journalctl -u opendkim`, `/var/log/mail.log` (milter events appear in mail log)
- **Distro install**: `apt install opendkim opendkim-tools` / `dnf install opendkim`

## Quick Start

```bash
sudo apt install opendkim opendkim-tools       # install daemon and key tools
sudo systemctl enable opendkim                  # enable on boot
sudo systemctl start opendkim                   # start the service
opendkim-genkey -b 2048 -d example.com -s mail  # generate DKIM key pair
opendkim-testkey -d example.com -s mail -vvv    # verify DNS record matches key
```

## Key Operations

| Task | Command |
|------|---------|
| Status | `systemctl status opendkim` |
| Generate key pair | `opendkim-genkey -b 2048 -d example.com -s mail -D /etc/opendkim/keys/example.com/` |
| List current keys | `ls -la /etc/opendkim/keys/` |
| Print public key (for DNS) | `cat /etc/opendkim/keys/example.com/mail.txt` |
| Check key file permissions | `stat /etc/opendkim/keys/example.com/mail.private` (must be 600, owned by opendkim) |
| Test signing config | `opendkim-testkey -d example.com -s mail -vvv` |
| Verify DNS record live | `dig +short TXT mail._domainkey.example.com` |
| Check DKIM signature on received mail | Inspect `Authentication-Results:` header in received message |
| Reload config (no restart) | `sudo systemctl reload opendkim` |
| Check Postfix milter connection | `postfix check 2>&1` and inspect `/var/log/mail.log` for milter errors |
| Verify Postfix smtpd_milters setting | `postconf smtpd_milters non_smtpd_milters` |
| Watch milter activity in real time | `journalctl -u opendkim -f` |

## Expected State
- `opendkim.service` is `active (running)`
- Socket or port 8891 is listening: `ss -xlnp | grep opendkim` (unix) or `ss -tlnp | grep 8891` (inet)
- Postfix connects on every outbound message — no `milter` errors in `/var/log/mail.log`
- Outbound messages carry `DKIM-Signature:` header
- `opendkim-testkey` exits 0 for all active selectors

## Health Checks
1. `systemctl is-active opendkim` → `active`
2. `opendkim-testkey -d example.com -s mail -vvv` → `key OK` (confirms DNS record matches private key)
3. Send a test message to a Gmail or similar address, view raw headers — confirm `DKIM=pass` in `Authentication-Results`

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `opendkim: key retrieval failed` in mail log | DNS not yet propagated, wrong selector, or record format error | `dig +short TXT mail._domainkey.example.com` — compare output to `mail.txt`; wait for TTL or fix record |
| `milter: can't read response` / Postfix can't connect | Wrong socket path in Postfix config, or opendkim not running | Verify `smtpd_milters` matches `Socket` in `opendkim.conf`; `systemctl start opendkim` |
| `Permission denied` on socket | Postfix `www-data`/`postfix` user not in `opendkim` group | `adduser postfix opendkim && systemctl restart postfix opendkim` |
| `No signing table match for ...` | Sender domain/address not in `SigningTable` | Add matching line to `/etc/opendkim/signing.table`; reload opendkim |
| Public key in DNS truncated or split | DNS provider split long TXT record incorrectly | Ensure record is a single quoted string or properly chunked 255-byte segments joined without space |
| Key file permissions too open | opendkim refuses to use a world-readable private key | `chmod 600 /etc/opendkim/keys/example.com/mail.private && chown opendkim:opendkim ...` |
| `opendkim-testkey: invalid key` | Key pair mismatch — DNS has old public key after regeneration | Re-publish `mail.txt` content to DNS; wait for propagation |
| Outbound mail missing `DKIM-Signature` | `Mode` lacks `s` (sign), or domain not in `Domain` | Check `Mode sv` and `Domain` directive in `opendkim.conf` |

## Pain Points
- **DNS propagation delay**: After publishing the TXT record, `opendkim-testkey` will fail until the record is live. Test with `dig` before enabling signing — a signing failure can cause mail to be treated as suspicious.
- **Key file ownership is enforced**: opendkim silently refuses a private key that is world-readable or not owned by the `opendkim` user. Always `chown opendkim:opendkim` and `chmod 600` after generating.
- **TXT record format is exact**: The DNS record must match `v=DKIM1; k=rsa; p=<base64>` with no extra whitespace. The `mail.txt` file from `opendkim-genkey` contains the exact value — use it verbatim.
- **Multiple selectors enable zero-downtime key rotation**: Publish the new selector's DNS record, add the new key to `KeyTable`/`SigningTable`, reload, then remove the old selector's DNS record after the old TTL expires.
- **DMARC requires alignment**: DMARC passes only when the DKIM signing domain aligns with the `From:` header domain AND/OR SPF passes on the envelope sender. DKIM alone is insufficient for DMARC compliance.
- **`opendkim` group membership takes effect only on next login/service restart**: After `adduser postfix opendkim`, restart both `postfix` and `opendkim`.
- **InternalHosts controls what gets signed**: Only mail originating from listed hosts/IPs gets signed. If Postfix is on a different IP or loopback is not listed, outbound mail will not be signed.

## See Also

- **postfix** — MTA that integrates with OpenDKIM via the milter protocol
- **dovecot** — IMAP/POP3 server for the mail delivery pipeline alongside DKIM-signed messages

## References
See `references/` for:
- `opendkim.conf.annotated` — full config with every directive explained, plus KeyTable/SigningTable format, Postfix milter config, and DNS record examples
- `docs.md` — official documentation, man pages, RFC, and validation tools
