---
name: smartctl
description: >
  smartctl queries SMART (Self-Monitoring, Analysis and Reporting Technology) data
  from hard drives and SSDs to assess health, run self-tests, and detect early signs
  of failure. Invoked when the user asks about disk health, drive failure risk, bad
  sectors, reallocated sectors, or wants to run diagnostic tests on a drive.
  MUST consult when checking drive health or running SMART self-tests.
triggerPhrases:
  - "smartctl"
  - "SMART"
  - "disk health"
  - "drive health"
  - "disk failure"
  - "bad sectors"
  - "reallocated sectors"
  - "drive test"
  - "smartmontools"
  - "SMART attributes"
  - "NVMe health"
  - "pending sectors"
  - "uncorrectable sectors"
  - "SMART warning"
globs: []
last_verified: "unverified"
---

## Identity

| Property | Value |
|----------|-------|
| **Binary** | `smartctl` |
| **Config** | `/etc/smartd.conf` (for the background monitoring daemon `smartd`) |
| **Logs** | Syslog / journald via `smartd`; self-test results stored on device |
| **Type** | CLI tool (part of smartmontools) |
| **Install** | `apt install smartmontools` / `dnf install smartmontools` |

## Quick Start

```bash
sudo apt install smartmontools         # install smartctl and smartd
sudo smartctl -H /dev/sda             # quick pass/fail health check
sudo smartctl -a /dev/sda             # full SMART attributes and device info
sudo smartctl -t short /dev/sda       # start a short self-test (~2 min)
sudo smartctl -l selftest /dev/sda    # check self-test results
```

## Key Operations

| Task | Command |
|------|---------|
| Overall health check (pass/fail summary) | `sudo smartctl -H /dev/sda` |
| All SMART attributes and device info | `sudo smartctl -a /dev/sda` |
| Device identity only (model, serial, firmware) | `sudo smartctl -i /dev/sda` |
| Start a short self-test (~2 minutes) | `sudo smartctl -t short /dev/sda` |
| Start a long self-test (hours, depends on size) | `sudo smartctl -t long /dev/sda` |
| Start a conveyance self-test (after shipping) | `sudo smartctl -t conveyance /dev/sda` |
| Check self-test log / results | `sudo smartctl -l selftest /dev/sda` |
| Check SMART error log | `sudo smartctl -l error /dev/sda` |
| Enable SMART on a drive | `sudo smartctl -s on /dev/sda` |
| NVMe drive health | `sudo smartctl -a --device=nvme /dev/nvme0` |
| USB drive via ATA passthrough | `sudo smartctl -a -d sat /dev/sdb` |
| USB drive with alternate passthrough | `sudo smartctl -a -d usb /dev/sdb` |

## Key SMART Attributes

| ID | Attribute | Critical Threshold |
|----|-----------|-------------------|
| 5 | Reallocated Sector Count | Any non-zero value is a warning; rising count indicates imminent failure |
| 9 | Power-On Hours | Context only; high hours on a used drive increases risk |
| 187 | Reported Uncorrectable Errors | Any non-zero value is serious |
| 188 | Command Timeout | Non-zero indicates bus or connector issues |
| 196 | Reallocation Event Count | Non-zero: sectors have been remapped |
| 197 | Current Pending Sector Count | Non-zero: sectors waiting to be reallocated; read errors occurring |
| 198 | Offline Uncorrectable Sectors | Non-zero: sectors that could not be recovered |
| 199 | UDMA CRC Error Count | Non-zero: cable or controller signal integrity issue |

## Common Failures

| Symptom | Cause | Fix |
|---------|-------|-----|
| `Smartctl open device: failed to open` | Requires root | Prefix with `sudo` |
| USB drive returns no SMART data | Enclosure does not pass SMART commands | Try `-d sat`, `-d usb`, or `-d sat,12` |
| "SMART support is: Unavailable" | Drive or firmware does not support SMART | Replace with a SMART-capable drive; no workaround |
| Overall health says PASSED but attribute 5 is rising | Overall PASSED is a conservative pass/fail; attributes tell the real story | Non-zero Reallocated Sector Count means the drive is degrading — schedule replacement |
| Self-test status shows "in progress" | Test runs in the background | Check again in a few minutes; `smartctl -a` shows percentage complete |
| NVMe shows different attribute names | NVMe uses a different SMART data structure | Use `--device=nvme`; attributes map to NVMe Log Page 0x02 fields |

## Common Failures (Self-Test Results)

| Status | Meaning |
|--------|---------|
| `Completed without error` | Test passed — no issues found |
| `Aborted by host` | Test was cancelled before completing |
| `Interrupted (host reset)` | System rebooted mid-test |
| `Fatal or unknown error` | Test itself failed — drive is suspect |
| `Completed: read failure` | Test found a read error at the logged LBA; sector is failing |
| `Self-test routine in progress` | Test is running; check again later |

## Pain Points

- **Root required**: smartctl opens the raw device file, which requires root. Always use `sudo`.
- **USB enclosure passthrough**: most USB-to-SATA bridge chips do not forward SMART commands by default. Try `-d sat` (SAT passthrough) or `-d usb` to work around this. Some cheap enclosures support no passthrough method at all.
- **Tests run in the background**: starting a short or long test returns immediately. The test runs on the drive's internal controller. Check results with `-l selftest` or `-a` after waiting the estimated time (shown when the test starts).
- **"PASSED" does not mean healthy**: the overall health check passes unless a SMART threshold has been crossed by the manufacturer's definition. A drive with dozens of reallocated sectors can still return PASSED. Always read the attribute table, specifically attributes 5, 187, 196, 197, and 198.
- **NVMe attribute names differ**: NVMe uses a different log page structure than ATA SMART. Attribute names like "Available Spare" and "Percentage Used" replace the ATA numbering. Always include `--device=nvme` for NVMe drives.
- **`smartd` for ongoing monitoring**: `smartctl` is a one-shot query tool. For continuous monitoring, configure `smartd` in `/etc/smartd.conf` to run scheduled self-tests and email alerts on threshold crossings.

## See Also

- **dmesg** — Kernel messages that surface drive errors, I/O failures, and hardware events
- **zfs** — ZFS filesystem with built-in scrubbing and checksum verification for data integrity
- **mdadm** — Linux software RAID management for drive redundancy alongside SMART monitoring

## References

See `references/` for:
- `cheatsheet.md` — 10 task-organized patterns for common smartctl workflows
- `docs.md` — man pages and upstream documentation links
