# firewalld Common Rules

## Initial Setup

Check state and understand the current configuration before making changes.

```bash
sudo firewall-cmd --state                      # running or not running
sudo firewall-cmd --get-default-zone           # which zone is the default
sudo firewall-cmd --get-active-zones           # zones with assigned interfaces
sudo firewall-cmd --zone=public --list-all     # full view of the public zone
sudo firewall-cmd --get-services               # all recognized service names
```

## Allow/Deny Services

The standard pattern: add permanently, then reload to activate.

```bash
# Allow a service permanently and activate immediately
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --reload

# Remove a service
sudo firewall-cmd --zone=public --remove-service=http --permanent
sudo firewall-cmd --reload

# Allow a port permanently
sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent
sudo firewall-cmd --reload

# Remove a port
sudo firewall-cmd --zone=public --remove-port=8080/tcp --permanent
sudo firewall-cmd --reload

# Test a rule at runtime first (lost on reload), then make permanent if it works
sudo firewall-cmd --zone=public --add-service=http
# verify traffic works, then:
sudo firewall-cmd --zone=public --add-service=http --permanent
```

## Web Services

```bash
# HTTP and HTTPS
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --zone=public --add-service=https --permanent
sudo firewall-cmd --reload

# Nginx Full equivalent (HTTP + HTTPS on standard ports)
sudo firewall-cmd --zone=public --add-service=http --permanent
sudo firewall-cmd --zone=public --add-service=https --permanent
sudo firewall-cmd --reload

# Custom application port
sudo firewall-cmd --zone=public --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
```

## Database Rules (Restrict to Specific IPs)

Never open database ports to the world. Rich rules allow source IP restriction.

```bash
# PostgreSQL — allow only from a specific app server
sudo firewall-cmd --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="192.168.1.10/32"
  port port="5432" protocol="tcp"
  accept' --permanent

# MySQL/MariaDB — allow only from a subnet
sudo firewall-cmd --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="10.0.0.0/8"
  port port="3306" protocol="tcp"
  accept' --permanent

sudo firewall-cmd --reload
```

## Custom SSH Port

```bash
# Allow SSH on a custom port
sudo firewall-cmd --zone=public --add-port=2222/tcp --permanent

# Remove the default SSH service (port 22) after confirming custom port works
sudo firewall-cmd --zone=public --remove-service=ssh --permanent

sudo firewall-cmd --reload
```

Do not remove port 22 until the new port is confirmed working in a separate session.

## Rich Rules

Rich rules handle logic that `--add-service` and `--add-port` cannot express.

```bash
# Allow all traffic from a specific source IP
sudo firewall-cmd --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="203.0.113.5/32"
  accept' --permanent

# Block all traffic from a source IP
sudo firewall-cmd --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="198.51.100.0/24"
  drop' --permanent

# Allow a source IP to reach a specific port
sudo firewall-cmd --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="10.0.0.5/32"
  port port="5432" protocol="tcp"
  accept' --permanent

# Log and drop — log matching packets before dropping (useful for auditing)
sudo firewall-cmd --zone=public --add-rich-rule='
  rule family="ipv4"
  source address="198.51.100.0/24"
  log prefix="BLOCKED " level="warning"
  drop' --permanent

sudo firewall-cmd --reload

# List rich rules for a zone
sudo firewall-cmd --zone=public --list-rich-rules

# Remove a rich rule (paste the exact rule string)
sudo firewall-cmd --zone=public --remove-rich-rule='
  rule family="ipv4"
  source address="203.0.113.5/32"
  accept' --permanent
sudo firewall-cmd --reload
```

## Port Forwarding

```bash
# Forward incoming port 80 to local port 8080
sudo firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080 --permanent
sudo firewall-cmd --reload

# Forward to a different host (requires masquerade enabled)
sudo firewall-cmd --zone=public --add-masquerade --permanent
sudo firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toport=8080:toaddr=192.168.1.10 --permanent
sudo firewall-cmd --reload

# Remove port forwarding
sudo firewall-cmd --zone=public --remove-forward-port=port=80:proto=tcp:toport=8080 --permanent
sudo firewall-cmd --reload
```

## Interface and Zone Assignment

```bash
# Show which interfaces are in which zones
sudo firewall-cmd --get-active-zones

# Assign an interface to a zone (runtime)
sudo firewall-cmd --zone=internal --change-interface=eth1

# Assign an interface to a zone (permanent)
sudo firewall-cmd --zone=internal --change-interface=eth1 --permanent
sudo firewall-cmd --reload

# Query which zone an interface is in
sudo firewall-cmd --get-zone-of-interface=eth0
```

## Source-Based Zone Assignment

Assign all traffic from an IP range to a zone, regardless of interface.

```bash
# Treat all traffic from the 10.0.0.0/8 range as "trusted"
sudo firewall-cmd --zone=trusted --add-source=10.0.0.0/8 --permanent
sudo firewall-cmd --reload

# Add a single IP to the internal zone
sudo firewall-cmd --zone=internal --add-source=192.168.1.50/32 --permanent
sudo firewall-cmd --reload

# Remove a source from a zone
sudo firewall-cmd --zone=trusted --remove-source=10.0.0.0/8 --permanent
sudo firewall-cmd --reload
```

## Masquerading (NAT)

Required when this host routes traffic on behalf of other machines (gateway/VPN scenarios).

```bash
# Enable masquerade on the external zone
sudo firewall-cmd --zone=external --add-masquerade --permanent
sudo firewall-cmd --reload

# Verify masquerade is enabled
sudo firewall-cmd --zone=external --query-masquerade

# Disable masquerade
sudo firewall-cmd --zone=external --remove-masquerade --permanent
sudo firewall-cmd --reload
```

## Panic Mode

Immediately blocks all traffic (incoming and outgoing). Use when a host is actively under attack and you need to cut all connections while you investigate.

```bash
# Enable panic mode — blocks ALL traffic immediately (including your SSH session)
sudo firewall-cmd --panic-on

# Disable panic mode (requires console access if SSH was dropped)
sudo firewall-cmd --panic-off

# Check panic mode status
sudo firewall-cmd --query-panic
```

Panic mode does not require a reload and takes effect instantly. It is runtime-only and clears on reload or daemon restart.

## Docker Zone Rules

Docker writes nftables rules that bypass firewalld zones. Use the `DOCKER-USER` chain via firewalld's direct interface to add rules that Docker evaluates before routing to containers.

```bash
# Block a specific source IP from reaching all Docker containers
sudo firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 1 \
  -s 198.51.100.5 -j DROP --permanent

# Allow only a specific subnet to reach containers; block everything else
sudo firewall-cmd --direct --add-rule ipv4 filter DOCKER-USER 1 \
  ! -s 192.168.1.0/24 -i eth0 -j DROP --permanent

sudo firewall-cmd --reload

# List direct rules
sudo firewall-cmd --direct --get-all-rules
```

Alternatively, bind containers to localhost and proxy traffic through nginx — firewalld then controls port 80/443 normally without Docker interference.

## Persist Runtime Changes

If you've built up runtime rules interactively and want to save them all at once:

```bash
# Promote entire current runtime config to permanent
sudo firewall-cmd --runtime-to-permanent
```

## Inspect the Underlying nftables Ruleset

```bash
# View the full nftables ruleset firewalld has generated
sudo nft list ruleset

# View a specific nftables table
sudo nft list table inet firewalld

# Trace a packet through the ruleset (advanced debugging)
sudo nft monitor trace
```
