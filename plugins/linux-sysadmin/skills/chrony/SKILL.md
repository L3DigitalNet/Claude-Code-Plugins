---
name: chrony
description: >
  chrony NTP time synchronization administration: daemon status, source tracking,
  clock offset diagnostics, makestep, RTC sync, and timedatectl integration.
  Triggers on: chrony, NTP, time sync, chronyd, chronyc, clock sync,
  network time, timedatectl NTP, chrony.conf, time drift, NTP sources.
globs:
  - "**/chrony.conf"
  - "**/chrony/chrony.conf"
---

## Identity
- **Daemon**: `chronyd`
- **Client tool**: `chronyc`
- **Unit**: `chronyd.service`
- **Config**: `/etc/chrony.conf` (RHEL/Fedora) or `/etc/chrony/chrony.conf` (Debian/Ubuntu)
- **Logs**: `journalctl -u chronyd`
- **Distro install**: `apt install chrony` / `dnf install chrony`

## Key Operations

| Operation | Command |
|-----------|---------|
| Daemon status | `systemctl status chronyd` |
| Tracking info (offset, frequency, stratum) | `chronyc tracking` |
| List NTP sources with detail | `chronyc sources -v` |
| Source statistics (drift, jitter) | `chronyc sourcestats` |
| Check if clock is synchronized | `chronyc tracking \| grep "Leap status"` — value should be `Normal` |
| Force immediate clock step (large offset) | `chronyc makestep` |
| Mark NTP sources online (after network up) | `chronyc online` |
| Mark NTP sources offline (before network down) | `chronyc offline` |
| Sync hardware clock (RTC) from system time | `hwclock --systohc` |
| timedatectl sync status | `timedatectl show --property=NTPSynchronized` |
| timedatectl enable NTP | `timedatectl set-ntp true` |
| Activity info (online/offline sources) | `chronyc activity` |

## Expected State
- `chronyc tracking` shows `Leap status: Normal` and `System time` offset below 100ms for general use
- Stratum should be 2–4 for servers using public pools (stratum 1 is a direct GPS/atomic source)
- `chronyc sources -v` shows at least one source with `*` (currently selected) in the S column
- `timedatectl` shows `NTPSynchronized=yes` and `NTP service: active`

## Health Checks
1. `systemctl is-active chronyd` → `active`
2. `chronyc tracking` → `Leap status: Normal` and `System time` offset in milliseconds, not seconds
3. `chronyc sources` → at least one row with `*` (synchronized) in the first column
4. `timedatectl | grep -E 'synchronized|NTP service'` → both lines show `yes` / `active`

## Common Failures

| Symptom | Likely cause | Check/Fix |
|---------|-------------|-----------|
| `No NTP sources reachable` | Firewall blocking outbound UDP 123 | `firewall-cmd --add-service=ntp` or `ufw allow ntp`; verify with `nc -uzv pool.ntp.org 123` |
| All sources show `?` in `chronyc sources` | DNS resolution failing or network down | `ping pool.ntp.org`; check `/etc/resolv.conf` and network interface |
| Large offset, clock not converging | chrony is slewing (slow) but offset is huge | Run `chronyc makestep` to force an immediate step; or add `makestep 1 -1` to config |
| `chronyd` conflicts with `systemd-timesyncd` | Both services running and competing | Disable one: `systemctl disable --now systemd-timesyncd` (chrony is more capable) |
| Time drifts on VMs despite chrony running | Hypervisor time sync overriding chrony | Disable VMware Tools / VirtualBox Additions time sync; see Pain Points |
| GPS/PPS source not selected | PPS signal not stable or SHM not configured | Check `chronyc sources -v` for `#` (local) rows; verify `/etc/chrony.conf` `refclock` directive |
| `Clock not synchronized` after reboot | chrony hasn't reached initial sync yet | Wait 30–60s; or add `initstepslew 10 <server>` to config for faster startup convergence |

## Pain Points
- **VM hypervisor time sync conflict**: VMware Tools and VirtualBox Guest Additions have their own time sync that fights chrony. Disable them: VMware — `vmware-toolsd --cmd "disable timesync"`; VirtualBox — `VBoxService --disable-timesync`. AWS/KVM instances generally use chrony without conflict.
- **NTP port 123 UDP outbound required**: chrony needs outbound 123/UDP to reach pool servers. Firewalls that only open TCP or block all outbound UDP will silently prevent sync without an obvious error.
- **makestep vs slew**: By default chrony slews the clock gradually (never jumps) once initial sync is complete. If a large offset accumulates (reboot, suspended VM), `chronyc makestep` forces an immediate correction. The config `makestep 1.0 3` allows automatic stepping for the first 3 clock updates only.
- **chrony replaced ntpd**: chrony's config format is different from the legacy `ntp.conf` (ntpd). Common migration mistake: copying `server` lines directly — the `iburst` option works the same but `burst`, `restrict`, and `fudge` directives do not exist in chrony.
- **systemd-timesyncd is simpler but less capable**: It handles basic NTP synchronization but has no `chronyc`-equivalent query tool, no hardware clock sync, no NTP server mode, and no support for GPS/PPS sources. Prefer chrony on servers.

## References
See `references/` for:
- `chrony.conf.annotated` — full config with every directive explained
- `docs.md` — official documentation links
