import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, executeBash } from "../helpers.js";

export function registerPerformanceTools(ctx: PluginContext): void {
  // ── perf_overview ───────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_overview", description: "System overview: CPU, memory, disk I/O, load averages.",
    module: "performance", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const [loadR, memR, diskR] = await Promise.all([
      executeBash(ctx, "cat /proc/loadavg", "instant"),
      executeBash(ctx, "free -m", "instant"),
      executeBash(ctx, "df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null || df -h", "instant"),
    ]);
    const loadParts = loadR.stdout.trim().split(/\s+/);
    // Parse free -m output into structured fields instead of returning a raw string
    const memLines = memR.stdout.trim().split("\n");
    const memParsed: Record<string, unknown> = {};
    for (const line of memLines) {
      const parts = line.trim().split(/\s+/);
      if (parts[0]?.toLowerCase().startsWith("mem:")) {
        memParsed.ram = { total_mb: parseInt(parts[1] ?? "0"), used_mb: parseInt(parts[2] ?? "0"), free_mb: parseInt(parts[3] ?? "0"), shared_mb: parseInt(parts[4] ?? "0"), bufcache_mb: parseInt(parts[5] ?? "0"), available_mb: parseInt(parts[6] ?? "0") };
      } else if (parts[0]?.toLowerCase().startsWith("swap:")) {
        memParsed.swap = { total_mb: parseInt(parts[1] ?? "0"), used_mb: parseInt(parts[2] ?? "0"), free_mb: parseInt(parts[3] ?? "0") };
      }
    }
    // Parse df output into structured array; fall back to raw on parse failure
    const diskLines = diskR.stdout.trim().split("\n").slice(1).filter(Boolean); // skip header
    const diskParsed = diskLines.map((l) => {
      const p = l.trim().split(/\s+/);
      return { filesystem: p[0], size: p[1], used: p[2], avail: p[3], use_pct: p[4], mount: p[5] };
    }).filter(d => d.mount);
    return success("perf_overview", ctx.targetHost, loadR.durationMs, "multiple (loadavg, free, df)", {
      load_average: { "1m": parseFloat(loadParts[0] ?? "0"), "5m": parseFloat(loadParts[1] ?? "0"), "15m": parseFloat(loadParts[2] ?? "0") },
      memory: Object.keys(memParsed).length > 0 ? memParsed : { raw: memR.stdout.trim() },
      disk: diskParsed.length > 0 ? diskParsed : { raw: diskR.stdout.trim() },
    });
  });

  // ── perf_top_processes ──────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_top_processes", description: "Top processes by CPU or memory usage.",
    module: "performance", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({
      sort_by: z.enum(["cpu", "memory"]).optional().default("cpu"),
      limit: z.number().int().min(1).max(50).optional().default(10),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const sort = (args.sort_by as string) === "memory" ? "--sort=-rss" : "--sort=-pcpu";
    const limit = (args.limit as number) ?? 10;
    const r = await executeBash(ctx, `ps aux ${sort} | head -n ${limit + 1}`, "quick");
    const lines = r.stdout.trim().split("\n");
    const header = lines[0];
    const processes = lines.slice(1).map((l) => {
      const p = l.trim().split(/\s+/);
      return { user: p[0], pid: p[1], cpu: p[2], mem: p[3], vsz: p[4], rss: p[5], command: p.slice(10).join(" ") };
    });
    return success("perf_top_processes", ctx.targetHost, r.durationMs, `ps aux ${sort}`, { header, processes });
  });

  // ── perf_memory ─────────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_memory", description: "Detailed memory breakdown: RAM, swap, buffers/cache, top memory consumers.",
    module: "performance", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({ top_consumers: z.number().int().min(1).max(20).optional().default(10) }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const n = (args.top_consumers as number) ?? 10;
    const [memR, topR] = await Promise.all([
      executeBash(ctx, "free -m && echo '---' && cat /proc/meminfo | head -20", "instant"),
      executeBash(ctx, `ps aux --sort=-rss | head -n ${n + 1}`, "quick"),
    ]);
    // Parse free -m section from memory_info output (before '---')
    const memSection = memR.stdout.trim().split("---")[0] ?? "";
    const memParsed: Record<string, unknown> = {};
    for (const line of memSection.trim().split("\n")) {
      const parts = line.trim().split(/\s+/);
      if (parts[0]?.toLowerCase().startsWith("mem:")) {
        memParsed.ram = { total_mb: parseInt(parts[1] ?? "0"), used_mb: parseInt(parts[2] ?? "0"), free_mb: parseInt(parts[3] ?? "0"), available_mb: parseInt(parts[6] ?? "0") };
      } else if (parts[0]?.toLowerCase().startsWith("swap:")) {
        memParsed.swap = { total_mb: parseInt(parts[1] ?? "0"), used_mb: parseInt(parts[2] ?? "0") };
      }
    }
    // Parse top consumers from ps output
    const topLines = topR.stdout.trim().split("\n");
    const topConsumers = topLines.slice(1).map((l) => {
      const p = l.trim().split(/\s+/);
      return { user: p[0], pid: p[1], mem_pct: p[3], rss_kb: parseInt(p[5] ?? "0"), command: p.slice(10).join(" ") };
    });
    return success("perf_memory", ctx.targetHost, memR.durationMs, "free -m + /proc/meminfo + ps", {
      memory: Object.keys(memParsed).length > 0 ? memParsed : { raw: memSection.trim() },
      meminfo_raw: memR.stdout.trim().split("---")[1]?.trim(),
      top_consumers: topConsumers.length > 0 ? topConsumers : { raw: topR.stdout.trim() },
    });
  });

  // ── perf_disk_io ────────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_disk_io", description: "Disk I/O statistics per device.",
    module: "performance", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    // Try iostat first, fall back to /proc/diskstats
    let r = await executeBash(ctx, "iostat -x 1 1 2>/dev/null || cat /proc/diskstats", "quick");
    return success("perf_disk_io", ctx.targetHost, r.durationMs, "iostat -x 1 1", { io_stats: r.stdout.trim() });
  });

  // ── perf_network_io ─────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_network_io", description: "Network throughput statistics per interface.",
    module: "performance", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "cat /proc/net/dev", "instant");
    // /proc/net/dev: skip 2 header lines, parse interface name and rx/tx byte counts
    const netLines = r.stdout.trim().split("\n").slice(2).filter(Boolean);
    const interfaces = netLines.map((line) => {
      const [ifacePart, statsPart] = line.split(":");
      const iface = ifacePart?.trim();
      const stats = statsPart?.trim().split(/\s+/) ?? [];
      return {
        interface: iface,
        rx_bytes: parseInt(stats[0] ?? "0"),
        rx_packets: parseInt(stats[1] ?? "0"),
        rx_errors: parseInt(stats[2] ?? "0"),
        tx_bytes: parseInt(stats[8] ?? "0"),
        tx_packets: parseInt(stats[9] ?? "0"),
        tx_errors: parseInt(stats[10] ?? "0"),
      };
    }).filter(i => i.interface);
    return success("perf_network_io", ctx.targetHost, r.durationMs, "cat /proc/net/dev", {
      interfaces,
      note: "rx_bytes/tx_bytes are cumulative since boot — call twice and diff for throughput rate",
    });
  });

  // ── perf_uptime ─────────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_uptime", description: "Uptime, boot time, and load averages.",
    module: "performance", riskLevel: "read-only", duration: "instant",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "uptime && echo '---' && who -b", "instant");
    return success("perf_uptime", ctx.targetHost, r.durationMs, "uptime", { output: r.stdout.trim() });
  });

  // ── perf_bottleneck ─────────────────────────────────────────────
  registerTool(ctx, {
    name: "perf_bottleneck", description: "Heuristic analysis of likely system bottleneck (CPU/memory/disk/network).",
    module: "performance", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const [loadR, memR, ioR, topR] = await Promise.all([
      executeBash(ctx, "cat /proc/loadavg", "instant"),
      executeBash(ctx, "free -m | grep Mem", "instant"),
      executeBash(ctx, "cat /proc/stat | head -1", "instant"),
      executeBash(ctx, "ps aux --sort=-pcpu | head -6", "quick"),
    ]);
    // Parse load average
    const loadParts = loadR.stdout.trim().split(/\s+/);
    const load1m = parseFloat(loadParts[0] ?? "0");
    // Parse memory
    const memParts = memR.stdout.trim().split(/\s+/);
    const memTotal = parseInt(memParts[1] ?? "1");
    const memAvail = parseInt(memParts[6] ?? memParts[3] ?? "0");
    const memUsedPct = ((memTotal - memAvail) / memTotal) * 100;
    // Simple heuristic
    let bottleneck = "none";
    let severity: "info" | "warning" | "high" | "critical" = "info";
    let summary = "System appears healthy.";

    if (load1m > 4) { bottleneck = "cpu"; severity = load1m > 8 ? "high" : "warning"; summary = `High CPU load (${load1m}). Check top processes.`; }
    if (memUsedPct > 90) { bottleneck = "memory"; severity = memUsedPct > 95 ? "critical" : "high"; summary = `Memory pressure at ${memUsedPct.toFixed(1)}%.`; }

    return success("perf_bottleneck", ctx.targetHost, loadR.durationMs, "multiple (loadavg, free, /proc/stat)", {
      load_1m: load1m, memory_used_pct: Math.round(memUsedPct), memory_available_mb: memAvail,
      top_processes: topR.stdout.trim(), bottleneck,
    }, { summary, severity });
  });
}
