import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, executeBash } from "../helpers.js";

export function registerLogTools(ctx: PluginContext): void {
  registerTool(ctx, {
    name: "log_query", description: "Query system logs via journalctl with time range and unit filters.",
    module: "logs", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({
      unit: z.string().optional().describe("Systemd unit name"),
      since: z.string().optional().describe("Start time e.g. '1 hour ago'"),
      until: z.string().optional().describe("End time"),
      priority: z.enum(["emerg", "alert", "crit", "err", "warning", "notice", "info", "debug"]).optional(),
      limit: z.number().int().min(1).max(1000).optional().default(100),
      grep: z.string().optional().describe("Filter log lines by pattern"),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    let cmd = "journalctl --no-pager";
    if (args.unit) cmd += ` -u ${args.unit}`;
    if (args.since) cmd += ` --since '${args.since}'`;
    if (args.until) cmd += ` --until '${args.until}'`;
    if (args.priority) cmd += ` -p ${args.priority}`;
    cmd += ` -n ${(args.limit as number) ?? 100}`;
    if (args.grep) cmd += ` -g '${args.grep}'`;
    const r = await executeBash(ctx, cmd, "normal");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    return success("log_query", ctx.targetHost, r.durationMs, cmd, { lines, count: lines.length });
  });

  registerTool(ctx, {
    name: "log_search", description: "Search across log files and journal for a pattern.",
    module: "logs", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({
      pattern: z.string().min(1).describe("Search pattern (grep-compatible)"),
      paths: z.array(z.string()).optional().describe("Specific log file paths to search"),
      since: z.string().optional(), limit: z.number().int().min(1).max(500).optional().default(100),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const limit = (args.limit as number) ?? 100;
    const results: Record<string, unknown> = {};
    // Search journal
    let jcmd = `journalctl --no-pager -g '${args.pattern}' -n ${limit}`;
    if (args.since) jcmd += ` --since '${args.since}'`;
    const jr = await executeBash(ctx, jcmd, "normal");
    results.journal = jr.stdout.trim().split("\n").filter(Boolean).slice(0, limit);
    // Search specific file paths
    const paths = (args.paths as string[] | undefined) ?? ["/var/log/syslog", "/var/log/messages"];
    const fileResults: Array<{ path: string; matches: string[] }> = [];
    for (const p of paths) {
      const fr = await executeBash(ctx, `grep -i '${args.pattern}' '${p}' 2>/dev/null | tail -n ${limit}`, "quick");
      if (fr.stdout.trim()) fileResults.push({ path: p, matches: fr.stdout.trim().split("\n").slice(0, limit) });
    }
    results.files = fileResults;
    return success("log_search", ctx.targetHost, jr.durationMs, `journalctl -g + grep`, results);
  });

  registerTool(ctx, {
    name: "log_summary", description: "Summarize recent log activity: error counts by unit, warning spikes.",
    module: "logs", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({ since: z.string().optional().default("1 hour ago") }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const since = (args.since as string) ?? "1 hour ago";
    const r = await executeBash(ctx, `journalctl --no-pager --since '${since}' -p err --output=json 2>/dev/null | wc -l`, "normal");
    const errCount = parseInt(r.stdout.trim()) || 0;
    const r2 = await executeBash(ctx, `journalctl --no-pager --since '${since}' -p warning --output=json 2>/dev/null | wc -l`, "normal");
    const warnCount = parseInt(r2.stdout.trim()) || 0;
    const r3 = await executeBash(ctx, `journalctl --no-pager --since '${since}' -p err -o short | awk '{print $5}' | sort | uniq -c | sort -rn | head -10`, "normal");
    const topUnits = r3.stdout.trim();
    const severity = errCount > 50 ? "high" as const : errCount > 10 ? "warning" as const : "info" as const;
    return success("log_summary", ctx.targetHost, r.durationMs, "journalctl analysis", {
      error_count: errCount, warning_count: warnCount, top_error_units: topUnits, period: since,
    }, { summary: `${errCount} errors and ${warnCount} warnings in the last period. ${topUnits ? "Top units with errors shown." : "No unit-level breakdown available."}`, severity });
  });

  registerTool(ctx, {
    name: "log_disk_usage", description: "Show disk space used by logs (journal + file logs).",
    module: "logs", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "journalctl --disk-usage 2>/dev/null && echo '---' && du -sh /var/log/ 2>/dev/null", "quick");
    return success("log_disk_usage", ctx.targetHost, r.durationMs, "journalctl --disk-usage + du", { output: r.stdout.trim() });
  });
}
