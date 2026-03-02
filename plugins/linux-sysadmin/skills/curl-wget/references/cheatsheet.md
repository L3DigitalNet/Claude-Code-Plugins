# curl and wget Command Reference

Each block below is copy-paste-ready. Substitute URLs, credentials, filenames,
and JSON payloads for your actual values.

---

## 1. Basic GET Requests

```bash
# Simple GET (output to stdout)
curl https://api.example.com/v1/items

# Pretty-print JSON response
curl -s https://api.example.com/v1/items | jq '.'

# Follow redirects
curl -L https://short.url/abc

# Show only HTTP status code
curl -s -o /dev/null -w "%{http_code}" https://example.com

# Silent output (no progress bar, errors only)
curl -s https://api.example.com/v1/status
```

---

## 2. Saving Files

```bash
# Save with a specified local filename
curl -o /tmp/data.json https://example.com/data.json

# Save using the remote filename from the URL
curl -O https://example.com/release-v1.0.0.tar.gz

# wget: download with progress bar
wget https://example.com/file.tar.gz

# wget: download quietly (no output)
wget -q https://example.com/file.tar.gz

# wget: save to a different filename
wget -O /tmp/myfile.tar.gz https://example.com/file.tar.gz
```

---

## 3. POST Requests

```bash
# POST with form-encoded data
curl -X POST -d 'username=alice&password=secret' https://example.com/login

# POST JSON body
curl -X POST \
  -H 'Content-Type: application/json' \
  -d '{"key": "value", "count": 42}' \
  https://api.example.com/items

# POST JSON from a file
curl -X POST \
  -H 'Content-Type: application/json' \
  --data @payload.json \
  https://api.example.com/items

# URL-encode a value automatically
curl -X POST --data-urlencode 'email=user@example.com' https://example.com/subscribe

# PUT request (update resource)
curl -X PUT \
  -H 'Content-Type: application/json' \
  -d '{"status": "active"}' \
  https://api.example.com/items/42
```

---

## 4. Authentication

```bash
# Basic auth
curl -u username:password https://api.example.com/

# Bearer token
curl -H 'Authorization: Bearer eyJhbGciOi...' https://api.example.com/

# API key in header
curl -H 'X-API-Key: your-api-key' https://api.example.com/

# API key as query parameter
curl 'https://api.example.com/data?api_key=your-api-key'

# Netrc file for credentials (avoids secrets in command line)
# ~/.netrc: machine api.example.com login alice password secret
curl --netrc https://api.example.com/
```

---

## 5. Headers and Response Inspection

```bash
# Show only response headers (HEAD request)
curl -I https://example.com

# Show request and response headers (verbose)
curl -v https://example.com 2>&1 | head -40

# Add a custom request header
curl -H 'Accept: application/json' -H 'X-Custom: value' https://api.example.com/

# Show specific response header values
curl -s -D - -o /dev/null https://example.com | grep -i 'content-type\|server'

# Follow redirects and show final URL
curl -Ls -o /dev/null -w '%{url_effective}' https://short.url/abc
```

---

## 6. TLS and Certificate Handling

```bash
# Skip TLS verification (testing only — never in production)
curl -k https://self-signed.internal/

# Provide a custom CA bundle
curl --cacert /etc/ssl/custom/ca-bundle.crt https://internal.example.com/

# Client certificate authentication
curl --cert client.crt --key client.key https://mtls.example.com/

# Client cert from PKCS12 bundle
curl --cert-type P12 --cert bundle.p12:passphrase https://mtls.example.com/

# Verify a specific TLS version
curl --tlsv1.3 https://example.com
```

---

## 7. Download Resumption and Rate Limiting

```bash
# Resume an interrupted download
curl -C - -O https://example.com/large-file.tar.gz

# wget: resume download
wget -c https://example.com/large-file.tar.gz

# Limit download speed (curl: bytes/s with K/M suffix)
curl --limit-rate 500k -O https://example.com/file.tar.gz

# wget: limit download speed
wget --limit-rate=500k https://example.com/file.tar.gz

# Retry on transient errors
curl --retry 3 --retry-delay 2 -O https://example.com/file.tar.gz
```

---

## 8. Error Handling in Scripts

```bash
# Exit non-zero on HTTP 4xx/5xx errors
curl -sf https://api.example.com/health

# Exit non-zero on error AND show error message
curl -Sf https://api.example.com/health

# Capture HTTP status code and response separately
HTTP_CODE=$(curl -s -o /tmp/response.json -w "%{http_code}" https://api.example.com/)
if [ "$HTTP_CODE" -ne 200 ]; then
  echo "Error: HTTP $HTTP_CODE"
  cat /tmp/response.json
  exit 1
fi

# Timeout: fail if no response within 10 seconds
curl --max-time 10 https://api.example.com/slow-endpoint

# Connect timeout (separate from total time)
curl --connect-timeout 5 --max-time 30 https://api.example.com/
```

---

## 9. wget: Recursive and Mirror Downloads

```bash
# Recursive download, don't go to parent directories
wget -r -np https://example.com/files/

# Mirror a site (recursive + timestamps + convert links)
wget --mirror --convert-links --page-requisites https://example.com/

# Download only specific file types
wget -r -np -A '*.pdf,*.zip' https://example.com/downloads/

# Restrict recursion depth
wget -r -l 2 https://example.com/

# Mirror with a local output directory
wget --mirror -P /tmp/mirror https://example.com/
```

---

## 10. Useful curl One-Liners

```bash
# Check if an endpoint is up (exit 0 = up, non-zero = down)
curl -sf https://api.example.com/health > /dev/null && echo "up" || echo "down"

# Download and pipe directly to tar
curl -L https://example.com/archive.tar.gz | tar -xz -C /tmp/

# Time a request
curl -s -o /dev/null -w "connect: %{time_connect}s\ntotal: %{time_total}s\n" https://example.com

# POST and pretty-print JSON response in one step
curl -s -X POST -H 'Content-Type: application/json' -d '{"q":"test"}' https://api.example.com/ | jq '.'

# GET with multiple headers and pipe to jq
curl -s \
  -H 'Authorization: Bearer TOKEN' \
  -H 'Accept: application/json' \
  https://api.example.com/users | jq '[.[] | {id, name, email}]'
```
