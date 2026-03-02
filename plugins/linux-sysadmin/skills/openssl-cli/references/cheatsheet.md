# openssl CLI Command Reference

Each block below is copy-paste-ready. Substitute `cert.pem`, `key.pem`,
`host`, and paths for your actual files and hostnames.

---

## 1. Inspect a Certificate File

```bash
# Full human-readable dump (suppress PEM output with -noout)
openssl x509 -in cert.pem -text -noout

# Show only the subject (who the cert is for)
openssl x509 -in cert.pem -subject -noout

# Show only the issuer (who signed it)
openssl x509 -in cert.pem -issuer -noout

# Show expiry date only
openssl x509 -in cert.pem -enddate -noout

# Show Subject Alternative Names (SANs)
openssl x509 -in cert.pem -ext subjectAltName -noout

# Show serial number
openssl x509 -in cert.pem -serial -noout
```

---

## 2. Check a Live Server Certificate

```bash
# Connect and inspect the returned certificate
echo Q | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -text -noout

# Check expiry of a live server's cert
echo Q | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -enddate -noout

# Show the full certificate chain
echo Q | openssl s_client -connect example.com:443 -servername example.com -showcerts 2>/dev/null

# Connect on a non-standard port (e.g., SMTP STARTTLS)
echo Q | openssl s_client -connect mail.example.com:587 -starttls smtp -servername mail.example.com 2>/dev/null

# Check TLS version negotiated
echo Q | openssl s_client -connect example.com:443 2>/dev/null | grep 'Protocol'
```

---

## 3. Generate Keys

```bash
# RSA private key (4096-bit)
openssl genrsa -out key.pem 4096

# RSA key encrypted with a passphrase
openssl genrsa -aes256 -out key-encrypted.pem 4096

# EC private key (P-256, widely supported)
openssl ecparam -name prime256v1 -genkey -noout -out ec-key.pem

# EC key (P-384, higher security)
openssl ecparam -name secp384r1 -genkey -noout -out ec-key-384.pem

# List available EC curve names
openssl ecparam -list_curves
```

---

## 4. Create CSR and Self-Signed Certificates

```bash
# Create a CSR from an existing key (interactive prompts)
openssl req -new -key key.pem -out request.csr

# Create a CSR non-interactively
openssl req -new -key key.pem -out request.csr \
  -subj "/C=US/ST=California/L=San Francisco/O=Example Inc/CN=example.com"

# Self-signed cert (90 days, no passphrase on key)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 90 -nodes \
  -subj "/CN=example.com"

# Self-signed cert with SANs (requires an extensions config)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes \
  -subj "/CN=example.com" \
  -addext "subjectAltName=DNS:example.com,DNS:www.example.com,IP:192.168.1.10"

# View a CSR
openssl req -in request.csr -text -noout
```

---

## 5. Verify Certificates and Chains

```bash
# Verify a cert against the system CA bundle
openssl verify cert.pem

# Verify against a specific CA file
openssl verify -CAfile ca.crt cert.pem

# Verify a full chain (intermediate + root in one file)
cat intermediate.pem root.pem > chain-bundle.pem
openssl verify -CAfile chain-bundle.pem cert.pem

# Verify that a key matches a certificate (moduli must match)
openssl rsa -modulus -noout -in key.pem | md5sum
openssl x509 -modulus -noout -in cert.pem | md5sum
# Both md5sum outputs must be identical

# Check OCSP status
OCSP_URL=$(openssl x509 -in cert.pem -noout -ocsp_uri)
openssl ocsp -issuer intermediate.pem -cert cert.pem -url "$OCSP_URL" -text
```

---

## 6. Format Conversion

```bash
# PEM to DER (binary)
openssl x509 -in cert.pem -outform DER -out cert.der

# DER to PEM
openssl x509 -in cert.der -inform DER -outform PEM -out cert.pem

# Export cert + key to PKCS12 (PFX) bundle
openssl pkcs12 -export -in cert.pem -inkey key.pem -out bundle.p12 -name "myalias"

# Add certificate chain to PKCS12
openssl pkcs12 -export -in cert.pem -inkey key.pem -certfile chain.pem -out bundle.p12

# Extract cert and key from PKCS12 (no passphrase on output)
openssl pkcs12 -in bundle.p12 -out combined.pem -nodes

# Extract cert only from PKCS12
openssl pkcs12 -in bundle.p12 -nokeys -out cert-only.pem
```

---

## 7. Encrypt and Decrypt Files

```bash
# Encrypt a file with AES-256-CBC (password-based)
openssl enc -aes-256-cbc -pbkdf2 -in plaintext.txt -out encrypted.bin

# Decrypt
openssl enc -d -aes-256-cbc -pbkdf2 -in encrypted.bin -out plaintext.txt

# Encrypt with a key derived from a passphrase, output base64
openssl enc -aes-256-cbc -pbkdf2 -a -in plaintext.txt -out encrypted.b64

# Decrypt base64-encoded file
openssl enc -d -aes-256-cbc -pbkdf2 -a -in encrypted.b64 -out plaintext.txt
```

Note: For modern file encryption, prefer `age` over `openssl enc`. openssl enc
uses symmetric encryption without authenticated encryption (no AEAD by default
in older versions).

---

## 8. Hashing and Base64

```bash
# SHA-256 hash of a file
openssl dgst -sha256 file.tar.gz

# SHA-256 in hex only (no filename prefix)
openssl dgst -sha256 -r file.tar.gz | awk '{print $1}'

# MD5 hash (legacy — avoid for security purposes)
openssl dgst -md5 file

# Base64 encode
openssl base64 -in binary.bin -out encoded.b64

# Base64 decode
openssl base64 -d -in encoded.b64 -out binary.bin

# Base64 encode a string (no trailing newline issue)
echo -n "secret string" | openssl base64
```

---

## 9. Generate Random Data

```bash
# Generate 32 random bytes as hex
openssl rand -hex 32

# Generate a random base64 string (32 bytes = ~44 chars)
openssl rand -base64 32

# Generate a random passphrase-style string
openssl rand -base64 24 | tr -d '/+=' | cut -c1-20
```

---

## 10. Certificate Expiry Monitoring

```bash
# Check if a cert expires within 30 days (exit 1 if yes)
openssl x509 -in cert.pem -checkend $((30 * 86400)) -noout

# Script to alert on expiring certs in a directory
for cert in /etc/ssl/certs/*.pem; do
  if ! openssl x509 -in "$cert" -checkend $((30 * 86400)) -noout 2>/dev/null; then
    expiry=$(openssl x509 -in "$cert" -enddate -noout | cut -d= -f2)
    echo "EXPIRING: $cert — $expiry"
  fi
done

# Check a live server's cert expiry
EXPIRY=$(echo Q | openssl s_client -connect example.com:443 -servername example.com 2>/dev/null \
  | openssl x509 -enddate -noout | cut -d= -f2)
echo "Expires: $EXPIRY"
```
