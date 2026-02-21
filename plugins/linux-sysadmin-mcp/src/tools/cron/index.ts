import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerCronTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "cron_list", description: "List crontab entries for a user or all users.", module: "cron", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ user: z.string().optional().describe("Username (omit for current user, 'all' for all users)") }), annotations: { readOnlyHint: true } }, async (args) => {
    const u = args.user as string | undefined;
    let cmd: string;
    if (u === "all") cmd = "for u in $(cut -d: -f1 /etc/passwd); do echo \"=== $u ===\"; sudo -n crontab -l -u $u 2>/dev/null || true; done";
    else if (u) cmd = `sudo -n crontab -l -u ${u} 2>/dev/null || crontab -l -u ${u} 2>/dev/null || echo 'No crontab for ${u}'`;
    else cmd = "crontab -l 2>/dev/null || echo 'No crontab for current user'";
    const r = await executeBash(ctx, cmd, "quick");
    return success("cron_list", ctx.targetHost, r.durationMs, cmd, { crontab: r.stdout.trim() });
  });

  registerTool(ctx, { name: "cron_add", description: "Add a crontab entry. Moderate risk.", module: "cron", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ schedule: z.string().min(9).describe("Cron schedule (e.g. '0 * * * *')"), command: z.string().min(1), user: z.string().optional(), comment: z.string().optional(), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response.") }), annotations: { destructiveHint: false } }, async (args) => {
    const u = args.user ? `-u ${args.user}` : "";
    const commentLine = args.comment ? `# ${args.comment}\n` : "";
    const entry = `${commentLine}${args.schedule} ${args.command}`;
    const cmd = `(crontab -l ${u} 2>/dev/null; echo '${entry}') | crontab - ${u}`;
    const gate = ctx.safetyGate.check({ toolName: "cron_add", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Add cron: ${args.schedule} ${args.command}`, confirmed: args.confirmed as boolean });
    if (gate) return gate;
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("cron_add", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("cron_add", ctx.targetHost, r.durationMs, cmd, { added: entry.trim() });
  });

  registerTool(ctx, { name: "cron_remove", description: "Remove a crontab entry by pattern. Moderate risk.", module: "cron", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ pattern: z.string().min(1).describe("Pattern to match the line to remove"), user: z.string().optional(), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response.") }), annotations: { destructiveHint: true } }, async (args) => {
    const u = args.user ? `-u ${args.user}` : "";
    const cmd = `crontab -l ${u} 2>/dev/null | grep -v '${args.pattern}' | crontab - ${u}`;
    const gate = ctx.safetyGate.check({ toolName: "cron_remove", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Remove cron entries matching: ${args.pattern}`, confirmed: args.confirmed as boolean });
    if (gate) return gate;
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("cron_remove", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("cron_remove", ctx.targetHost, r.durationMs, cmd, { removed_pattern: args.pattern });
  });

  registerTool(ctx, { name: "cron_validate", description: "Validate cron expression syntax.", module: "cron", riskLevel: "read-only", duration: "instant", inputSchema: z.object({ expression: z.string().min(9) }), annotations: { readOnlyHint: true } }, async (args) => {
    const parts = (args.expression as string).trim().split(/\s+/);
    const fieldNames = ["minute", "hour", "day-of-month", "month", "day-of-week"];
    // [min, max] inclusive for each of the 5 standard cron positions
    const fieldRanges: [number, number][] = [[0, 59], [0, 23], [1, 31], [1, 12], [0, 7]];
    const issues: string[] = [];

    if (parts.length < 5 || parts.length > 7) {
      issues.push(`Expected 5-7 fields, got ${parts.length}`);
    } else {
      // For each field, extract numeric base values (not step denominators) and validate ranges.
      // Handles: literals (5), lists (1,5,10), ranges (1-15), stepped (*/5, 10-30/2).
      parts.slice(0, 5).forEach((part, i) => {
        const [min, max] = fieldRanges[i];
        const name = fieldNames[i];
        // Strip step denominators (/N), wildcards, then split on list/range separators
        const tokens = part.replace(/\/\d+/g, "").replace(/[*?]/g, "").split(/[,\-]/).filter(Boolean);
        for (const token of tokens) {
          const n = parseInt(token, 10);
          if (!isNaN(n) && (n < min || n > max)) {
            issues.push(`${name}: ${n} out of range ${min}-${max}`);
          }
        }
      });
    }

    return success("cron_validate", ctx.targetHost, 0, null, {
      expression: args.expression,
      valid: issues.length === 0,
      fields: parts.slice(0, 5).map((v, i) => ({ field: fieldNames[i], value: v })),
      issues
    });
  });

  registerTool(ctx, { name: "cron_next_runs", description: "Show next N scheduled execution times for a cron expression.", module: "cron", riskLevel: "read-only", duration: "instant", inputSchema: z.object({ expression: z.string().min(9), count: z.number().int().min(1).max(20).optional().default(5) }), annotations: { readOnlyHint: true } }, async (args) => {
    // Pure-JS cron calculator — systemd-analyze uses OnCalendar syntax (not cron), so it always failed.
    // Walks forward minute-by-minute from now; capped at 1 year (527040 min) for sparse expressions.
    const count = (args.count as number) ?? 5;
    const expr = (args.expression as string).trim();
    const parts = expr.split(/\s+/);
    if (parts.length < 5) {
      return success("cron_next_runs", ctx.targetHost, 0, null, { error: `Invalid expression: expected 5 fields, got ${parts.length}`, next_runs: [] });
    }
    const [minF, hourF, domF, monF, dowF] = parts;

    // Match a single cron field value against a Date component value.
    // Handles: * (wildcard), */N (step), N (literal), N-M (range), N-M/S (stepped range), N,M,... (list).
    function matchField(field: string, value: number): boolean {
      if (field === "*" || field === "?") return true;
      for (const part of field.split(",")) {
        const slashIdx = part.indexOf("/");
        const step = slashIdx !== -1 ? parseInt(part.slice(slashIdx + 1), 10) : 1;
        const rangeStep = slashIdx !== -1 ? part.slice(0, slashIdx) : part;
        if (rangeStep === "*") {
          // */N — accept any value that is divisible by step relative to 0
          if (value % step === 0) return true;
        } else if (rangeStep.includes("-")) {
          const [lo, hi] = rangeStep.split("-").map(Number);
          if (value >= lo && value <= hi && (value - lo) % step === 0) return true;
        } else {
          if (value === parseInt(rangeStep, 10)) return true;
        }
      }
      return false;
    }

    const results: string[] = [];
    const start = new Date();
    start.setSeconds(0, 0);
    start.setMinutes(start.getMinutes() + 1);
    const cur = new Date(start.getTime());
    let iterations = 0;
    const maxIterations = 527040; // 1 year in minutes — guards against @yearly-style sparse expressions

    while (results.length < count && iterations < maxIterations) {
      const dow = cur.getDay(); // 0=Sun, 6=Sat
      // Sunday can be 0 or 7 in cron — check both
      const dowMatch = matchField(dowF, dow) || (dow === 0 && matchField(dowF, 7));

      if (matchField(monF, cur.getMonth() + 1) && matchField(domF, cur.getDate()) && dowMatch &&
          matchField(hourF, cur.getHours()) && matchField(minF, cur.getMinutes())) {
        results.push(cur.toISOString().replace("T", " ").slice(0, 16) + " UTC");
      }

      cur.setMinutes(cur.getMinutes() + 1);
      iterations++;
    }

    return success("cron_next_runs", ctx.targetHost, 0, null, { expression: expr, next_runs: results, searched_minutes: iterations });
  });
}
