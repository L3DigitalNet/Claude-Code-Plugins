# BIND9 Common Patterns

Each section below is a complete, copy-paste-ready configuration. Validate zone files with
`named-checkzone` and named.conf with `named-checkconf` before reloading.

---

## 1. Authoritative Server for a Domain

The minimal setup to serve a domain. This server answers queries for `example.com` but
does not perform recursive lookups for other domains.

**`/etc/bind/named.conf.options`** (Debian) or the `options{}` block in `/etc/named.conf` (RHEL):

```
options {
    directory "/var/cache/bind";
    listen-on port 53 { any; };
    listen-on-v6 port 53 { any; };

    // Authoritative-only: refuse recursive queries from the outside world.
    recursion no;
    allow-query { any; };

    // No zone transfers unless explicitly permitted per-zone.
    allow-transfer { none; };

    // Hide version string.
    version "none";

    dnssec-validation auto;
};
```

**`/etc/bind/named.conf.local`**:

```
zone "example.com" {
    type primary;
    file "/etc/bind/db.example.com";
    allow-transfer { none; };
};
```

**`/etc/bind/db.example.com`**:

```
$ORIGIN example.com.
$TTL 3600

@   IN SOA  ns1.example.com.  hostmaster.example.com. (
                2024031501  3600  900  604800  300 )

@   IN NS   ns1.example.com.
@   IN NS   ns2.example.com.

ns1 IN A    203.0.113.10
ns2 IN A    203.0.113.20

@   IN A    203.0.113.1
www IN A    203.0.113.1
mail IN A   203.0.113.5

@   IN MX   10 mail.example.com.
@   IN TXT  "v=spf1 mx -all"
```

Apply: `named-checkconf && named-checkzone example.com /etc/bind/db.example.com && rndc reload`

---

## 2. Recursive Resolver for an Internal Network

An internal DNS server that resolves all names on behalf of clients. It does not host
any zones — it forwards queries to the internet and caches results.

```
acl "internal" {
    10.0.0.0/8;
    172.16.0.0/12;
    192.168.0.0/16;
    127.0.0.1;
    ::1;
};

options {
    directory "/var/cache/bind";
    listen-on port 53 { any; };
    listen-on-v6 port 53 { any; };

    // Allow recursive queries only from internal network.
    recursion yes;
    allow-query     { internal; };
    allow-recursion { internal; };

    // Optional: forward all queries to upstream resolvers.
    // Remove these to have named resolve from the root hints directly.
    forwarders {
        8.8.8.8;
        8.8.4.4;
        1.1.1.1;
    };
    forward first;   // Fall back to full recursion if forwarders fail.

    dnssec-validation auto;
    version "none";
};
```

No zone definitions are needed for a pure recursive resolver. The default root hints
zone (`zone "." { type hint; file "/usr/share/dns/root.hints"; };`) is included by
`named.conf.default-zones` on Debian, or defined inline on RHEL.

---

## 3. Split-Horizon DNS (Internal vs External Views)

Serve different answers for the same domain depending on where the query comes from.
Clients on the internal network get private IPs; external clients get public IPs.

**Important**: When using views, ALL zones must be inside a view block — you cannot
mix global zones and view zones.

```
acl "internal" {
    192.168.0.0/16;
    127.0.0.1;
    ::1;
};

// Internal view: responds to queries from the internal network.
view "internal" {
    match-clients { internal; };
    recursion yes;

    zone "example.com" {
        type primary;
        file "/etc/bind/internal/db.example.com";
    };

    // Include default zones inside the view on Debian.
    include "/etc/bind/named.conf.default-zones";
};

// External view: responds to all other queries.
view "external" {
    match-clients { any; };
    recursion no;

    zone "example.com" {
        type primary;
        file "/etc/bind/external/db.example.com";
        allow-transfer { none; };
    };
};
```

**`/etc/bind/internal/db.example.com`** — returns private IPs:

```
$ORIGIN example.com.
$TTL 300
@   IN SOA ns1 hostmaster ( 2024031501 3600 900 604800 300 )
@   IN NS  ns1
ns1 IN A   192.168.1.10
@   IN A   192.168.1.1      ; internal server IP
www IN A   192.168.1.1
```

**`/etc/bind/external/db.example.com`** — returns public IPs:

```
$ORIGIN example.com.
$TTL 3600
@   IN SOA ns1.example.com. hostmaster.example.com. ( 2024031501 3600 900 604800 300 )
@   IN NS  ns1.example.com.
ns1 IN A   203.0.113.10
@   IN A   203.0.113.1      ; public server IP
www IN A   203.0.113.1
```

Validate both zone files before reloading:

```
named-checkzone example.com /etc/bind/internal/db.example.com
named-checkzone example.com /etc/bind/external/db.example.com
named-checkconf /etc/bind/named.conf
rndc reload
```

---

## 4. Zone Transfer (Primary to Secondary)

The primary allows the secondary to fetch the full zone via AXFR. NOTIFY messages
trigger the secondary to check for updates automatically after each zone reload.

**Primary `/etc/bind/named.conf.local`**:

```
acl "secondaries" {
    192.168.1.20;    // secondary server IP
};

zone "example.com" {
    type primary;
    file "/etc/bind/db.example.com";

    // Allow zone transfers only to listed secondaries.
    allow-transfer { secondaries; };

    // Send NOTIFY to secondaries so they pull changes promptly.
    notify yes;

    // Also notify these IPs even if not in the NS records.
    // also-notify { 192.168.1.20; };
};
```

**Secondary `/etc/bind/named.conf.local`**:

```
zone "example.com" {
    type secondary;

    // Tell named where to find the primary for this zone.
    masters { 192.168.1.10; };

    // named writes the transferred zone here for use after restart.
    // This path must be writable by the named user.
    file "/var/lib/bind/db.example.com.secondary";
};
```

Manually trigger a zone transfer check:

```
rndc retransfer example.com
```

Verify transfer completed on the secondary:

```
journalctl -u named -n 50 | grep "transfer of 'example.com'"
dig @localhost example.com SOA +short
```

---

## 5. Reverse DNS (PTR Records)

PTR records map IP addresses to hostnames. The zone name is the network address
reversed with `.in-addr.arpa` appended.

| Network | Zone name |
|---------|-----------|
| 192.168.1.0/24 | `1.168.192.in-addr.arpa` |
| 192.168.0.0/16 | `168.192.in-addr.arpa` |
| 10.0.0.0/8 | `10.in-addr.arpa` |
| 2001:db8::/32 (IPv6) | `8.b.d.0.1.0.0.2.ip6.arpa` |

**`/etc/bind/named.conf.local`**:

```
zone "1.168.192.in-addr.arpa" {
    type primary;
    file "/etc/bind/db.192.168.1";
    allow-transfer { secondaries; };
};
```

**`/etc/bind/db.192.168.1`**:

```
$ORIGIN 1.168.192.in-addr.arpa.
$TTL 3600

@   IN SOA  ns1.example.com.  hostmaster.example.com. (
                2024031501  3600  900  604800  300 )

@   IN NS   ns1.example.com.
@   IN NS   ns2.example.com.

; Only the last octet is used in the owner field.
; "10" expands to 10.1.168.192.in-addr.arpa.
10  IN PTR  ns1.example.com.
20  IN PTR  ns2.example.com.
1   IN PTR  example.com.
5   IN PTR  mail.example.com.
100 IN PTR  client1.example.com.
```

Validate and reload:

```
named-checkzone 1.168.192.in-addr.arpa /etc/bind/db.192.168.1
rndc reload
dig @localhost -x 192.168.1.10 +short    # should return ns1.example.com.
```

---

## 6. Adding and Modifying Records

The safe workflow for editing a zone file manually:

1. Edit the zone file — add, change, or remove records.
2. Increment the SOA serial number. The YYYYMMDDNN convention: if today is 2024-03-15
   and this is the first change of the day, use `2024031501`. If you already changed it
   today, increment the last two digits: `2024031502`.
3. Validate: `named-checkzone example.com /etc/bind/db.example.com`
4. Reload the zone: `rndc reload example.com`
5. Verify: `dig @localhost newrecord.example.com A +short`

Adding a new A record:

```
; Before
$TTL 3600
@   IN SOA ns1.example.com. hostmaster.example.com. (
                2024031501 ...

; After — only two lines change: the serial and the new record
@   IN SOA ns1.example.com. hostmaster.example.com. (
                2024031502 ...    ; incremented

api IN A    192.168.1.50          ; new record
```

Changing an existing record:

```
; Before
www IN A    192.168.1.1

; After — lower the TTL first (in a previous reload), then change the IP
; so that clients with the old record cached see the change quickly.
www IN A    192.168.1.2

; Remember to increment the serial.
```

---

## 7. Wildcard Records

A wildcard matches any name under the zone that has no explicit record of that type.

```
; Wildcard A record — catches anything.example.com not otherwise defined.
*   IN A    192.168.1.1

; Wildcard MX — not recommended; use explicit MX records instead.
; *  IN MX  10 mail.example.com.
```

Wildcard limitations:
- Wildcards do not match multi-level names: `*.example.com` does NOT match `a.b.example.com`.
- An explicit record always takes precedence over a wildcard at the same level.
- Wildcards at the zone apex (`@`) are not valid for NS or SOA records.
- DNSSEC and wildcards interact in complex ways (NSEC/NSEC3 covering); test before deploying.

---

## 8. Mail Records (MX + SPF TXT)

A complete mail configuration for `example.com` using one primary and one backup MX,
with an SPF policy that authorizes only those mail servers.

```
; MX records — lower priority number = preferred server.
; Target must be an A/AAAA record, not a CNAME.
@   IN MX   10  mail1.example.com.
@   IN MX   20  mail2.example.com.

mail1   IN A    203.0.113.5
mail2   IN A    203.0.113.6

; SPF TXT record — defines who may send email for this domain.
; "mx" authorizes all servers listed in MX records.
; "-all" means hard fail for everyone else (recommended for security).
; Use "~all" (softfail) during migration/testing if your mail flow is uncertain.
@   IN TXT  "v=spf1 mx -all"

; DMARC policy — what receiving servers should do with SPF/DKIM failures.
; p=reject: reject messages that fail authentication.
; rua: send aggregate reports here.
_dmarc  IN TXT  "v=DMARC1; p=reject; rua=mailto:dmarc-reports@example.com"

; DKIM public key. The selector name ("default" here) must match what your
; mail server is configured to use for signing.
default._domainkey  IN TXT  (
    "v=DKIM1; k=rsa; "
    "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC..."
)
```

---

## 9. DNSSEC Signing Basics

DNSSEC adds cryptographic signatures to zone data so resolvers can verify authenticity.
The process: generate keys, sign the zone, publish DS records at the parent, maintain
signatures (re-sign before they expire).

**Step 1: Generate a Key Signing Key (KSK) and Zone Signing Key (ZSK).**

```bash
cd /etc/bind/keys   # or wherever you store keys

# KSK — signs the DNSKEY RRset. Longer-lived, kept offline when possible.
dnssec-keygen -a ECDSAP256SHA256 -f KSK -n ZONE example.com

# ZSK — signs all other RRsets in the zone. Rotated more frequently.
dnssec-keygen -a ECDSAP256SHA256 -n ZONE example.com
```

This creates files like:
- `Kexample.com.+013+12345.key` (public key — include in zone file)
- `Kexample.com.+013+12345.private` (private key — keep secure)

**Step 2: Include the key files in the zone file.**

```
; At the end of /etc/bind/db.example.com:
$INCLUDE /etc/bind/keys/Kexample.com.+013+12345.key
$INCLUDE /etc/bind/keys/Kexample.com.+013+67890.key
```

**Step 3: Sign the zone.**

```bash
dnssec-signzone \
    -A \                          # Sign all RRs, including glue
    -3 $(head -c 6 /dev/urandom | base64 | tr -d '/+=' | head -c 8) \  # NSEC3 salt
    -N INCREMENT \                # Auto-increment serial
    -o example.com \              # Zone origin
    -t \                          # Print stats when done
    /etc/bind/db.example.com      # Zone file to sign
```

This produces `db.example.com.signed`. Update the zone definition to use the signed file:

```
zone "example.com" {
    type primary;
    file "/etc/bind/db.example.com.signed";
    // ...
};
```

**Step 4: Publish DS record at the parent zone/registrar.**

```bash
dnssec-dsfromkey /etc/bind/keys/Kexample.com.+013+12345.key
```

Submit the DS record output to your domain registrar. The chain of trust is only
complete once the DS record is in the parent zone.

**Step 5: Verify DNSSEC is working.**

```bash
dig @localhost example.com A +dnssec          # Should include RRSIG record
dig @8.8.8.8 example.com A +dnssec            # Test from an external DNSSEC validator
```

**Automated DNSSEC with dnssec-policy (BIND 9.16+)**: Replaces manual key management.

```
zone "example.com" {
    type primary;
    file "/etc/bind/db.example.com";
    dnssec-policy default;    // Use built-in key rotation policy
    inline-signing yes;       // Sign on-the-fly; edit the unsigned zone file normally
};
```

---

## 10. Forwarder Configuration

Use forwarders to send all recursive queries to upstream DNS servers instead of
resolving from root. Common for internal networks behind a corporate firewall.

**Forward everything to upstream resolvers:**

```
options {
    recursion yes;
    allow-recursion { internal; };

    forwarders {
        8.8.8.8;          // Google Public DNS
        8.8.4.4;
        1.1.1.1;          // Cloudflare
        1.0.0.1;
    };

    // "first": try forwarders, fall back to full recursion if they all fail.
    // "only": return SERVFAIL if all forwarders fail; never do full recursion.
    forward first;
};
```

**Selective forwarding — different upstreams for different zones:**

Useful when you have an internal corporate DNS that knows about internal hostnames,
while everything else goes to the public internet.

```
// Forward internal corporate zones to the corporate DNS.
zone "corp.internal" {
    type forward;
    forwarders { 10.0.0.1; 10.0.0.2; };
    forward only;
};

zone "10.in-addr.arpa" {
    type forward;
    forwarders { 10.0.0.1; 10.0.0.2; };
    forward only;
};

// All other queries use the global forwarders in options{} or resolve from root.
```
