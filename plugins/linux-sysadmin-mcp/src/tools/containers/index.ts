import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

function rt(ctx: PluginContext): string { return ctx.distro.container_runtime === "none" ? "docker" : ctx.distro.container_runtime; }

export function registerContainerTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "ctr_list", description: "List containers (running and stopped).", module: "containers", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ all: z.boolean().optional().default(true) }), annotations: { readOnlyHint: true } }, async (args) => {
    const r = await executeBash(ctx, `${rt(ctx)} ps ${args.all ? "-a" : ""} --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'`, "quick");
    return success("ctr_list", ctx.targetHost, r.durationMs, `${rt(ctx)} ps`, { output: r.stdout.trim(), runtime: rt(ctx) });
  });

  registerTool(ctx, { name: "ctr_images", description: "List container images.", module: "containers", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, `${rt(ctx)} images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}'`, "quick");
    return success("ctr_images", ctx.targetHost, r.durationMs, `${rt(ctx)} images`, { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "ctr_inspect", description: "Inspect container configuration.", module: "containers", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ container: z.string().min(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    const r = await executeBash(ctx, `${rt(ctx)} inspect ${args.container}`, "quick");
    return success("ctr_inspect", ctx.targetHost, r.durationMs, `${rt(ctx)} inspect`, { inspect: r.stdout.trim() });
  });

  registerTool(ctx, { name: "ctr_logs", description: "Retrieve container logs.", module: "containers", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ container: z.string().min(1), tail: z.number().int().optional().default(100), since: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    let cmd = `${rt(ctx)} logs --tail ${(args.tail as number) ?? 100}`;
    if (args.since) cmd += ` --since '${args.since}'`;
    cmd += ` ${args.container}`;
    const r = await executeBash(ctx, cmd, "quick");
    return success("ctr_logs", ctx.targetHost, r.durationMs, cmd, { logs: r.stdout.trim() + (r.stderr ? "\n" + r.stderr.trim() : "") });
  });

  for (const action of ["start", "stop", "restart"] as const) {
    registerTool(ctx, { name: `ctr_${action}`, description: `${action.charAt(0).toUpperCase() + action.slice(1)} a container. Moderate risk.`, module: "containers", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ container: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: action === "stop" } }, async (args) => {
      const cmd = `${rt(ctx)} ${action} ${args.container}`;
      const gate = ctx.safetyGate.check({ toolName: `ctr_${action}`, toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `${action} container ${args.container}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
      if (gate) return gate;
      if (args.dry_run) return success(`ctr_${action}`, ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
      const r = await executeBash(ctx, cmd, "quick");
      if (r.exitCode !== 0) return error(`ctr_${action}`, ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
      return success(`ctr_${action}`, ctx.targetHost, r.durationMs, cmd, { container: args.container, action });
    });
  }

  registerTool(ctx, { name: "ctr_remove", description: "Remove a container. High risk.", module: "containers", riskLevel: "high", duration: "quick", inputSchema: z.object({ container: z.string().min(1), force: z.boolean().optional().default(false), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = `${rt(ctx)} rm ${args.force ? "-f" : ""} ${args.container}`;
    const gate = ctx.safetyGate.check({ toolName: "ctr_remove", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `Remove container ${args.container}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("ctr_remove", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("ctr_remove", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("ctr_remove", ctx.targetHost, r.durationMs, cmd, { removed: args.container });
  });

  registerTool(ctx, { name: "ctr_image_pull", description: "Pull a container image. Moderate risk.", module: "containers", riskLevel: "moderate", duration: "slow", inputSchema: z.object({ image: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = `${rt(ctx)} pull ${args.image}`;
    const gate = ctx.safetyGate.check({ toolName: "ctr_image_pull", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Pull image ${args.image}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("ctr_image_pull", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "slow");
    if (r.exitCode !== 0) return error("ctr_image_pull", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("ctr_image_pull", ctx.targetHost, r.durationMs, cmd, { pulled: args.image });
  });

  registerTool(ctx, { name: "ctr_image_remove", description: "Remove a container image. High risk.", module: "containers", riskLevel: "high", duration: "quick", inputSchema: z.object({ image: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = `${rt(ctx)} rmi ${args.image}`;
    const gate = ctx.safetyGate.check({ toolName: "ctr_image_remove", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `Remove image ${args.image}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("ctr_image_remove", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("ctr_image_remove", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("ctr_image_remove", ctx.targetHost, r.durationMs, cmd, { removed: args.image });
  });

  registerTool(ctx, { name: "ctr_compose_status", description: "Show Compose project status.", module: "containers", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ project_dir: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const dir = args.project_dir ? `-f ${args.project_dir}/docker-compose.yml` : "";
    const r = await executeBash(ctx, `${rt(ctx)} compose ${dir} ps 2>/dev/null || docker-compose ${dir} ps 2>/dev/null || echo 'Compose not available'`, "quick");
    return success("ctr_compose_status", ctx.targetHost, r.durationMs, "compose ps", { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "ctr_compose_up", description: "Start a Compose project. Moderate risk.", module: "containers", riskLevel: "moderate", duration: "slow", inputSchema: z.object({ project_dir: z.string().min(1), detach: z.boolean().optional().default(true), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = `cd '${args.project_dir}' && ${rt(ctx)} compose up ${args.detach ? "-d" : ""}`;
    const gate = ctx.safetyGate.check({ toolName: "ctr_compose_up", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Start compose project in ${args.project_dir}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("ctr_compose_up", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "slow");
    if (r.exitCode !== 0) return error("ctr_compose_up", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("ctr_compose_up", ctx.targetHost, r.durationMs, cmd, { started: true });
  });

  registerTool(ctx, { name: "ctr_compose_down", description: "Stop and remove a Compose project. High risk.", module: "containers", riskLevel: "high", duration: "normal", inputSchema: z.object({ project_dir: z.string().min(1), volumes: z.boolean().optional().default(false).describe("Remove named volumes declared in the compose file. WARNING: permanently deletes all volume data — use dry_run: true first."), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = `cd '${args.project_dir}' && ${rt(ctx)} compose down ${args.volumes ? "-v" : ""}`;
    const gate = ctx.safetyGate.check({ toolName: "ctr_compose_down", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `Stop compose project in ${args.project_dir}${args.volumes ? " (with volume removal)" : ""}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("ctr_compose_down", ctx.targetHost, 0, null, { preview_command: cmd, volumes_would_be_deleted: args.volumes === true }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("ctr_compose_down", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("ctr_compose_down", ctx.targetHost, r.durationMs, cmd, { stopped: true });
  });
}
