---
name: openssl-cli
description: >
  openssl CLI certificate and TLS operations: PEM inspection, live server checks,
  key generation, CSR creation, self-signed certs, chain verification, expiry
  checking, key/cert matching, format conversion, and OCSP.
  MUST consult when inspecting certificates, generating keys, or debugging TLS.
triggerPhrases:
  - "openssl"
  - "certificate inspect"
  - "TLS check"
  - "ssl certificate"
  - "generate key"
  - "CSR"
  - "self-signed certificate"
  - "verify certificate"
  - "certificate chain"
  - "certificate expiry"
globs:
  - "**/*.pem"
  - "**/*.crt"
  - "**/*.key"
  - "**/*.csr"
  - "**/*.p12"
  - "**/*.pfx"
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `openssl` |
| **Config** | `/etc/ssl/openssl.cnf` (rarely edited directly) |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install openssl` / `dnf install openssl` (pre-installed on most distros) |

## Quick Start

```bash
sudo apt install openssl
openssl version                        # verify installation
openssl x509 -in cert.pem -text -noout # inspect a certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 90 -nodes  # self-signed cert
echo Q | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | openssl x509 -noout -enddate  # check remote cert expiry
```

## Key Operations

| Task | Command |
|------|---------|
| Inspect a PEM certificate | `openssl x509 -in cert.pem -text -noout` |
| Check expiry date only | `openssl x509 -in cert.pem -enddate -noout` |
| Check live server certificate | `echo Q \| openssl s_client -connect host:443 -servername host 2>/dev/null \| openssl x509 -text -noout` |
| Show certificate chain from server | `echo Q \| openssl s_client -connect host:443 -servername host -showcerts 2>/dev/null` |
| Generate RSA private key (4096-bit) | `openssl genrsa -out key.pem 4096` |
| Generate EC private key (P-256) | `openssl ecparam -name prime256v1 -genkey -noout -out ec-key.pem` |
| Create CSR from existing key | `openssl req -new -key key.pem -out request.csr` |
| Create self-signed cert (90 days) | `openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 90 -nodes` |
| Verify cert against CA bundle | `openssl verify -CAfile ca-bundle.crt cert.pem` |
| Check key matches certificate | `openssl rsa -modulus -noout -in key.pem \| md5sum` and `openssl x509 -modulus -noout -in cert.pem \| md5sum` |
| Convert PEM to DER | `openssl x509 -in cert.pem -outform DER -out cert.der` |
| Convert DER to PEM | `openssl x509 -in cert.der -inform DER -outform PEM -out cert.pem` |
| Export to PKCS12 (PFX) | `openssl pkcs12 -export -in cert.pem -inkey key.pem -out bundle.p12` |
| Import PKCS12 to PEM | `openssl pkcs12 -in bundle.p12 -out combined.pem -nodes` |
| Decode base64 | `openssl base64 -d -in encoded.b64 -out decoded.bin` |
| Check OCSP status | `openssl ocsp -issuer ca.pem -cert cert.pem -url $(openssl x509 -in cert.pem -noout -ocsp_uri)` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Output is an unreadable PEM blob | Forgot `-noout` with `-text` | Always combine: `openssl x509 -text -noout -in cert.pem` |
| `s_client` hangs waiting for input | `s_client` opens an interactive TLS session | Pipe `echo Q` to it: `echo Q \| openssl s_client -connect host:443` |
| Server returns wrong cert (wrong vhost) | SNI not sent by default | Add `-servername yourdomain.com` to `s_client` |
| `verify error: num=20: unable to get local issuer certificate` | Intermediate CA missing from chain | Concatenate intermediates into the bundle: `cat cert.pem intermediate.pem > fullchain.pem` |
| `openssl verify` exits 0 but shows errors | Some OpenSSL versions exit 0 even on verify failure | Check stderr explicitly: `openssl verify ... 2>&1 \| grep -i error` |
| LibreSSL (macOS) rejects a flag | LibreSSL lacks some OpenSSL options | Use a Homebrew-installed `openssl@3` and invoke via `/usr/local/opt/openssl/bin/openssl` |
| Key and cert moduli don't match | Wrong key was used to sign the CSR | Regenerate the CSR from the correct key, or re-issue the cert |

## Pain Points

- **`-noout` is almost always required with `-text`**: Without it, `x509 -text` dumps both the human-readable block and the raw PEM. The PEM output is rarely useful and makes the readable section hard to find.
- **`s_client` stays open by default**: It opens a live TLS connection and waits for you to type. Always pipe `echo Q` (or `echo | openssl s_client ...`) to send an immediate EOF and get output you can process.
- **SNI is not automatic**: When a server hosts multiple domains on one IP, `s_client` without `-servername` may return the default (wrong) certificate. Always pass `-servername domain.com` to match what browsers send.
- **Certificate chain order matters for servers**: Servers should present the leaf certificate first, intermediates next, and omit the root CA (clients already have it). A chain in the wrong order causes TLS handshake failures on some clients even though every certificate is valid.
- **LibreSSL vs OpenSSL on macOS**: macOS ships LibreSSL under the `openssl` binary name, but it doesn't support all OpenSSL options. Install `openssl@3` via Homebrew for full compatibility when writing cross-platform scripts.

## See Also

- **certbot** — automated Let's Encrypt certificate management (uses openssl under the hood)
- **step-ca** — private certificate authority for internal services
- **ssh-keygen** — SSH key management (complementary to TLS certificate operations)
- **age** — modern file encryption as an alternative to openssl enc

## References

See `references/` for:
- `cheatsheet.md` — certificate inspection, key generation, CSR creation, format conversion patterns
- `docs.md` — official documentation links
