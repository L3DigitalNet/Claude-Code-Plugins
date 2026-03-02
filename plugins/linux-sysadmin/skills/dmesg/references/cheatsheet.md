# dmesg Cheatsheet

Ten task-organized patterns for the most common dmesg workflows.

---

## 1. Check for hardware errors right now

The quickest first pass when something breaks — show only errors and warnings with readable timestamps.

```bash
sudo dmesg -T --level err,warn
```

Errors in red, warnings in yellow (with `-L` for color on terminals that support it):

```bash
sudo dmesg -TL --level err,warn
```

---

## 2. Follow kernel messages in real time

Watch for new kernel events as they happen — useful during hardware swaps, network changes, or service restarts.

```bash
sudo dmesg -TW
```

Press `Ctrl-C` to stop. `-W` requires util-linux 2.21+. On older systems:

```bash
watch -n 2 'dmesg -T | tail -20'
```

---

## 3. Diagnose a drive or NVMe error

Block device errors from the kernel typically contain the device name (`sda`, `nvme0n1`), error type, and sector number.

```bash
sudo dmesg -T | grep -iE 'sda|nvme|ata|blk|I/O error'
```

Sustained `I/O error` lines on the same device indicate a failing drive. Cross-reference with `smartctl -a /dev/sda`.

---

## 4. Find OOM kill events

When a process disappears unexpectedly, check whether the OOM killer terminated it.

```bash
sudo dmesg -T | grep -i 'oom\|out of memory\|killed process'
```

The OOM log block includes the killed process name, PID, and a memory map. Look at the lines immediately before the `Killed process` line for the triggering condition.

---

## 5. Check for USB device connect/disconnect events

Diagnose why a USB device isn't recognized, or confirm that a device was detected.

```bash
sudo dmesg -T | grep -i usb
```

A successful enumeration shows lines like `New USB device found` followed by `Product:` and `SerialNumber:`. A failed enumeration shows `device not accepting address` or `unable to enumerate USB device`.

---

## 6. Check boot messages for driver failures

Review what the kernel logged during the last boot — useful for diagnosing missing modules, firmware load failures, or hardware not detected.

```bash
# From systemd journal (persistent, survives reboots)
journalctl -k -b -p err..warning

# From dmesg (current boot only)
sudo dmesg -T | head -200
```

`-b` in journalctl means "current boot". Use `-b -1` for the previous boot.

---

## 7. Show messages from the last N minutes

Focus on recent events without scrolling through the full buffer.

```bash
sudo dmesg -T --since "10 minutes ago"
```

Or by absolute timestamp:

```bash
sudo dmesg -T --since "2024-03-01 14:00:00" --until "2024-03-01 14:30:00"
```

`--since` and `--until` require util-linux 2.33+.

---

## 8. Diagnose a kernel module or driver loading problem

When a device isn't working, check whether its module loaded without errors.

```bash
# Check load status and errors for a specific driver
sudo dmesg -T | grep -i 'firmware\|module\|driver' | grep -i 'error\|fail\|warn'

# Check for a specific module
sudo dmesg -T | grep -i iwlwifi     # example: Intel Wi-Fi driver
```

`firmware: failed to load` means the firmware file is missing from `/lib/firmware/`.

---

## 9. Check for segfaults and general protection faults

Kernel-reported segfaults and GPFs appear in dmesg with the process name, PID, and instruction pointer.

```bash
sudo dmesg -T | grep -iE 'segfault|general protection|trap|invalid opcode'
```

A line like `myapp[1234]: segfault at 0x00 ip ...` helps correlate crashes with specific processes. Cross-reference with `journalctl -u myapp` for the surrounding context.

---

## 10. Export a timestamped snapshot for a support ticket

Capture the current kernel log to a file with wall-clock timestamps, errors highlighted first.

```bash
{
  echo "=== Errors and Warnings ==="
  sudo dmesg -T --level err,warn
  echo ""
  echo "=== Full Buffer ==="
  sudo dmesg -T
} > /tmp/dmesg-$(hostname)-$(date +%Y%m%d-%H%M%S).txt
```

For a more complete picture, include the persistent journal:

```bash
journalctl -k -b > /tmp/kern-journal-$(date +%Y%m%d-%H%M%S).txt
```
