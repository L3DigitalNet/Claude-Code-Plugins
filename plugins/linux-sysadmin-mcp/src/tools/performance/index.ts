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
    return success("perf_overview", ctx.targetHost, loadR.durationMs, "multiple (loadavg, free, df)", {
      load_average: { "1m": parseFloat(loadParts[0] ?? "0"), "5m": parseFloat(loadParts[1] ?? "0"), "15m": parseFloat(loadParts[2] ?? "0") },
      memory: memR.stdout.trim(),
      disk: diskR.stdout.trim(),
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
    return success("perf_memory", ctx.targetHost, memR.durationMs, "free -m + /proc/meminfo + ps", {
      memory_info: memR.stdout.trim(), top_consumers: topR.stdout.trim(),
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
    return success("perf_network_io", ctx.targetHost, r.durationMs, "cat /proc/net/dev", { net_dev: r.stdout.trim() });
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
