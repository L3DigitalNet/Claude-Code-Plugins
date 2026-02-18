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

  registerTool(ctx, { name: "cron_add", description: "Add a crontab entry. Moderate risk.", module: "cron", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ schedule: z.string().min(9).describe("Cron schedule (e.g. '0 * * * *')"), command: z.string().min(1), user: z.string().optional(), comment: z.string().optional(), confirmed: z.boolean().optional().default(false) }), annotations: { destructiveHint: false } }, async (args) => {
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

  registerTool(ctx, { name: "cron_remove", description: "Remove a crontab entry by pattern. Moderate risk.", module: "cron", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ pattern: z.string().min(1).describe("Pattern to match the line to remove"), user: z.string().optional(), confirmed: z.boolean().optional().default(false) }), annotations: { destructiveHint: true } }, async (args) => {
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
    const valid = parts.length >= 5 && parts.length <= 7;
    const fieldNames = ["minute", "hour", "day-of-month", "month", "day-of-week"];
    const issues: string[] = [];
    if (!valid) issues.push(`Expected 5-7 fields, got ${parts.length}`);
    return success("cron_validate", ctx.targetHost, 0, null, { expression: args.expression, valid: valid && issues.length === 0, fields: parts.slice(0, 5).map((v, i) => ({ field: fieldNames[i], value: v })), issues });
  });

  registerTool(ctx, { name: "cron_next_runs", description: "Show next N scheduled execution times for a cron expression.", module: "cron", riskLevel: "read-only", duration: "instant", inputSchema: z.object({ expression: z.string().min(9), count: z.number().int().min(1).max(20).optional().default(5) }), annotations: { readOnlyHint: true } }, async (args) => {
    // Use systemd-analyze calendar if available, fall back to simple parsing
    const r = await executeBash(ctx, `systemd-analyze calendar '${args.expression}' --iterations=${(args.count as number) ?? 5} 2>/dev/null || echo 'systemd-analyze not available for cron expressions'`, "instant");
    return success("cron_next_runs", ctx.targetHost, r.durationMs, "systemd-analyze calendar", { output: r.stdout.trim() });
  });
}
