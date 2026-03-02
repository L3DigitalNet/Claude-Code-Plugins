# Pi-hole Configuration Reference

## setupVars.conf

Location: `/etc/pihole/setupVars.conf`

Written by the installer and updated by the web UI and `pihole -r`. Hand-editing is supported but changes to some fields require `pihole restartdns` or a full service restart to take effect.

```ini
# Admin web interface password hash (SHA256 double-hashed). Set via:
# pihole -a -p <newpassword>   or leave blank to disable auth
WEBPASSWORD=<hash>

# Network interface Pi-hole listens on
PIHOLE_INTERFACE=eth0

# Pi-hole's own IPv4 address in CIDR notation (set by installer)
IPV4_ADDRESS=192.168.1.10/24

# Pi-hole's own IPv6 address (leave blank to disable IPv6)
IPV6_ADDRESS=

# Log DNS queries to /var/log/pihole/pihole.log and gravity.db
QUERY_LOGGING=true

# Install and manage the lighttpd web server
INSTALL_WEB_SERVER=true

# Install the web admin interface (requires INSTALL_WEB_SERVER=true)
INSTALL_WEB_INTERFACE=true

# Whether lighttpd is enabled via systemd
LIGHTTPD_ENABLED=true

# DNS cache size in entries. 0 disables caching (not recommended).
# Default: 10000. Higher values use more RAM but reduce upstream queries.
CACHE_SIZE=10000

# Reject queries for non-fully-qualified domain names (no dots).
# Prevents local hostnames from leaking to upstream resolvers.
DNS_FQDN_REQUIRED=true

# Never forward reverse lookups for private IP ranges to upstream.
# Prevents RFC1918 addresses from leaking to upstream resolvers.
DNS_BOGUS_PRIV=true

# Which interfaces FTL listens on for DNS queries:
#   local    - only loopback
#   single   - PIHOLE_INTERFACE only
#   bind     - bind only to PIHOLE_INTERFACE
#   all      - all interfaces (needed for Docker host networking)
DNSMASQ_LISTENING=local

# Upstream DNS servers (up to 4: PIHOLE_DNS_1 through PIHOLE_DNS_4)
# Use IP#port notation for non-standard ports (e.g., unbound on 5335)
PIHOLE_DNS_1=1.1.1.1
PIHOLE_DNS_2=1.0.0.1

# Enable DNSSEC validation. Requires upstream resolver support.
DNSSEC=false

# Reverse server (conditional forwarding) — send reverse lookups for
# the local subnet to the router so Pi-hole can resolve hostnames
REV_SERVER=true
REV_SERVER_CIDR=192.168.1.0/24
REV_SERVER_TARGET=192.168.1.1
REV_SERVER_DOMAIN=local

# DHCP server (disabled by default — disable router DHCP first)
DHCP_ACTIVE=false
DHCP_START=192.168.1.201
DHCP_END=192.168.1.251
DHCP_ROUTER=192.168.1.1
DHCP_LEASETIME=24
DHCP_IPv6=false
DHCP_rapid_commit=false

# Master on/off switch for DNS blocking (separate from service state)
BLOCKING_ENABLED=true

# Web UI layout: boxed or traditional full-width
WEBUIBOXEDLAYOUT=boxed
```

---

## pihole-FTL.conf

Location: `/etc/pihole/pihole-FTL.conf`

FTL (Faster Than Light) is the DNS resolver and statistics engine. These settings tune its behavior beyond what the web UI exposes. Restart with `pihole restartdns` after changes.

```ini
# Which sockets FTL creates for the API:
#   localonly  - only 127.0.0.1 (default, recommended)
#   all        - all interfaces (needed for remote API access)
SOCKET_LISTENING=localonly

# TCP port for the FTL API socket (default 4711)
FTLPORT=4711

# Resolve client IP addresses to hostnames in the query log
RESOLVE_IPV4=true
RESOLVE_IPV6=true

# Import queries from the database on startup (for statistics continuity)
DBIMPORT=true

# Retain query data in gravity.db for this many days (0 = keep forever)
MAXDBDAYS=365

# How often (minutes) to write queries from memory to the database
DBINTERVAL=1.0

# Path to the query database
DBFILE=/etc/pihole/pihole-FTL.db

# Maximum age (hours) of queries shown in the web UI query log
MAXLOGAGE=24.0

# Privacy level — controls what is stored and shown:
#   0 = show everything (default)
#   1 = hide domains
#   2 = hide domains and clients
#   3 = anonymous mode (no query logging at all)
PRIVACYLEVEL=0

# Exclude queries from and to localhost (127.0.0.1/::1) from logs
IGNORE_LOCALHOST=no

# How blocked queries are answered:
#   NULL      - return 0.0.0.0 / :: (default, RFC-compliant)
#   IP-NODATA - return Pi-hole's IP with NODATA (for HTTPS blocking)
#   NXDOMAIN  - return NXDOMAIN (non-existent domain)
#   NODATA    - return NODATA
BLOCKINGMODE=NULL

# Follow CNAME chains to detect if the final target is blocked.
# Prevents CNAME cloaking ad-tech bypass.
CNAME_DEEP_INSPECT=true

# Block Encrypted SNI (ESNI) queries — used to bypass SNI-based filtering.
# Blocks _esni.* TXT queries.
BLOCK_ESNI=true

# Only analyze A (IPv4) and AAAA (IPv6) queries for blocking; pass through
# all other query types unblocked (MX, TXT, SRV, etc.)
ANALYZE_ONLY_A_AND_AAAA=false

# Include DNSSEC queries in the query log
SHOW_DNSSEC=false

# Block Mozilla's canary domain (use-application-dns.net) to prevent
# Firefox from bypassing Pi-hole by enabling DoH automatically
MOZILLA_CANARY=true

# Resolve client names from /etc/hosts and the network database
NAMES_FROM_NETDB=true

# Enable regex blacklist/whitelist matching (both default true)
REGEX_BLACKLIST_ENABLED=true
REGEX_WHITELIST_ENABLED=true

# Analyze AAAA (IPv6) queries for blocking (in addition to A queries)
AAAA_QUERY_ANALYSIS=true
```

---

## Upstream DNS Presets

Common values for `PIHOLE_DNS_1` / `PIHOLE_DNS_2`:

| Provider | Primary | Secondary |
|----------|---------|-----------|
| Cloudflare | `1.1.1.1` | `1.0.0.1` |
| Cloudflare (malware blocking) | `1.1.1.2` | `1.0.0.2` |
| Google | `8.8.8.8` | `8.8.4.4` |
| Quad9 (blocking) | `9.9.9.9` | `149.112.112.112` |
| OpenDNS | `208.67.222.222` | `208.67.220.220` |
| unbound (local recursive) | `127.0.0.1#5335` | — |

---

## systemd-resolved Conflict Fix

Ubuntu 18.04+ and Debian 12+ run `systemd-resolved` with a stub DNS listener on `127.0.0.53:53`. This prevents Pi-hole from binding port 53.

```bash
# 1. Disable the stub listener
sudo sed -i 's/^#DNSStubListener=yes/DNSStubListener=no/' /etc/systemd/resolved.conf
# If the line doesn't exist, add it:
echo 'DNSStubListener=no' | sudo tee -a /etc/systemd/resolved.conf

# 2. Restart resolved
sudo systemctl restart systemd-resolved

# 3. Point /etc/resolv.conf at Pi-hole (not at resolved's stub)
# Remove the symlink and write a static file
sudo rm /etc/resolv.conf
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf

# 4. Verify port 53 is now free
ss -ulnp | grep :53
# Should show nothing, or only pihole-FTL after it starts

# 5. Start/restart Pi-hole
sudo systemctl restart pihole-FTL
pihole status
```

Note: step 3 is not persistent through all NetworkManager configurations. If `/etc/resolv.conf` keeps being overwritten, configure NetworkManager to stop managing it or set `dns=none` in `/etc/NetworkManager/NetworkManager.conf`.
