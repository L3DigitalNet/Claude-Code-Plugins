# smartctl Cheatsheet

## 1. Quick Health Check

The fastest way to check if a drive is healthy. Returns PASSED or FAILED.

```bash
sudo smartctl -H /dev/sda
sudo smartctl -H /dev/nvme0
```

Sample output:
```
SMART overall-health self-assessment test result: PASSED
```

PASSED means no manufacturer-defined threshold has been crossed. It does NOT mean
the drive is problem-free — always check attributes 5, 196, 197, and 198 separately.

---

## 2. Full SMART Report

All attributes, device info, error log, and self-test history in one command.

```bash
sudo smartctl -a /dev/sda
```

Key sections to review:
1. **SMART overall-health** — pass/fail
2. **SMART Attributes** — look for non-zero values in IDs 5, 187, 196, 197, 198
3. **SMART Error Log** — any entries here indicate real errors occurred
4. **SMART Self-test log** — results of previous tests

---

## 3. Run a Short Self-Test

Short test takes ~2 minutes and tests the drive's read/write mechanisms and servo.

```bash
sudo smartctl -t short /dev/sda
```

After starting, wait 2 minutes and check results:

```bash
sudo smartctl -l selftest /dev/sda
```

Or check the status inline:

```bash
sudo smartctl -a /dev/sda | grep -A 5 "Self-test log"
```

---

## 4. Run a Long Self-Test

Long test scans every sector. Duration depends on drive size (1-12+ hours for large HDDs).

```bash
# Start the test (returns immediately, test runs in background)
sudo smartctl -t long /dev/sda

# Check estimated completion time from the output, then poll
sudo smartctl -a /dev/sda | grep -E "Self-test.*in progress|% of test remaining"

# Check results when done
sudo smartctl -l selftest /dev/sda
```

The test can be aborted:
```bash
sudo smartctl -X /dev/sda
```

---

## 5. Check Critical Attributes

Filter the SMART attribute table to the most failure-predictive values.

```bash
sudo smartctl -a /dev/sda | grep -E "Reallocated|Pending|Uncorrectable|Command_Timeout|CRC"
```

Attributes to watch:
```
  5 Reallocated_Sector_Ct   - any non-zero: sectors failed and were remapped
196 Reallocated_Event_Count - counts how many remap events have occurred
197 Current_Pending_Sector  - sectors being read with errors; may be reallocated soon
198 Offline_Uncorrectable   - sectors that failed during background scan; cannot be read
187 Reported_Uncorrect       - reported uncorrectable errors
199 UDMA_CRC_Error_Count    - cable/controller signal issues
```

A rising count in any of these is a sign to schedule drive replacement.

---

## 6. NVMe Drive Health

NVMe drives use a different data structure than ATA SMART. Specify the device type.

```bash
sudo smartctl -a --device=nvme /dev/nvme0
sudo smartctl -H --device=nvme /dev/nvme0
```

Key NVMe health indicators:
```
Available Spare:          90%    <- drops as spare NAND is consumed
Available Spare Threshold: 10%   <- failure threshold
Percentage Used:           2%    <- wear level (100% = end of rated life)
Data Units Written:        ...   <- total write volume
Power-On Hours:            ...
```

---

## 7. USB Drive Passthrough

USB enclosures often don't forward SMART commands. Try different passthrough modes.

```bash
# Try SAT (SCSI-ATA Translation) first — works for most SATA-in-USB enclosures
sudo smartctl -a -d sat /dev/sdb

# If SAT fails, try generic USB
sudo smartctl -a -d usb /dev/sdb

# For JMicron chipsets
sudo smartctl -a -d usb,0x0204 /dev/sdb

# Probe for the right device type (smartctl guesses)
sudo smartctl -a /dev/sdb   # often works even without -d flag
```

If no passthrough method works, the enclosure chip does not support SMART forwarding.
Connect the drive directly via SATA to get SMART data.

---

## 8. Enable SMART if Disabled

Some drives ship with SMART disabled. Enable it before querying.

```bash
# Check if SMART is enabled
sudo smartctl -i /dev/sda | grep -i "SMART support"

# Enable SMART
sudo smartctl -s on /dev/sda

# Verify
sudo smartctl -i /dev/sda
```

---

## 9. Check SMART Error Log

The error log records actual I/O errors reported by the drive. Any entries here
indicate real errors occurred during normal operation.

```bash
sudo smartctl -l error /dev/sda
```

Healthy drives return:
```
SMART Error Log Version: 1
No Errors Logged
```

If errors are logged, note the LBA address and cross-reference with `dmesg` for
which file or partition is affected.

---

## 10. Batch Health Check (All Drives)

Check all drives in one pass. Useful for server audits.

```bash
# Find all block devices that are real disks (not partitions)
for dev in $(lsblk -d -n -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'); do
    echo "=== $dev ==="
    sudo smartctl -H "$dev" 2>&1
    sudo smartctl -a "$dev" 2>&1 | grep -E "Reallocated|Pending|Uncorrectable|PASSED|FAILED"
    echo
done
```

Or use smartctl's scan mode to detect all drives:

```bash
sudo smartctl --scan
sudo smartctl --scan | awk '{print $1}' | while read dev; do
    echo "=== $dev ==="
    sudo smartctl -H "$dev"
done
```
