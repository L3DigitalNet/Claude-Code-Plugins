# ufw Common Rules

## Initial Setup (Safe Sequence)

Always allow SSH before enabling ufw on a remote system.

```bash
sudo ufw allow ssh                    # Allow SSH BEFORE enabling
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

## Web Services

```bash
# HTTP and HTTPS individually
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Nginx app profile (covers 80 + 443)
sudo ufw allow 'Nginx Full'
sudo ufw allow 'Nginx HTTP'           # HTTP only
sudo ufw allow 'Nginx HTTPS'          # HTTPS only

# Apache app profile (covers 80 + 443)
sudo ufw allow 'Apache Full'
sudo ufw allow 'Apache'               # HTTP only
sudo ufw allow 'Apache Secure'        # HTTPS only

# Custom port
sudo ufw allow 8080/tcp
sudo ufw allow 3000/tcp
```

## Database Rules (Restrict to Specific IPs)

Never open database ports to the world. Always restrict to a specific IP or subnet.

```bash
# PostgreSQL — allow only from app server
sudo ufw allow from 192.168.1.10 to any port 5432 proto tcp

# MySQL/MariaDB — allow only from subnet
sudo ufw allow from 10.0.0.0/8 to any port 3306 proto tcp

# Redis — allow only from localhost (default) or specific IP
sudo ufw allow from 127.0.0.1 to any port 6379 proto tcp
sudo ufw allow from 192.168.1.10 to any port 6379 proto tcp

# MongoDB
sudo ufw allow from 192.168.1.10 to any port 27017 proto tcp
```

## Common Services

```bash
# SSH (default port 22)
sudo ufw allow ssh
sudo ufw allow 22/tcp                 # Equivalent

# SSH on custom port
sudo ufw allow 2222/tcp

# FTP (active mode)
sudo ufw allow 21/tcp

# FTP (passive mode) — requires a port range configured in the FTP server
sudo ufw allow 49152:65535/tcp

# SMTP
sudo ufw allow 25/tcp                 # SMTP (often blocked by ISPs on VPSes)
sudo ufw allow 587/tcp                # SMTP submission (TLS)
sudo ufw allow 465/tcp                # SMTP over SSL (legacy)

# IMAP
sudo ufw allow 143/tcp                # IMAP
sudo ufw allow 993/tcp                # IMAPS (TLS)

# DNS (only needed if this host is a DNS server)
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
```

## Internal Network Access

```bash
# Allow all traffic from a subnet
sudo ufw allow from 192.168.1.0/24

# Allow a specific IP (all ports)
sudo ufw allow from 10.0.0.5

# Allow a specific IP to a specific port
sudo ufw allow from 10.0.0.5 to any port 8080 proto tcp

# Allow a subnet to a specific port
sudo ufw allow from 192.168.1.0/24 to any port 5432 proto tcp
```

## Rate Limiting

Protects against brute-force attacks by blocking IPs that attempt more than 6 connections within 30 seconds.

```bash
# Rate-limit SSH (replaces a plain allow ssh rule)
sudo ufw limit ssh
sudo ufw limit 22/tcp                 # Equivalent

# Rate-limit a custom port
sudo ufw limit 2222/tcp
```

## Deleting Rules

```bash
# Delete by rule content (must match exactly)
sudo ufw delete allow 80/tcp
sudo ufw delete allow ssh
sudo ufw delete allow from 192.168.1.10 to any port 5432 proto tcp

# Delete by rule number (safer for complex rules)
sudo ufw status numbered              # List rules with numbers
sudo ufw delete 3                     # Delete rule #3

# Reset all rules (clears everything — re-add SSH immediately after)
sudo ufw reset
sudo ufw allow ssh
sudo ufw enable
```

## Logging

```bash
# Enable logging (LOW level by default)
sudo ufw logging on

# Set log level
sudo ufw logging low                  # Blocked packets only
sudo ufw logging medium               # Blocked + allowed packets
sudo ufw logging high                 # All packets (high volume)
sudo ufw logging full                 # Maximum verbosity

# Disable logging
sudo ufw logging off

# View logs
sudo journalctl -k | grep UFW         # Kernel log, UFW entries
sudo tail -f /var/log/ufw.log         # UFW-specific log file (if rsyslog configured)
```

Example log entry:
```
Mar 01 14:22:05 hostname kernel: [UFW BLOCK] IN=eth0 OUT= MAC=... SRC=1.2.3.4 DST=10.0.0.1 LEN=44 TOS=0x00 PREC=0x00 TTL=50 ID=0 DF PROTO=TCP SPT=54321 DPT=22 WINDOW=65535 RES=0x00 SYN URGP=0
```
Key fields: `IN` (interface), `SRC` (source IP), `DST` (destination IP), `DPT` (destination port), `PROTO`.

## Docker Interaction

Docker publishes ports by inserting raw iptables rules into the `DOCKER` chain, which is consulted before ufw's INPUT chain. This means a port published with `-p 80:80` is reachable from the internet even if `sudo ufw deny 80/tcp` is active.

**Workaround 1 — Bind to localhost, proxy via nginx (recommended):**
```bash
# Run container bound to localhost only
docker run -p 127.0.0.1:8080:8080 myapp

# Expose externally through nginx with ufw controlling port 80/443
sudo ufw allow 'Nginx Full'
```

**Workaround 2 — Use the DOCKER-USER chain:**
Docker evaluates the `DOCKER-USER` iptables chain before routing to containers. Rules added there are not overwritten by Docker restarts.
```bash
# Block a source IP from reaching all Docker containers
sudo iptables -I DOCKER-USER -s 1.2.3.4 -j DROP

# Allow only a specific subnet to reach Docker containers
sudo iptables -I DOCKER-USER -i eth0 ! -s 192.168.1.0/24 -j DROP
```
Note: these rules are not persisted by ufw — use `iptables-persistent` or a startup script.

**Workaround 3 — Disable Docker iptables management (complex, breaks inter-container networking by default):**
Set `"iptables": false` in `/etc/docker/daemon.json` and manage all rules manually. Only appropriate if you fully control the iptables ruleset.
