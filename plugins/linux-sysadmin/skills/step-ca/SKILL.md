---
name: step-ca
description: >
  Smallstep step-ca private certificate authority: initialization, provisioner
  configuration, certificate issuance and renewal, client bootstrapping, ACME
  integration, SSH CA, and mTLS.
  MUST consult when installing, configuring, or troubleshooting Smallstep step-ca PKI.
triggerPhrases:
  - "step-ca"
  - "smallstep"
  - "internal CA"
  - "private CA"
  - "step certificate"
  - "ACME internal"
  - "homelab HTTPS"
  - "mTLS"
  - "step ca init"
  - "step ca certificate"
  - "step ca bootstrap"
  - "JWK provisioner"
  - "OIDC provisioner"
globs:
  - "**/ca.json"
  - "**/config/ca.json"
last_verified: "unverified"
---

## Identity
- **Binary**: `step-ca` (the CA server), `step` (the CLI client)
- **Config**: `$(step path)/config/ca.json` — typically `~/.step/config/ca.json` or `/etc/step-ca/config/ca.json` when running as a service
- **Root CA cert**: `$(step path)/certs/root_ca.crt`
- **Intermediate cert**: `$(step path)/certs/intermediate_ca.crt`
- **Service**: `step-ca.service` (systemd) or a Docker container
- **Default port**: 9000 (configurable in `ca.json` → `address`)
- **Logs**: `journalctl -u step-ca` (systemd) or container stdout

## Quick Start

```bash
wget https://dl.smallstep.com/gh-release/certificates/docs-cli-install/v0.27.5/step-ca_0.27.5_amd64.deb
sudo dpkg -i step-ca_*.deb
step ca init                           # interactive CA setup
step-ca $(step path)/config/ca.json    # start CA (foreground test)
sudo systemctl enable --now step-ca
```

## Key Operations

| Task | Command |
|------|---------|
| Initialize new CA | `step ca init` |
| Start CA (foreground) | `step-ca $(step path)/config/ca.json` |
| Start CA (systemd) | `sudo systemctl start step-ca` |
| Check service status | `systemctl status step-ca` |
| Health check endpoint | `curl -k https://localhost:9000/health` |
| Issue a certificate | `step ca certificate myhost.local myhost.crt myhost.key` |
| Issue with SAN | `step ca certificate myhost.local myhost.crt myhost.key --san myhost.local --san 192.168.1.10` |
| Renew certificate (manual) | `step ca renew myhost.crt myhost.key` |
| Renew (daemon mode) | `step ca renew --daemon myhost.crt myhost.key` |
| Revoke certificate | `step ca revoke --cert myhost.crt` |
| Inspect certificate | `step certificate inspect myhost.crt` |
| Inspect CA health + version | `step ca health` |
| List provisioners | `step ca provisioner list` |
| Add ACME provisioner | `step ca provisioner add acme --type ACME` |
| Add JWK provisioner | `step ca provisioner add myprovisioner --type JWK` |
| Add OIDC provisioner | `step ca provisioner add sso --type OIDC --oidc-client-id ... --oidc-configuration-endpoint ...` |
| Bootstrap a new host | `step ca bootstrap --ca-url https://ca.internal:9000 --fingerprint <root-fingerprint>` |
| Test ACME challenge | `step ca certificate --provisioner acme test.internal test.crt test.key` |
| Get root fingerprint | `step certificate fingerprint $(step path)/certs/root_ca.crt` |
| Trust root cert (system) | `step certificate install $(step path)/certs/root_ca.crt` |

## Expected State
- CA server is running and listening on port 9000 (or configured address)
- Root CA certificate is installed in the OS trust store on every client that will communicate with services using step-ca-issued certs
- Clients have run `step ca bootstrap` to configure their local `step` CLI to trust the CA
- At least one provisioner is configured in `ca.json`

## Health Checks
1. `systemctl is-active step-ca` → `active`
2. `curl -k https://localhost:9000/health` → `{"status":"ok"}`
3. `step ca certificate test.check /tmp/test.crt /tmp/test.key && step certificate inspect /tmp/test.crt` → shows valid cert with correct issuer

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `x509: certificate signed by unknown authority` | Root CA not trusted on the client | Run `step certificate install $(step path)/certs/root_ca.crt` on the client, or distribute and trust the root cert manually |
| ACME order fails with `provisioner not found` | No ACME provisioner configured | `step ca provisioner list`; add one with `step ca provisioner add acme --type ACME` then restart step-ca |
| Certificate expired unexpectedly | Default ACME lifetime is 24h — much shorter than Let's Encrypt's 90 days | Use `step ca renew --daemon` or a cron job; configure longer lifetimes in `ca.json` policy |
| `step ca bootstrap` errors: `connection refused` | step-ca not running or wrong `--ca-url` | `systemctl status step-ca`; verify the URL and port; check firewall |
| Wrong CA URL in client config | Bootstrap run with wrong `--ca-url` | Re-run `step ca bootstrap --ca-url https://correct-host:9000 --fingerprint <fp>` |
| `step-ca.service` fails to start | Bad `ca.json` (missing key, wrong path) | `journalctl -u step-ca -n 50`; validate JSON and check all referenced file paths exist |
| `permission denied` on key files | Key files not readable by the service user | `ls -l $(step path)/secrets/`; `chown` to the step-ca service user |
| `failed to decrypt` on startup | Wrong or missing password for intermediate key | Confirm the password file path in `ca.json` → `password`; re-enter interactively with `step-ca $(step path)/config/ca.json` |

## Pain Points
- **Root CA trust is not automatic**: The root cert must be explicitly installed on every client — every OS, browser, Docker container, and app that needs to verify certs. `step certificate install` handles the OS store, but app-level stores (Java, Python, Firefox) need separate handling.
- **Short default lifetimes**: ACME-issued certs expire in 24h by default. This is intentional for zero-trust but requires automated renewal from day one. `step ca renew --daemon` handles this, but it must be set up as a service for every cert-bearing host.
- **Bootstrap is a per-host operation**: Every host that issues or validates certs must run `step ca bootstrap` to configure the step CLI's CA URL and root fingerprint. There is no network-discoverable default.
- **ACME provisioner requires a password**: Unlike public ACME (Let's Encrypt), step-ca's ACME provisioner still requires a provisioner password stored on the CA server. Clients do not see or need this password, but it must be present on the CA.
- **Caddy integration is zero-config once bootstrapped**: Caddy's built-in ACME client talks directly to step-ca using the ACME provisioner URL. After `step ca bootstrap` on the Caddy host and setting `acme_ca` in the Caddyfile, Caddy handles all issuance and renewal with no manual cert management.

## See Also

- **certbot** — public ACME client for Let's Encrypt certificates (internet-facing domains)
- **openssl-cli** — inspect, verify, and convert certificates issued by step-ca

## References
See `references/` for:
- `common-patterns.md` — CA init, client bootstrap, ACME setup, Caddy integration, SSH CA, mTLS, and renewal patterns
- `docs.md` — official documentation and reference links
