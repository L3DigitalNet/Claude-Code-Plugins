# vmstat Cheatsheet

Ten task-organized patterns for the most common vmstat workflows.

---

## 1. Quick current-state snapshot (discard the first line)

The first vmstat row is a since-boot average. Run two iterations and take the second.

```bash
vmstat 1 2 | tail -1
```

---

## 2. Continuous monitoring for memory pressure

Watch `si`, `so`, `free`, and `b` columns in real time. Non-zero `si`/`so` means active swapping.

```bash
vmstat -w 1
```

The `-w` flag widens columns so values don't truncate on systems with high memory.

---

## 3. Investigate I/O wait and CPU steal

`wa` > 10% indicates a disk bottleneck. `st` > 0 on a VM means the hypervisor is stealing CPU time.

```bash
vmstat -t 1
```

The `-t` flag prepends a timestamp to each line, useful when capturing to a log file.

---

## 4. Capture 5 minutes of stats to a file

Sample every 5 seconds for 60 iterations (5 minutes). The `date` header marks when the capture started.

```bash
echo "Captured at: $(date)" > /tmp/vmstat-capture.txt
vmstat -t 5 60 >> /tmp/vmstat-capture.txt
```

---

## 5. Check swap totals and memory breakdown

`vmstat -s` prints a one-time memory summary including total RAM, swap size, and current usage figures.

```bash
vmstat -s
```

Look for `used swap` vs `total swap` to gauge swap pressure at a glance.

---

## 6. Identify blocked processes (I/O saturation)

The `b` column counts processes in uninterruptible sleep waiting for I/O. Sustained `b > 0` means the I/O queue is backed up.

```bash
vmstat -w 1 | awk 'NR==1 || NR==2 || $5 > 0'
```

This passes the header lines through and then only shows lines where `b` (column 5) is non-zero.

---

## 7. Disk device statistics

`vmstat -d` shows per-device reads, writes, and I/O time totals (not rates unless combined with an interval).

```bash
vmstat -d 1
```

For rates on a specific device, prefer `iostat -x <device> 1` which provides latency (`await`) as well.

---

## 8. Per-partition I/O counters

Shows read/write counts and merged operations for a named partition.

```bash
vmstat -p sda1
vmstat -p nvme0n1p1
```

Useful for confirming which partition is taking the I/O load when a disk has multiple partitions.

---

## 9. Kernel slab cache usage

`vmstat -m` lists the kernel slab allocator caches — useful when debugging high kernel memory use that doesn't show up in user-space tools.

```bash
vmstat -m | sort -k3 -rn | head -20
```

The third column is the number of allocated slabs. High counts in `dentry` or `inode_cache` indicate filesystem cache pressure.

---

## 10. Combined wide + timestamp + continuous (production monitoring line)

The most useful single invocation for a support session: wide output, timestamps, 1-second intervals.

```bash
vmstat -tw 1
```

Pipe to `tee` to see output live while also saving it:

```bash
vmstat -tw 1 | tee /tmp/vmstat-session.txt
```
