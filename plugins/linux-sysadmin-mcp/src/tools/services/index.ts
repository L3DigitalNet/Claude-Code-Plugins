import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, executeBash, executeCommand, buildCategorizedResponse } from "../helpers.js";

export function registerServiceTools(ctx: PluginContext): void {
  // ── svc_list ────────────────────────────────────────────────────
  registerTool(ctx, {
    name: "svc_list", description: "List all services and their states. Supports filtering by status.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({
      filter: z.string().optional().describe("Filter by unit name or 'failed'/'running'/'inactive'"),
      limit: z.number().int().min(1).max(500).optional().default(50),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const filter = args.filter as string | undefined;
    let cmd = "systemctl list-units --type=service --no-pager --no-legend";
    if (filter === "failed") cmd = "systemctl list-units --type=service --state=failed --no-pager --no-legend";
    else if (filter === "running") cmd = "systemctl list-units --type=service --state=running --no-pager --no-legend";
    else if (filter === "inactive") cmd = "systemctl list-units --type=service --state=inactive --no-pager --no-legend";
    else if (filter) cmd += ` | grep -i '${filter}'`;
    const r = await executeBash(ctx, cmd, "quick");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const limit = (args.limit as number) ?? 50;
    const services = lines.slice(0, limit).map((l) => {
      const parts = l.trim().split(/\s+/);
      return { unit: parts[0], load: parts[1], active: parts[2], sub: parts[3], description: parts.slice(4).join(" ") };
    });
    return success("svc_list", ctx.targetHost, r.durationMs, cmd, { services }, {
      total: lines.length, returned: services.length, truncated: lines.length > limit, filter: filter ?? null,
    });
  });

  // ── svc_status ──────────────────────────────────────────────────
  registerTool(ctx, {
    name: "svc_status", description: "Detailed status of a specific service. Enriched with knowledge profile health checks when available.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({ service: z.string().min(1).describe("Service/unit name") }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string;
    const cmd = ctx.commands.serviceStatus(svc);
    const r = await executeCommand(ctx, "svc_status", cmd, "quick");
    // Parse systemctl status output
    const output = r.stdout.trim();
    const data: Record<string, unknown> = { service: svc, raw_status: output };
    // Extract key fields
    const activeMatch = output.match(/Active:\s+(\S+)\s+\((\S+)\)/);
    if (activeMatch) { data.active_state = activeMatch[1]; data.sub_state = activeMatch[2]; }
    const pidMatch = output.match(/Main PID:\s+(\d+)/);
    if (pidMatch) data.pid = parseInt(pidMatch[1]);
    const memMatch = output.match(/Memory:\s+([\d.]+\S+)/);
    if (memMatch) data.memory = memMatch[1];
    // Check knowledge profile health checks
    const profile = ctx.knowledgeBase.getProfile(svc);
    if (profile?.health_checks) {
      const checks: Array<{ description: string; passed: boolean; output: string }> = [];
      for (const hc of profile.health_checks) {
        const hr = await executeBash(ctx, hc.command, "quick");
        let passed = true;
        if (hc.expect_exit !== undefined) passed = hr.exitCode === hc.expect_exit;
        if (hc.expect_contains) passed = passed && hr.stdout.includes(hc.expect_contains);
        checks.push({ description: hc.description, passed, output: hr.stdout.trim().slice(0, 200) });
      }
      data.health_checks = checks;
    }
    return success("svc_status", ctx.targetHost, r.durationMs, cmd.argv.join(" "), data);
  });

  // ── svc_start / svc_stop / svc_restart ──────────────────────────
  for (const action of ["start", "stop", "restart"] as const) {
    registerTool(ctx, {
      name: `svc_${action}`,
      description: `${action.charAt(0).toUpperCase() + action.slice(1)} a service. Moderate risk (may escalate via knowledge profiles).`,
      module: "services", riskLevel: "moderate", duration: "quick",
      inputSchema: z.object({
        service: z.string().min(1).describe("Service or unit name (e.g. 'nginx', 'nginx.service')"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes."),
      }),
      annotations: { destructiveHint: action === "stop" },
    }, async (args) => {
      const svc = args.service as string;
      const cmd = ctx.commands.serviceControl(svc, action);
      const gate = ctx.safetyGate.check({
        toolName: `svc_${action}`, toolRiskLevel: "moderate", targetHost: ctx.targetHost,
        command: cmd.argv.join(" "), description: `${action} service ${svc}`,
        confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean, serviceName: svc,
      });
      if (gate) return gate;
      if (args.dry_run) return success(`svc_${action}`, ctx.targetHost, null, null, { preview_command: cmd.argv.join(" ") }, { dry_run: true });
      const r = await executeCommand(ctx, `svc_${action}`, cmd, "quick");
      if (r.exitCode !== 0) return buildCategorizedResponse(`svc_${action}`, ctx.targetHost, r.durationMs, r.stderr, ctx);
      const docHint = ctx.config.documentation.repo_path
        ? { documentation_action: { type: "service_changed", service: svc, suggested_actions: [`doc_generate_service service=${svc}`, `doc_backup_config service=${svc}`] } }
        : undefined;
      return success(`svc_${action}`, ctx.targetHost, r.durationMs, cmd.argv.join(" "), { service: svc, action, result: "ok" }, docHint);
    });
  }

  // ── svc_enable / svc_disable ────────────────────────────────────
  for (const action of ["enable", "disable"] as const) {
    registerTool(ctx, {
      name: `svc_${action}`, description: `${action.charAt(0).toUpperCase() + action.slice(1)} a service at boot. Moderate risk.`,
      module: "services", riskLevel: "moderate", duration: "quick",
      inputSchema: z.object({ service: z.string().min(1).describe("Service or unit name (e.g. 'nginx', 'nginx.service')"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }),
      annotations: { destructiveHint: false },
    }, async (args) => {
      const svc = args.service as string;
      const cmd = ctx.commands.serviceControl(svc, action);
      const gate = ctx.safetyGate.check({
        toolName: `svc_${action}`, toolRiskLevel: "moderate", targetHost: ctx.targetHost,
        command: cmd.argv.join(" "), description: `${action} service ${svc} at boot`,
        confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
      });
      if (gate) return gate;
      if (args.dry_run) return success(`svc_${action}`, ctx.targetHost, null, null, { preview_command: cmd.argv.join(" ") }, { dry_run: true });
      const r = await executeCommand(ctx, `svc_${action}`, cmd, "quick");
      if (r.exitCode !== 0) return buildCategorizedResponse(`svc_${action}`, ctx.targetHost, r.durationMs, r.stderr, ctx);
      return success(`svc_${action}`, ctx.targetHost, r.durationMs, cmd.argv.join(" "), { service: svc, action, enabled_at_boot: action === "enable" });
    });
  }

  // ── svc_logs ────────────────────────────────────────────────────
  registerTool(ctx, {
    name: "svc_logs", description: "Retrieve recent logs for a service. Consults knowledge profile for all log sources.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({
      service: z.string().min(1).describe("Service or unit name (e.g. 'nginx', 'nginx.service')"), lines: z.number().int().min(1).max(500).optional().default(50).describe("Number of log lines to retrieve (default 50, max 500)"),
      since: z.string().optional().describe("Time filter e.g. '1 hour ago', '2024-01-01'"),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string;
    const lines = (args.lines as number) ?? 50;
    let cmd = `journalctl -u ${svc} -n ${lines} --no-pager`;
    if (args.since) cmd += ` --since '${args.since}'`;
    const r = await executeBash(ctx, cmd, "quick");
    const journalLines = r.stdout.trim().split("\n").filter(Boolean);
    const data: Record<string, unknown> = {
      service: svc,
      journal_logs: journalLines,
      log_line_count: journalLines.length,
      // truncated when returned lines equals the requested limit — more may exist
      truncated: journalLines.length >= lines,
    };
    // Check knowledge profile for additional log paths
    const profile = ctx.knowledgeBase.getProfile(svc);
    if (profile?.logs) {
      const fileLogs: Array<{ path: string; tail: string }> = [];
      for (const log of profile.logs) {
        if (log.path) {
          const lr = await executeBash(ctx, `tail -n ${lines} '${log.path}' 2>/dev/null`, "quick");
          if (lr.exitCode === 0 && lr.stdout.trim()) fileLogs.push({ path: log.path, tail: lr.stdout.trim() });
        }
      }
      if (fileLogs.length) data.file_logs = fileLogs;
    }
    return success("svc_logs", ctx.targetHost, r.durationMs, cmd, data);
  });

  // ── timer_list ──────────────────────────────────────────────────
  registerTool(ctx, {
    name: "timer_list", description: "List systemd timers and their schedules.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}),
    annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "systemctl list-timers --all --no-pager --no-legend", "quick");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const timers = lines.map((l) => {
      const parts = l.trim().split(/\s{2,}/);
      return { next: parts[0], left: parts[1], last: parts[2], passed: parts[3], unit: parts[4], activates: parts[5] };
    });
    return success("timer_list", ctx.targetHost, r.durationMs, "systemctl list-timers", { timers, count: timers.length });
  });
}
