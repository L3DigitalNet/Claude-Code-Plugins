---
name: curl-wget
description: >
  curl and wget HTTP client tools: GET and POST requests, JSON payloads,
  authentication, header inspection, TLS options, resumable downloads,
  rate limiting, and wget recursive mirroring.
  MUST consult when writing curl or wget commands for HTTP requests or downloads.
triggerPhrases:
  - "curl"
  - "wget"
  - "HTTP request"
  - "download file"
  - "API request"
  - "POST request"
  - "HTTP headers"
  - "follow redirect"
  - "basic auth"
  - "certificate"
  - "http get"
  - "http post"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `curl`, `wget` |
| **Config** | `~/.curlrc` (curl), `~/.wgetrc` (wget) |
| **Logs** | No persistent logs — output to terminal |
| **Type** | CLI tool |
| **Install** | `apt install curl wget` / `dnf install curl wget` |

## Quick Start

```bash
sudo apt install curl wget
curl -s https://api.example.com/health | jq '.'
curl -o file.tar.gz https://example.com/file.tar.gz
wget https://example.com/file.tar.gz
curl -X POST -H 'Content-Type: application/json' -d '{"key":"val"}' https://api.example.com/
```

## Key Operations

| Task | Command |
|------|---------|
| GET request | `curl https://example.com/api/v1/items` |
| Follow redirects | `curl -L https://example.com` |
| Save output to file | `curl -o output.json https://example.com/data.json` |
| Save using remote filename | `curl -O https://example.com/file.tar.gz` |
| POST with form data | `curl -X POST -d 'key=value&other=123' https://example.com/form` |
| POST JSON body | `curl -X POST -H 'Content-Type: application/json' -d '{"key":"value"}' https://api.example.com/` |
| Show response headers only | `curl -I https://example.com` |
| Show headers and body | `curl -v https://example.com` |
| Silent (no progress bar) | `curl -s https://example.com/api` |
| Fail on HTTP error (4xx/5xx) | `curl -sf https://example.com/api` |
| Basic auth | `curl -u username:password https://example.com/api` |
| Bearer token | `curl -H 'Authorization: Bearer TOKEN' https://api.example.com/` |
| Skip TLS verification (testing only) | `curl -k https://self-signed.example.com` |
| Use client certificate | `curl --cert client.crt --key client.key https://api.example.com/` |
| Resume interrupted download | `curl -C - -O https://example.com/large.tar.gz` |
| Limit download speed | `curl --limit-rate 500k -O https://example.com/large.tar.gz` |
| POST file as body | `curl -X POST --data @payload.json -H 'Content-Type: application/json' https://api.example.com/` |
| wget: simple download | `wget https://example.com/file.tar.gz` |
| wget: recursive download | `wget -r -np https://example.com/files/` |
| wget: mirror a site | `wget --mirror --convert-links https://example.com/` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| Script ignores HTTP 404/500 errors | curl exits 0 on HTTP errors unless `--fail` is set | Add `-f` (`--fail`) so curl exits non-zero on 4xx/5xx |
| `curl: (60) SSL certificate problem` | Self-signed or expired cert | Use `-k` for testing; for production, fix the cert or provide `-cacert ca.crt` |
| Redirect not followed | Missing `-L` flag | Add `-L` to follow 301/302/307 redirects |
| `@` in `-d` data causes "file not found" | curl treats `@` in `-d` as a file reference | URL-encode as `%40`, or use `--data-urlencode 'field=user@example.com'` |
| `--data @file` sends literal `@file` text | Used `--data` instead of `--data-binary` or correct flag | Use `--data @filename` — the `@` prefix means "read from file" (it works as documented) |
| wget downloads HTML index instead of file | Server returns directory listing for the URL | Append the actual filename to the URL, or use `curl -O` |
| Rate limit not working | `--limit-rate` uses bytes/s by default (K/M suffixes optional) | Use `--limit-rate 500k` for 500 KB/s or `--limit-rate 5m` for 5 MB/s |

## Pain Points

- **curl exits 0 on HTTP errors**: By default, curl treats any HTTP response as success. A script that does `curl https://api/ && do_thing` will call `do_thing` even on a 503. Add `-f` or `--fail` to fix this; combine with `-s` to suppress progress noise in scripts.
- **`-o` vs `-O` are easy to confuse**: `-o filename` saves to a local name you specify. `-O` saves using the remote filename from the URL. Using the wrong one either overwrites an unintended file or saves to a confusing name.
- **`-k` skips TLS verification silently**: There is no warning in the output that certificate validation was skipped. Fine for internal testing; dangerous in production scripts or CI where it may mask certificate problems.
- **URL-encoding gotchas with `-d`**: `-d` sends data URL-encoded if you build it as `key=value`, but if your value contains `&`, `+`, or `@`, they need manual encoding or use `--data-urlencode key=value` which handles the encoding automatically.
- **wget is simpler for downloads, weaker for APIs**: wget follows redirects by default and handles resumption well, but lacks curl's header/auth/body control. For anything beyond a simple download, prefer curl.

## See Also

- **openssl-cli** — TLS certificate inspection and debugging for connection issues

## References
See `references/` for:
- `cheatsheet.md` — task-organized command reference
- `docs.md` — official documentation links
