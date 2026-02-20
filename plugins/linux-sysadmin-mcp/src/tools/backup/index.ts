import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerBackupTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "bak_list", description: "List existing backups.", module: "backup", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ path: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const p = (args.path as string) ?? ctx.config.documentation.repo_path ?? "/var/backups";
    const r = await executeBash(ctx, `ls -lhrt '${p}/' 2>/dev/null | tail -30`, "quick");
    return success("bak_list", ctx.targetHost, r.durationMs, `ls ${p}`, { backups: r.stdout.trim(), path: p });
  });

  registerTool(ctx, { name: "bak_create", description: "Create a backup of paths using tar or rsync. Moderate risk.", module: "backup", riskLevel: "moderate", duration: "slow", inputSchema: z.object({ paths: z.array(z.string().min(1)).min(1).describe("Paths to back up"), destination: z.string().optional().describe("Destination dir (defaults to config)"), method: z.enum(["tar", "rsync"]).optional().default("tar"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const dest = (args.destination as string) ?? ctx.config.documentation.repo_path ?? "/var/backups";
    const ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const hostname = ctx.targetHost.replace(/[^a-zA-Z0-9-]/g, "_");
    let cmd: string;
    if ((args.method as string) === "rsync") {
      const destDir = `${dest}/${hostname}-${ts}`;
      cmd = `sudo mkdir -p '${destDir}' && sudo rsync -avz ${(args.paths as string[]).map(p=>`'${p}'`).join(" ")} '${destDir}/'`;
    } else {
      const archive = `${dest}/${hostname}-${ts}.tar.gz`;
      cmd = `sudo mkdir -p '${dest}' && sudo tar czf '${archive}' ${(args.paths as string[]).map(p=>`'${p}'`).join(" ")}`;
    }
    const gate = ctx.safetyGate.check({ toolName: "bak_create", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Backup ${(args.paths as string[]).join(", ")} to ${dest}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("bak_create", ctx.targetHost, 0, null, { would_run: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "slow");
    if (r.exitCode !== 0) return error("bak_create", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("bak_create", ctx.targetHost, r.durationMs, cmd, { destination: dest, method: args.method });
  });

  registerTool(ctx, { name: "bak_restore", description: "Restore from a backup. High risk.", module: "backup", riskLevel: "high", duration: "slow", inputSchema: z.object({ source: z.string().min(1).describe("Backup file/directory"), destination: z.string().optional().default("/").describe("Restore target"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const src = args.source as string;
    const dest = (args.destination as string) ?? "/";
    let cmd: string;
    if (src.endsWith(".tar.gz") || src.endsWith(".tgz")) cmd = `sudo tar xzf '${src}' -C '${dest}'`;
    else cmd = `sudo rsync -avz '${src}/' '${dest}/'`;
    const gate = ctx.safetyGate.check({ toolName: "bak_restore", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `Restore ${src} to ${dest}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) {
      const dryCmd = src.endsWith(".tar.gz") ? `tar tzf '${src}' | head -20` : `rsync -avzn '${src}/' '${dest}/'`;
      const r = await executeBash(ctx, dryCmd, "normal");
      return success("bak_restore", ctx.targetHost, r.durationMs, dryCmd, { preview: r.stdout.trim() }, { dry_run: true });
    }
    const r = await executeBash(ctx, cmd, "slow");
    if (r.exitCode !== 0) return error("bak_restore", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("bak_restore", ctx.targetHost, r.durationMs, cmd, { restored_from: src, restored_to: dest });
  });

  registerTool(ctx, { name: "bak_schedule", description: "Schedule a recurring backup via cron. Moderate risk.", module: "backup", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ paths: z.array(z.string()).min(1), destination: z.string().min(1), schedule: z.string().min(9).describe("Cron schedule"), retention_days: z.number().int().min(1).optional().default(30), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response.") }), annotations: { destructiveHint: false } }, async (args) => {
    const paths = (args.paths as string[]).join(" ");
    const dest = args.destination as string;
    const ret = (args.retention_days as number) ?? 30;
    const hostname = ctx.targetHost.replace(/[^a-zA-Z0-9-]/g, "_");
    const cronCmd = `tar czf ${dest}/${hostname}-$(date +\\%Y\\%m\\%d-\\%H\\%M\\%S).tar.gz ${paths} && find ${dest} -name '${hostname}-*.tar.gz' -mtime +${ret} -delete`;
    const entry = `${args.schedule} ${cronCmd}`;
    const cmd = `(crontab -l 2>/dev/null; echo '# linux-sysadmin backup'; echo '${entry}') | crontab -`;
    const gate = ctx.safetyGate.check({ toolName: "bak_schedule", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Schedule backup: ${args.schedule}`, confirmed: args.confirmed as boolean });
    if (gate) return gate;
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("bak_schedule", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("bak_schedule", ctx.targetHost, r.durationMs, cmd, { schedule: args.schedule, paths: args.paths, retention_days: ret });
  });

  registerTool(ctx, { name: "bak_verify", description: "Verify backup integrity.", module: "backup", riskLevel: "read-only", duration: "normal", inputSchema: z.object({ path: z.string().min(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    const p = args.path as string;
    let cmd: string;
    if (p.endsWith(".tar.gz") || p.endsWith(".tgz")) cmd = `tar tzf '${p}' > /dev/null && echo 'Archive OK: '$(tar tzf '${p}' | wc -l)' files' || echo 'Archive CORRUPT'`;
    else cmd = `ls -lR '${p}' | wc -l && echo 'files in backup directory'`;
    const r = await executeBash(ctx, cmd, "normal");
    return success("bak_verify", ctx.targetHost, r.durationMs, cmd, { output: r.stdout.trim(), path: p });
  });
}
