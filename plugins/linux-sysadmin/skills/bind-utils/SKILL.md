---
name: bind-utils
description: >
  DNS query and debugging tools — dig, nslookup, and host — for looking up
  DNS records, tracing delegation chains, diagnosing resolver behavior, and
  validating mail authentication records (SPF, DKIM, DMARC). Triggers on: dig,
  nslookup, host, dns query, dns lookup, dns record, dns debugging, resolve
  hostname, MX record, TXT record, SPF, DMARC, DKIM.
globs: []
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `dig`, `nslookup`, `host` |
| **Config** | `No persistent config — invoked directly` |
| **Logs** | `No persistent logs — output to terminal` |
| **Type** | CLI tools (from bind-utils / dnsutils package) |
| **Install** | `apt install bind9-dnsutils` / `dnf install bind-utils` |

## Key Operations

| Task | Command |
|------|---------|
| Basic A record lookup | `dig example.com` |
| Short output (just the answer) | `dig +short example.com` |
| Specify record type | `dig MX example.com` |
| Query a specific DNS server | `dig @8.8.8.8 example.com` |
| Trace full delegation chain | `dig +trace example.com` |
| Reverse lookup (PTR record) | `dig -x 93.184.216.34` |
| DNSSEC validation | `dig +dnssec example.com` |
| Zone transfer (AXFR) | `dig @ns1.example.com example.com AXFR` |
| No recursion (check authoritative answer) | `dig +norecurse @ns1.example.com example.com` |
| Check SPF record | `dig TXT example.com +short` |
| Check DKIM record | `dig TXT selector._domainkey.example.com +short` |
| Check DMARC record | `dig TXT _dmarc.example.com +short` |
| Check NS delegation | `dig NS example.com` |
| nslookup basic lookup | `nslookup example.com` |
| host simple lookup | `host example.com` |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `NXDOMAIN` | Name does not exist in DNS at all | Verify the record was actually created; check for typos; confirm the zone is properly delegated |
| `SERVFAIL` | Resolver failed to get an answer (misconfigured zone, DNSSEC validation failure, or unreachable authoritative server) | Query with `+cd` (check disabled) to bypass DNSSEC validation; query the authoritative nameserver directly with `@ns1.example.com` |
| PTR lookup returns wrong hostname or nothing | Reverse zone not configured, or ISP controls the PTR and it's unset | PTR records require the ISP or hosting provider to configure the reverse zone; you can't set your own PTR without controlling the reverse DNS zone |
| `+trace` gives different result from regular lookup | Resolver cache holds a different answer than the authoritative server currently serves | Query with `+nocache` or query the authoritative NS directly; wait for TTL to expire |
| Zone transfer refused | AXFR restricted to specific IPs on the authoritative server | Normal — AXFR is intentionally restricted; use individual record queries instead |
| DKIM record missing or malformed | Selector name wrong, or record not yet propagated | Verify selector with your mail provider; check propagation with `dig @8.8.8.8 TXT selector._domainkey.example.com` |
| Split-horizon gives different results inside vs. outside | Resolver returns internal view inside the network, external view from outside | Use `dig @8.8.8.8` or `dig @1.1.1.1` to explicitly query a public resolver from inside the network |

## Pain Points

- **`nslookup` and `host` are simpler but less informative than `dig`**: Use `dig` for any diagnostic work. `nslookup` has interactive and non-interactive modes but its output is less parseable and its behavior has quirks. `host` is convenient for quick lookups but lacks dig's filter and tracing capabilities.
- **`dig +short` is the fastest scripting path**: For automation or quick checks, `dig +short example.com A` returns just the IP(s), one per line, with no extra output to strip.
- **`+trace` follows the actual delegation chain**: It queries the root servers, then the TLD servers, then the authoritative servers in sequence — bypassing your local resolver's cache entirely. This is how to confirm a record actually exists at the authoritative level, not just in a cache.
- **DNSSEC errors differ from NXDOMAIN**: `SERVFAIL` with DNSSEC validation failure looks identical to a broken zone from the client's perspective. Use `dig +cd example.com` to disable DNSSEC checking and see if the record resolves — if it does, DNSSEC is the issue.
- **Split-horizon DNS misleads external diagnostics**: If your network runs internal DNS that returns RFC 1918 addresses for public names, querying from inside with your default resolver gives the internal view. Always query `@8.8.8.8` or `@1.1.1.1` explicitly when diagnosing external-facing DNS.
- **PTR records require ISP cooperation**: Reverse DNS (PTR records) lives in the `in-addr.arpa.` zone, which is delegated by IANA to the IP address owner — typically the ISP or hosting provider, not you. You cannot set your own PTR record without either controlling the reverse zone yourself or asking your provider to set it.
