# iotop Cheatsheet

Ten task-organized patterns for the most common iotop workflows.

---

## 1. Identify what is hammering the disk right now

Show only processes with active I/O, refreshing every second.

```bash
sudo iotop -o -d 1
```

Press `o` in interactive mode to toggle the active-only filter without restarting.

---

## 2. Capture a snapshot for a support ticket

Batch mode, active processes only, 10 samples at 2-second intervals, saved to a file.

```bash
sudo iotop -b -o -d 2 -n 10 > /tmp/io-snapshot-$(date +%Y%m%d-%H%M%S).txt
```

The timestamp in the filename avoids overwriting previous captures.

---

## 3. Watch a specific process

Monitor a known PID (e.g., a database) without the noise of other processes.

```bash
sudo iotop -p 1234
```

Find the PID first: `pgrep -x postgres` or `systemctl show postgresql.service -p MainPID --value`.

---

## 4. Monitor all processes owned by a user

Useful for isolating I/O from a web application or container user.

```bash
sudo iotop -u www-data
```

---

## 5. Show accumulated totals instead of rates

Useful for understanding total bytes read/written over an observation window, not just instantaneous rates.

```bash
sudo iotop -a -b -n 30 -d 2
```

The `TotalREAD` and `TotalWRITE` columns accumulate across all intervals.

---

## 6. Continuous monitoring with timestamps (log to file)

Append timestamped batch output to a rolling log. Useful in a maintenance window or overnight capture.

```bash
sudo iotop -b -o -d 5 | while IFS= read -r line; do
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"
done >> /var/log/iotop-monitor.log
```

---

## 7. Find the process writing to a specific mount point

iotop shows per-process I/O but not which path. Combine with `lsof` to map process to file.

```bash
# Step 1: identify the high-I/O PID with iotop
sudo iotop -b -o -n 3 | grep -v '^Total'

# Step 2: see which files that PID has open
sudo lsof -p <PID> | grep -E 'REG|DIR'
```

---

## 8. Confirm a background job (backup, rsync) is the I/O source

Run iotop while the job is active; filter by the known user or process name.

```bash
sudo iotop -u backup -b -o -d 2
```

Or by process name pattern (match against command column):

```bash
sudo iotop -b -o -d 2 | grep rsync
```

---

## 9. Check if tmpfs or loop devices are the I/O source

High iotop totals on a system with low physical disk utilization often come from tmpfs (RAM-backed) or loop devices (container overlay filesystems). These are visible in iotop but usually harmless.

```bash
# Confirm loop device backing files
losetup -l

# Confirm tmpfs mounts
findmnt -t tmpfs

# Then check if the high-I/O PIDs map to containers
sudo iotop -b -o -n 5 | head -20
```

---

## 10. Use iotop-c (C fork) on systems where Python iotop fails

On modern kernels (6.x+), the Python version may crash or show no output. Install and use the C rewrite instead.

```bash
# Debian/Ubuntu
sudo apt install iotop-c

# Fedora/RHEL
sudo dnf install iotop-c

# Usage is identical to the Python version
sudo iotop-c -o -d 1
```

Both binaries accept the same flags. `iotop-c` is the maintained fork and preferred on any distro that packages it.
