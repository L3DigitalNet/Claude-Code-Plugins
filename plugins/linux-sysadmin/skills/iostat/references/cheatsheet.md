# iostat Cheatsheet

Ten task-organized patterns for the most common iostat workflows.

---

## 1. Current disk latency and utilization (skip the first line)

The first iostat interval averages since boot. Use two iterations and discard the first.

```bash
iostat -x 1 2 | grep -v '^$' | tail -n +7
```

Or just run `iostat -x 1` and visually ignore the first block.

---

## 2. Watch all devices with extended stats

The most common monitoring invocation: extended stats, human-readable sizes, timestamps.

```bash
iostat -xht 1
```

Key columns: `await` (latency ms), `%util` (device busy %), `aqu-sz` (queue depth).

---

## 3. Monitor a single device

Focus on one device to reduce noise. Works for both spinning disks and NVMe.

```bash
# SATA/SAS
iostat -x sda 1

# NVMe
iostat -x nvme0n1 1
```

---

## 4. Identify which partition is taking the I/O

When a disk has multiple partitions, `-p` breaks out stats per partition.

```bash
iostat -xp sda 1
iostat -xp nvme0n1 1
```

---

## 5. Capture a timed snapshot for a support ticket

10 samples at 2-second intervals, human-readable, with timestamps.

```bash
iostat -xht 2 10 > /tmp/iostat-$(date +%Y%m%d-%H%M%S).txt
```

---

## 6. Check if a device is saturated

`%util` near 100% combined with `await` > threshold indicates saturation. For NVMe, also check `aqu-sz`.

```bash
iostat -x 1 | awk 'NR==1 || /Device/ || ($NF+0) > 80'
```

This passes headers through and prints rows where the last column (`%util`) exceeds 80%.

---

## 7. Machine-parseable JSON output

Useful for feeding into a monitoring pipeline or logging to a file for later analysis.

```bash
iostat -o JSON 1 5 > /tmp/iostat-json.txt

# Parse with jq — extract device name and await for each disk
iostat -o JSON 1 2 | jq '.sysstat.hosts[0].statistics[-1].disk[] | {device: .disk_device, await: .await}'
```

---

## 8. Compare read vs write latency

`r_await` and `w_await` separate read and write average wait times. Useful for identifying write-heavy bottlenecks (e.g., a database doing heavy commits).

```bash
iostat -x 1 | awk 'NR<=3 || /Device/ || /^[a-z]/ {print $1, $9, $10, $NF}'
```

Columns: device, `r_await`, `w_await`, `%util`.

---

## 9. Throughput in MB/s for a quick I/O rate check

`-m` outputs all sizes in megabytes per second. Easier to read than the default KB/s for high-throughput devices.

```bash
iostat -xm 1
```

Compare `rMB/s` and `wMB/s` against the device's rated sequential throughput to gauge how close to saturation you are.

---

## 10. Continuous monitoring with tee (live + saved)

Watch output in the terminal while saving to a file for later review.

```bash
iostat -xht 1 | tee /tmp/iostat-session-$(date +%Y%m%d-%H%M%S).txt
```

Press `Ctrl+C` to stop. The file retains the full capture.
