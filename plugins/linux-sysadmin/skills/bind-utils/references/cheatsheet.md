# dig / nslookup / host Command Reference

`dig` is the primary tool. `nslookup` and `host` are covered at the end for
reference. Most examples use `dig` — it gives the most diagnostic detail and
is the easiest to parse in scripts.

---

## 1. Basic Record Lookups

```bash
# A record (IPv4 address)
dig example.com
dig example.com A

# Short output (answer only, no header/authority/additional sections)
dig +short example.com

# AAAA record (IPv6 address)
dig example.com AAAA
dig +short example.com AAAA

# CNAME record
dig www.example.com CNAME
dig +short www.example.com CNAME

# All records (ANY — many resolvers no longer respond fully to ANY queries)
dig example.com ANY
```

---

## 2. Mail-Related Records (MX, SPF, DKIM, DMARC)

```bash
# MX records (mail exchangers, with priority)
dig MX example.com +short

# SPF record — lives in TXT records on the domain itself
dig TXT example.com +short
# Look for the record starting with "v=spf1"

# DKIM record — selector is set by your mail provider (e.g., "google", "mail", "s1")
# Format: <selector>._domainkey.<domain>
dig TXT google._domainkey.example.com +short
# Should return a TXT record containing "v=DKIM1; k=rsa; p=..."

# DMARC record — always at _dmarc.<domain>
dig TXT _dmarc.example.com +short
# Should return a record starting with "v=DMARC1;"

# Check if DMARC exists at all
dig TXT _dmarc.example.com | grep -c 'DMARC1' && echo "DMARC configured" || echo "No DMARC record"
```

---

## 3. Query a Specific DNS Server

Use this to bypass your local resolver's cache or to query an authoritative server directly.

```bash
# Query using Google's public resolver
dig @8.8.8.8 example.com

# Query using Cloudflare's public resolver
dig @1.1.1.1 example.com

# Query an authoritative nameserver directly (get authoritative answer)
dig @ns1.example.com example.com

# First find the authoritative nameservers, then query one directly
dig NS example.com +short   # → ns1.example.com., ns2.example.com.
dig @ns1.example.com example.com

# Compare your resolver's answer against an external one
diff <(dig +short example.com) <(dig +short @8.8.8.8 example.com)
```

---

## 4. Reverse DNS (PTR Records)

```bash
# PTR lookup for an IPv4 address
dig -x 93.184.216.34

# Short output (just the hostname)
dig -x 93.184.216.34 +short

# Manual PTR query (same as -x but explicit)
# For 93.184.216.34, reverse it to 34.216.184.93.in-addr.arpa
dig 34.216.184.93.in-addr.arpa PTR +short

# IPv6 PTR lookup (expand the address and reverse nibbles into ip6.arpa)
dig -x 2606:2800:220:1:248:1893:25c8:1946 +short
```

---

## 5. Trace Delegation Chain

`+trace` bypasses your resolver and walks the delegation from root to
authoritative, showing exactly what each level of the DNS hierarchy returns.

```bash
# Full trace from root to authoritative answer
dig +trace example.com

# Trace a specific record type
dig +trace MX example.com

# Trace with minimal output
dig +trace +short example.com

# What +trace reveals:
# - Which root server was queried
# - Which TLD (e.g., .com) nameserver responded
# - Which authoritative nameservers the TLD delegates to
# - What the authoritative NS returns directly
# This bypasses ALL caches — shows the live authoritative state
```

---

## 6. DNSSEC Validation

```bash
# Query with DNSSEC records (shows RRSIG, DS, DNSKEY)
dig +dnssec example.com

# Check if a domain has DNSSEC signed records
dig +dnssec example.com | grep -i 'RRSIG'

# Disable DNSSEC validation (bypass validator — shows if record exists despite DNSSEC issue)
dig +cd example.com     # +cd = checking disabled

# Check DS record (delegation signer — presence means DNSSEC is enabled for the domain)
dig DS example.com

# Check DNSKEY (the actual signing keys at the authoritative level)
dig DNSKEY example.com

# Diagnose SERVFAIL from DNSSEC mismatch:
# If this resolves but your normal query SERVFAILs, DNSSEC validation is the cause:
dig +cd example.com @your-resolver-ip
```

---

## 7. Check NS Delegation

```bash
# Find the authoritative nameservers for a domain
dig NS example.com

# Find the nameservers at the parent (TLD) level — confirms delegation is correct
dig NS example.com @a.gtld-servers.net.

# Check which TLD servers are authoritative for .com
dig NS com. @a.root-servers.net.

# Full delegation check: root → TLD → authoritative
dig +trace NS example.com

# Verify both NS records resolve correctly
for ns in $(dig NS example.com +short); do
  echo -n "$ns: "
  dig A $ns +short
done
```

---

## 8. Zone Transfer (AXFR)

Zone transfers return all records in a zone. Most servers restrict AXFR to
authorized IPs — these will fail with `Transfer failed` on locked-down servers.

```bash
# Attempt zone transfer (usually only works on intentionally open servers or in labs)
dig @ns1.example.com example.com AXFR

# List all records including glue records
dig @ns1.example.com example.com AXFR | grep -v ';'

# Test if zone transfer is allowed (security audit)
dig @ns1.example.com example.com AXFR | head -5
# If you see records (not just SOA), the zone is open to transfer
```

---

## 9. TTL and Propagation Checking

```bash
# See TTL in the answer (how long the record will be cached)
dig example.com     # TTL is the number before the record type in the ANSWER section

# Check SOA record for the zone's minimum TTL and serial number
dig SOA example.com
# Serial number changes when the zone is updated — compare before and after a change

# Force re-query by asking a resolver that is unlikely to have the record cached
dig @1.1.1.1 example.com     # Cloudflare
dig @9.9.9.9 example.com     # Quad9
dig @208.67.222.222 example.com  # OpenDNS

# Batch query from a file (one hostname per line)
while read host; do
  echo -n "$host: "
  dig +short "$host"
done < hosts.txt
```

---

## 10. nslookup and host (Quick Reference)

For when dig is not available or for quick one-off checks.

```bash
# nslookup: basic lookup
nslookup example.com

# nslookup: query specific server
nslookup example.com 8.8.8.8

# nslookup: specific record type
nslookup -type=MX example.com
nslookup -type=TXT example.com

# nslookup: reverse lookup
nslookup 93.184.216.34

# host: simplest lookup
host example.com

# host: specific record type
host -t MX example.com
host -t TXT example.com

# host: reverse lookup
host 93.184.216.34

# host: query a specific nameserver
host example.com 8.8.8.8

# host: verbose (shows query and full answer)
host -v example.com
```
