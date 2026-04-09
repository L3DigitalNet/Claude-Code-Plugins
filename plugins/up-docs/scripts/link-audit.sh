#!/usr/bin/env bash
# link-audit.sh — Extract and verify links from markdown content.
#
# Usage: link-audit.sh <markdown-file> [--timeout 10]
#        echo '<markdown>' | link-audit.sh - [--timeout 10]
# Requires: curl
# Output: JSON with external/internal link status.
# Exit:   0 on success, 1 if curl not found.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

command -v curl >/dev/null 2>&1 \
  || { echo '{"error":"curl not found — required for link verification"}' >&2; exit 1; }

FILE="${1:--}"
shift || true

TIMEOUT=10
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

# Read content
if [[ "$FILE" == "-" ]]; then
  CONTENT=$(cat)
elif [[ -f "$FILE" ]]; then
  CONTENT=$(cat "$FILE")
else
  echo "{\"error\":\"file not found: $FILE\"}" >&2
  exit 1
fi

export CONTENT TIMEOUT

$PYTHON << 'PYEOF'
import json, os, re, subprocess, sys
from urllib.parse import urlparse

content = os.environ.get("CONTENT", "")
timeout = int(os.environ.get("TIMEOUT", "10"))

# Extract links
MD_LINK = re.compile(r'\[([^\]]*)\]\(([^)]+)\)')
AUTOLINK = re.compile(r'<(https?://[^>]+)>')
BARE_URL = re.compile(r'(?<!\()(https?://[^\s<>\[\]()]+)')

links = []
seen = set()

for m in MD_LINK.finditer(content):
    text, url = m.group(1), m.group(2)
    if url not in seen:
        seen.add(url)
        links.append({"text": text, "url": url})

for m in AUTOLINK.finditer(content):
    url = m.group(1)
    if url not in seen:
        seen.add(url)
        links.append({"text": "", "url": url})

for m in BARE_URL.finditer(content):
    url = m.group(0).rstrip(".,;:!?)")
    if url not in seen:
        seen.add(url)
        links.append({"text": "", "url": url})

# Classify and check links
external = {"live": [], "dead": [], "redirect": [], "timeout": [], "rate_limited": []}
internal = {"valid": [], "broken": [], "needs_verification": []}

# Extract headings for anchor checking
headings = set()
for line in content.splitlines():
    m = re.match(r'^#{1,6}\s+(.+)', line)
    if m:
        slug = re.sub(r'[^\w\s-]', '', m.group(1).lower())
        slug = re.sub(r'\s+', '-', slug.strip())
        headings.add(slug)

# Track domains that returned 429
rate_limited_domains = set()

for link in links:
    url = link["url"]

    # Internal anchor
    if url.startswith("#"):
        anchor = url[1:]
        if anchor in headings:
            internal["valid"].append({"text": link["text"], "target": anchor})
        else:
            internal["broken"].append({"text": link["text"], "target": anchor})
        continue

    # Internal/relative link
    if not url.startswith("http://") and not url.startswith("https://"):
        internal["needs_verification"].append({"text": link["text"], "target": url})
        continue

    # External link
    parsed = urlparse(url)
    domain = parsed.netloc

    # Skip if domain is rate limited
    if domain in rate_limited_domains:
        external["rate_limited"].append({"url": url, "status": 429})
        continue

    try:
        r = subprocess.run(
            ["curl", "-sIL", "-o", "/dev/null", "-w", "%{http_code} %{url_effective}",
             "--max-time", str(timeout), "--connect-timeout", "5", url],
            capture_output=True, text=True, timeout=timeout + 5
        )
        parts = r.stdout.strip().split(None, 1)
        status = int(parts[0]) if parts else 0
        final_url = parts[1] if len(parts) > 1 else url

        if status == 429:
            external["rate_limited"].append({"url": url, "status": 429})
            rate_limited_domains.add(domain)
        elif 200 <= status < 300:
            external["live"].append({"url": url, "status": status})
        elif 300 <= status < 400:
            external["redirect"].append({"url": url, "status": status, "final_url": final_url})
        else:
            external["dead"].append({"url": url, "status": status})

    except subprocess.TimeoutExpired:
        external["timeout"].append({"url": url, "error": "Connection timed out"})
    except Exception as e:
        external["timeout"].append({"url": url, "error": str(e)[:100]})

ext_checked = sum(len(v) for v in external.values())

result = {
    "total_links": len(links),
    "external": external,
    "internal": internal,
    "summary": {
        "external_checked": ext_checked,
        "external_live": len(external["live"]),
        "external_dead": len(external["dead"]),
        "external_redirect": len(external["redirect"]),
        "external_timeout": len(external["timeout"]),
        "external_rate_limited": len(external["rate_limited"]),
    },
}

print(json.dumps(result, indent=2))
PYEOF
