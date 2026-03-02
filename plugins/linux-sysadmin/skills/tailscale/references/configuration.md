# Tailscale Configuration Reference

## `tailscale up` Flags

`tailscale up` brings the interface up and applies configuration. Flags not specified are reset to their defaults — use `tailscale set` to change individual settings without resetting others.

| Flag | Default | Description |
|------|---------|-------------|
| `--authkey=<key>` | — | Authenticate non-interactively using a pre-auth key from the admin console. Required for headless/automated setups. Keys can be reusable or one-time, ephemeral or persistent. |
| `--hostname=<name>` | system hostname | Override the device name shown in the admin console and used for MagicDNS. |
| `--advertise-routes=<cidrs>` | — | Comma-separated list of subnet CIDRs this device will route for the tailnet (e.g., `192.168.1.0/24,10.0.0.0/8`). Requires admin console approval and `net.ipv4.ip_forward=1`. |
| `--accept-routes` | `false` | Accept subnet routes advertised by other devices. Without this, clients ignore advertised subnets. |
| `--exit-node=<peer>` | — | Route all non-Tailscale traffic through this peer. Peer must have `--advertise-exit-node` set and be approved in the admin console. |
| `--exit-node-allow-lan-access` | `false` | When using an exit node, still allow direct access to the local LAN (bypasses the exit node for local subnet traffic). |
| `--advertise-exit-node` | `false` | Allow this device to be used as an exit node by others. Must also be approved in the admin console. |
| `--accept-dns` | `true` | Apply MagicDNS and admin console DNS settings to the local resolver. Set to `false` to disable Tailscale DNS management entirely. |
| `--shields-up` | `false` | Block all incoming connections from the tailnet to this device. Outgoing connections still work. Useful for untrusted networks. |
| `--ssh` | `false` | Enable Tailscale SSH: allows other tailnet devices to SSH to this device using Tailscale identity, governed by ACLs. Does not require `sshd` to be running. |
| `--operator=<user>` | — | Allow this local Linux user to run `tailscale` commands without `sudo`. |
| `--reset` | `false` | Reset all settings to defaults before applying the specified flags. |
| `--force-reauth` | `false` | Force re-authentication even if the device is already authenticated. Use to recover from expired sessions. |
| `--timeout=<duration>` | `0` | Timeout for the `up` command (e.g., `30s`). Default waits indefinitely. |

---

## Daemon Flags (`/etc/default/tailscaled`)

The `tailscaled` daemon reads flags from this file at startup. Change the `FLAGS` variable; restart `tailscaled` to apply.

```bash
# /etc/default/tailscaled

# Daemon startup flags — passed directly to tailscaled
FLAGS=""

# Common flags:
#
# --port=<n>
#   UDP port for the Tailscale data plane (default: 41641).
#   Change if 41641 is blocked and you cannot open the firewall.
#
# --tun=<name>
#   Name of the TUN interface (default: tailscale0).
#   Change if another service is using that name.
#
# --statedir=<path>
#   Directory for persistent state (default: /var/lib/tailscale/).
#   Must be writable by tailscaled.
#
# --socket=<path>
#   Unix socket path for the tailscale CLI to communicate with the daemon
#   (default: /var/run/tailscale/tailscaled.sock).
#
# Example: run on a non-default port, custom state dir
# FLAGS="--port=41642 --statedir=/opt/tailscale/state"
```

After editing `/etc/default/tailscaled`: `sudo systemctl restart tailscaled`

---

## ACL Basics

Tailscale ACLs are written in HuJSON (JSON with comments) and managed in the admin console at `login.tailscale.com`. There is no local ACL file — changes take effect immediately across the tailnet when saved.

### ACL structure

```jsonc
{
  // tagOwners: who is allowed to assign a tag to a device.
  // Tags group devices for ACL purposes instead of using individual IPs.
  "tagOwners": {
    "tag:server": ["autogroup:admin"],
    "tag:dev":    ["autogroup:admin"]
  },

  // hosts: named aliases for IPs or subnets (optional, improves readability).
  "hosts": {
    "prod-db":   "100.64.0.10",
    "dev-subnet": "192.168.2.0/24"
  },

  // acls: list of rules evaluated top-to-bottom; first match wins.
  // action: "accept" (allow) — there is no explicit "deny"; everything not
  // matched by an accept rule is implicitly denied.
  "acls": [
    // Allow all devices to reach the internet via exit nodes
    {
      "action": "accept",
      "src":    ["autogroup:member"],
      "dst":    ["autogroup:internet:*"]
    },
    // Allow dev machines to reach only dev subnet, not production
    {
      "action": "accept",
      "src":    ["tag:dev"],
      "dst":    ["dev-subnet:*"]
    },
    // Allow admins full access to production servers
    {
      "action": "accept",
      "src":    ["autogroup:admin"],
      "dst":    ["tag:server:*"]
    },
    // Allow specific port only (e.g., HTTPS to production DB)
    {
      "action": "accept",
      "src":    ["tag:server"],
      "dst":    ["prod-db:443"]
    }
  ],

  // ssh: Tailscale SSH access rules (only applies when --ssh is enabled on devices)
  "ssh": [
    {
      "action": "accept",
      "src":    ["autogroup:admin"],
      "dst":    ["autogroup:self"],
      "users":  ["autogroup:nonroot", "root"]
    }
  ]
}
```

The `autogroup:admin`, `autogroup:member`, `autogroup:self`, and `autogroup:internet` groups are built-in Tailscale identities. Tags must be assigned to devices in the admin console or via auth keys.

---

## Key Setup Patterns

### 1. Basic device auth (interactive)

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start the daemon (usually done automatically by the installer)
sudo systemctl enable --now tailscaled

# Authenticate — opens a browser URL
sudo tailscale up
# Follow the printed URL to complete auth in the admin console
```

### 2. Headless auth with auth key (servers and automation)

Generate a reusable or one-time auth key in the admin console under Settings > Keys.

```bash
sudo tailscale up \
  --authkey=tskey-auth-<key> \
  --hostname=my-server \
  --ssh          # optional: enable Tailscale SSH
```

For ephemeral devices (e.g., CI runners), use an ephemeral auth key — the device is automatically removed from the tailnet when it disconnects.

### 3. Subnet router setup

```bash
# Step 1: Enable IP forwarding on the routing device
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Step 2: Advertise the subnet
sudo tailscale up --advertise-routes=192.168.1.0/24

# Step 3: In the admin console, navigate to the device and approve the advertised route.

# Step 4: On each client that needs access to the subnet, accept routes:
sudo tailscale up --accept-routes

# Verify: from a client, ping a host on the advertised subnet
ping 192.168.1.100
```

### 4. Exit node setup

```bash
# On the device that will be the exit node:

# Step 1: Enable IP forwarding (same as subnet router above)
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Step 2: Advertise as exit node
sudo tailscale up --advertise-exit-node

# Step 3: In the admin console, find the device and enable "Use as exit node".

# Step 4: On the client, select the exit node:
tailscale set --exit-node=<device-name>

# Verify: all traffic now routes through the exit node
curl https://ifconfig.me   # should return the exit node's public IP

# To stop using the exit node:
tailscale set --exit-node=
```
