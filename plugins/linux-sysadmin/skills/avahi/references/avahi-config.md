# Avahi Configuration Reference

## avahi-daemon.conf

Full annotated configuration. Defaults shown; uncomment and modify as needed.

```ini
[server]
# Hostname to advertise. Defaults to the system hostname (from gethostname()).
# Append ".local" to resolve it via mDNS on the local segment.
#host-name=myhost

# mDNS domain. Almost always leave as "local".
#domain-name=local

# Additional browse domains — comma-separated. Avahi will query these domains
# as if they were the local mDNS segment (useful for wide-area DNS-SD).
#browse-domains=0pointer.de, zeroconf.org

# Advertise on IPv4 and/or IPv6.
use-ipv4=yes
use-ipv6=yes

# Whitelist specific interfaces (comma-separated). Default: all non-loopback.
# Use this to restrict avahi to a single VLAN or bridge interface.
#allow-interfaces=eth0,wlan0

# Blacklist specific interfaces (comma-separated).
# Takes precedence over allow-interfaces if both are set.
#deny-interfaces=docker0,virbr0

# Check for address conflicts on startup (RFC 3927). Recommended: yes.
check-response-ttl=no

# Use IFF_RUNNING flag to detect carrier state before publishing.
use-iff-running=no

# Enable D-Bus interface for runtime control (avahi-publish, avahi-browse).
# Requires avahi-daemon compiled with D-Bus support.
enable-dbus=yes

# Rate-limit outgoing mDNS packets to prevent flooding. Value in packets/sec.
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
# Enable wide-area DNS-SD (RFC 6763 §11). Disabled by default.
# Requires browse-domains to be set.
enable-wide-area=yes

[publish]
# Publish this host's address records. Disable to suppress all A/AAAA records.
publish-addresses=yes

# Publish HINFO records (OS + CPU type). Set to no to reduce info leakage.
publish-hinfo=yes

# Publish Workstation (_workstation._tcp) service. Set to no on servers.
publish-workstation=yes

# Publish a DNS-SD domain record for "local". Usually leave enabled.
publish-domain=yes

# Allow user-space processes to publish services via D-Bus.
# Required for avahi-publish-service and most applications using avahi.
disable-publishing=no

# Prevent user-space processes from publishing — overrides per-process.
#disallow-other-stacks=no

# Set the TTL for published records (seconds). 4500 is the RFC default.
#host-name-from-machine-id=no

[reflector]
# Reflect mDNS and DNS-SD packets between all local network interfaces.
# Useful on hosts with multiple interfaces (e.g., a router or bridge).
# WARNING: creates broadcast loops if used carelessly on bridged interfaces.
enable-reflector=no

# Also reflect DNS-SD unicast queries (experimental).
reflect-ipv=no

[rlimits]
# Resource limits for the daemon process. Leave unset to use system defaults.
# Raise if avahi logs "Too many open files" under heavy service discovery load.
#rlimit-core=0
#rlimit-data=4194304
#rlimit-fsize=0
#rlimit-nofile=768
#rlimit-stack=4194304
#rlimit-nproc=3
```

---

## Service Definition XML (.service files)

Files in `/etc/avahi/services/` are read on startup and when avahi receives SIGHUP. Each file can declare multiple services. avahi-daemon is strict about XML validity — malformed files are silently skipped.

### Minimal structure

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>   <!-- %h = hostname -->
  <service>
    <type>_http._tcp</type>
    <port>80</port>
  </service>
</service-group>
```

### HTTP server with subtype and TXT record

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Web on %h</name>
  <service>
    <type>_http._tcp</type>
    <subtype>_admin._sub._http._tcp</subtype>
    <port>8080</port>
    <txt-record>path=/admin</txt-record>
    <txt-record>version=2.1</txt-record>
  </service>
</service-group>
```

### SSH service

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h SSH</name>
  <service>
    <type>_ssh._tcp</type>
    <port>22</port>
  </service>
</service-group>
```

### SMB file sharing

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">%h</name>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
  <service>
    <type>_device-info._tcp</type>
    <port>0</port>
    <txt-record>model=RackMac</txt-record>
  </service>
</service-group>
```

### IPP printer

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <name replace-wildcards="yes">Printer on %h</name>
  <service>
    <type>_ipp._tcp</type>
    <port>631</port>
    <txt-record>rp=printers/myprinter</txt-record>
    <txt-record>pdl=application/pdf,image/jpeg</txt-record>
  </service>
</service-group>
```

### Custom application service

```xml
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
  <!-- Static name — no hostname interpolation -->
  <name>My App API</name>
  <service>
    <type>_myapp._tcp</type>
    <port>9000</port>
    <txt-record>api=v2</txt-record>
    <txt-record>env=production</txt-record>
  </service>
</service-group>
```

### XML field reference

| Field | Required | Notes |
|-------|----------|-------|
| `<name>` | Yes | Human-readable label. `replace-wildcards="yes"` enables `%h` (hostname), `%d` (domain). |
| `<type>` | Yes | DNS-SD service type. Format: `_service._tcp` or `_service._udp`. |
| `<subtype>` | No | Sub-type for filtering. Format: `_subtype._sub._service._tcp`. |
| `<port>` | Yes | TCP/UDP port. Use `0` for meta-services like `_device-info._tcp`. |
| `<txt-record>` | No | Key=value pairs. Multiple allowed. Visible in `avahi-browse --resolve`. |
| `<host-name>` | No | Override the host this service points to (defaults to local host). |
| `<domain-name>` | No | Override the domain (defaults to `local`). |

---

## nsswitch.conf — mDNS entry

`/etc/nsswitch.conf` controls the hostname lookup order. For `.local` resolution to work, the `hosts:` line must contain an mdns entry placed before `dns`:

```
# Correct — mdns4_minimal with [NOTFOUND=return] short-circuits .local queries
hosts: files mdns4_minimal [NOTFOUND=return] dns

# Alternative if IPv6 .local names are needed (slower — waits for AAAA timeout)
hosts: files mdns [NOTFOUND=return] dns
```

**Variants:**
- `mdns4_minimal` — resolves `.local` names over IPv4 only; returns NOTFOUND immediately for anything that's not `.local`, so DNS lookup is never delayed. Recommended for most setups.
- `mdns4` — like `mdns4_minimal` but does not short-circuit non-`.local` queries, causing unnecessary mDNS probes for every DNS lookup.
- `mdns` — resolves over both IPv4 and IPv6. Use only if IPv6 mDNS is fully functional on all interfaces.

The `[NOTFOUND=return]` action means: if the mdns module returns NOTFOUND (the name doesn't exist in mDNS), stop here and don't proceed to the next source. This prevents `.local` lookups from leaking to the DNS server (which would time out and add 2–5 seconds of latency).

---

## avahi-browse output format

```
+ eth0 IPv4 "My Service"        _http._tcp   local
= eth0 IPv4 "My Service"        _http._tcp   local
   hostname = [myhost.local]
   address = [192.168.1.42]
   port = [8080]
   txt = ["path=/"]
```

Column meanings:
- `+` / `=`: `+` means "discovered" (unresolved); `=` means "resolved" (with hostname/address/port/txt)
- Interface: network interface the advertisement was seen on
- Protocol: `IPv4` or `IPv6`
- Service name: the `<name>` from the `.service` file or application registration
- Service type: DNS-SD type string
- Domain: almost always `local`

Useful flags for `avahi-browse`:
- `--all` — show all service types (not just a specific one)
- `--resolve` — resolve discovered services to hostname/address/port/txt
- `--terminate` — exit after initial browse (don't wait for new events)
- `--parsable` — machine-readable output (semicolon-separated fields)
- `--domain=local` — restrict to a specific domain
