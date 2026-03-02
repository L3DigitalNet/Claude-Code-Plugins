# perf Cheatsheet

Ten task-organized patterns for the most common perf workflows.

---

## 1. Live view of CPU hotspots

`perf top` shows the functions consuming the most CPU in real time — the quickest way to identify a hot loop or an unexpected kernel path.

```bash
sudo perf top -d 5
```

`-d 5` sets a 5-second refresh delay so the display is readable. Press `a` to annotate the selected symbol with disassembly. Press `q` to quit.

---

## 2. Count hardware events for a command

`perf stat` runs a command and prints a summary of hardware performance counters (cycles, instructions, cache misses, branch mispredictions) at exit.

```bash
perf stat -e cycles,instructions,cache-misses,branch-misses ./mybinary
```

The instructions-per-cycle ratio (`IPC`) is a key health indicator: below 1.0 often indicates memory-bound behavior; above 3.0 is typical for well-optimized compute.

---

## 3. Profile a process and produce a call-graph report

Record a profile with call stacks, then open the interactive report.

```bash
# Record for 10 seconds with frame pointer call graphs
sudo perf record -g -p 1234 -- sleep 10

# Open the interactive TUI
sudo perf report
```

In `perf report`, press `Enter` on a symbol to expand its callers/callees. Press `a` to annotate with source.

---

## 4. Profile a command from start to finish

For short-lived commands or benchmarks, wrap the entire execution.

```bash
sudo perf record -g ./mybinary --args
sudo perf report --stdio | head -50
```

`--stdio` prints non-interactively, useful for CI or remote sessions without a TTY.

---

## 5. System-wide profile across all CPUs

Capture what the entire system is doing — useful for finding unexpected kernel work, interrupt storms, or background process interference.

```bash
sudo perf record -a -g -- sleep 30
sudo perf report --stdio --percent-limit 1
```

`--percent-limit 1` hides entries below 1% to reduce noise.

---

## 6. Generate a flame graph

Requires Brendan Gregg's FlameGraph scripts. Clone them once; reuse across sessions.

```bash
git clone --depth 1 https://github.com/brendangregg/FlameGraph /opt/FlameGraph

# Record
sudo perf record -a -g -- sleep 30

# Generate
sudo perf script | /opt/FlameGraph/stackcollapse-perf.pl | \
  /opt/FlameGraph/flamegraph.pl > /tmp/flame-$(date +%Y%m%d-%H%M%S).svg
```

Open the SVG in a browser. Click frames to zoom; use the search box to highlight call paths matching a pattern.

---

## 7. Identify cache-miss hotspots

High cache-miss rates cause memory-bound slowdowns that don't show up in CPU utilization. Profile with cache events.

```bash
sudo perf record -e cache-misses -g -p 1234 -- sleep 10
sudo perf report --stdio | head -30
```

Functions with high cache-miss counts are candidates for data locality improvements (struct packing, access pattern changes).

---

## 8. List all available events

perf can sample hardware counters, software events, kernel tracepoints, and PMU-specific events. List what the current system supports.

```bash
# All events grouped by type
perf list

# Filter to tracepoints only (kernel-level)
perf list | grep Tracepoint

# Filter to hardware events
perf list | grep Hardware
```

---

## 9. Attach to an already-running process with a time limit

Profile a specific process without restarting it, for a bounded duration.

```bash
sudo perf record -g -p $(pgrep -x myapp) -- sleep 60
sudo perf report
```

The `-- sleep 60` tells perf to run for 60 seconds and then stop recording. The target process continues running after perf exits.

---

## 10. Measure scheduler latency (off-CPU time)

`perf sched` records scheduler events to find time spent waiting to be scheduled — useful when a process is slow but CPU utilization appears normal.

```bash
sudo perf sched record -p 1234 -- sleep 10
sudo perf sched latency
```

The output shows wake-up latency histograms per task. High p99 latency with low average often points to lock contention or noisy neighbors.
