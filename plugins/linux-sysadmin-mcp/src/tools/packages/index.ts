import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeCommand, categorizeError, buildCategorizedResponse } from "../helpers.js";

export function registerPackageTools(ctx: PluginContext): void {
  // ── pkg_list_installed ──────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_list_installed", description: "List installed packages, optionally filtered by name.",
    module: "packages", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({
      filter: z.string().optional().describe("Filter packages by name substring"),
      limit: z.number().int().min(1).max(500).optional().default(50),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const cmd = ctx.commands.packageListInstalled(args.filter as string | undefined);
    const r = await executeCommand(ctx, "pkg_list_installed", cmd, "quick");
    if (r.exitCode !== 0 && !r.stdout) return error("pkg_list_installed", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr });
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const limit = (args.limit as number) ?? 50;
    const packages = lines.slice(0, limit).map((l) => {
      const [name, version, arch] = l.split("\t");
      return { name: name?.trim(), version: version?.trim(), arch: arch?.trim() };
    });
    return success("pkg_list_installed", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { packages }, {
      total: lines.length, returned: packages.length, truncated: lines.length > limit, filter: (args.filter as string) ?? null,
    });
  });

  // ── pkg_search ──────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_search", description: "Search available packages by name/keyword.",
    module: "packages", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({ query: z.string().min(1).describe("Search query"), limit: z.number().int().min(1).max(100).optional().default(20) }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const cmd = ctx.commands.packageSearch(args.query as string);
    const r = await executeCommand(ctx, "pkg_search", cmd, "normal");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const limit = (args.limit as number) ?? 20;
    return success("pkg_search", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { results: lines.slice(0, limit) }, {
      total: lines.length, returned: Math.min(lines.length, limit), truncated: lines.length > limit,
    });
  });

  // ── pkg_info ────────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_info", description: "Show detailed info for a specific package.",
    module: "packages", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({ package: z.string().min(1).describe("Package name") }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const cmd = ctx.commands.packageInfo(args.package as string);
    const r = await executeCommand(ctx, "pkg_info", cmd, "quick");
    if (r.exitCode !== 0) return error("pkg_info", ctx.targetHost, r.durationMs, { ...categorizeError(r.stderr, ctx), message: r.stderr.trim() || `Package '${args.package}' not found` });
    return success("pkg_info", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { info: r.stdout.trim() });
  });

  // ── pkg_install ─────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_install", description: "Install one or more packages. Moderate risk — requires confirmation.",
    module: "packages", riskLevel: "moderate", duration: "slow",
    inputSchema: z.object({
      packages: z.array(z.string().min(1)).min(1).describe("Package names to install"),
      confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes."),
    }),
    annotations: { readOnlyHint: false, destructiveHint: false },
  }, async (args) => {
    const pkgs = args.packages as string[];
    const cmd = ctx.commands.packageInstall(pkgs, { dryRun: args.dry_run as boolean });
    const gate = ctx.safetyGate.check({
      toolName: "pkg_install", toolRiskLevel: "moderate", targetHost: ctx.targetHost,
      command: cmd.argv.join(" "), description: `Install packages: ${pkgs.join(", ")}`,
      confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
    });
    if (gate) return gate;
    const r = await executeCommand(ctx, "pkg_install", cmd, "slow");
    if (r.exitCode !== 0) return buildCategorizedResponse("pkg_install", ctx.targetHost, r.durationMs, r.stderr, ctx);
    return success("pkg_install", ctx.targetHost, r.durationMs, cmd.argv.join(" "),
      { packages_installed: pkgs, output: r.stdout.trim() },
      args.dry_run ? { dry_run: true } : undefined,
    );
  });

  // ── pkg_remove ──────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_remove", description: "Remove a package (preserve config files). High risk.",
    module: "packages", riskLevel: "high", duration: "normal",
    inputSchema: z.object({
      packages: z.array(z.string().min(1)).min(1).describe("Package names to remove or purge"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes."),
    }),
    annotations: { destructiveHint: true },
  }, async (args) => {
    const pkgs = args.packages as string[];
    const cmd = ctx.commands.packageRemove(pkgs, { dryRun: args.dry_run as boolean });
    const gate = ctx.safetyGate.check({
      toolName: "pkg_remove", toolRiskLevel: "high", targetHost: ctx.targetHost,
      command: cmd.argv.join(" "), description: `Remove packages: ${pkgs.join(", ")}`,
      confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
    });
    if (gate) return gate;
    const r = await executeCommand(ctx, "pkg_remove", cmd, "normal");
    if (r.exitCode !== 0) return buildCategorizedResponse("pkg_remove", ctx.targetHost, r.durationMs, r.stderr, ctx);
    return success("pkg_remove", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { packages_removed: pkgs, output: r.stdout.trim() }, args.dry_run ? { dry_run: true } : undefined);
  });

  // ── pkg_purge ───────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_purge", description: "Remove a package AND its config files. Critical risk.",
    module: "packages", riskLevel: "critical", duration: "normal",
    inputSchema: z.object({
      packages: z.array(z.string().min(1)).min(1).describe("Package names to remove or purge"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes."),
    }),
    annotations: { destructiveHint: true },
  }, async (args) => {
    const pkgs = args.packages as string[];
    const cmd = ctx.commands.packageRemove(pkgs, { purge: true, dryRun: args.dry_run as boolean });
    const gate = ctx.safetyGate.check({
      toolName: "pkg_purge", toolRiskLevel: "critical", targetHost: ctx.targetHost,
      command: cmd.argv.join(" "), description: `Purge packages and configs: ${pkgs.join(", ")}`,
      confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
    });
    if (gate) return gate;
    const r = await executeCommand(ctx, "pkg_purge", cmd, "normal");
    if (r.exitCode !== 0) return buildCategorizedResponse("pkg_purge", ctx.targetHost, r.durationMs, r.stderr, ctx);
    return success("pkg_purge", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { packages_purged: pkgs, output: r.stdout.trim() }, args.dry_run ? { dry_run: true } : undefined);
  });

  // ── pkg_update ──────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_update", description: "Update specific packages or all packages. Moderate risk.",
    module: "packages", riskLevel: "moderate", duration: "slow",
    inputSchema: z.object({
      packages: z.array(z.string()).optional().describe("Specific packages to update. Omit to upgrade ALL installed packages on the system."),
      confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes."),
    }),
    annotations: { destructiveHint: false },
  }, async (args) => {
    const pkgs = (args.packages as string[] | undefined) ?? undefined;
    const cmd = ctx.commands.packageUpdate(pkgs, { dryRun: args.dry_run as boolean });
    const gate = ctx.safetyGate.check({
      toolName: "pkg_update", toolRiskLevel: "moderate", targetHost: ctx.targetHost,
      command: cmd.argv.join(" "), description: pkgs?.length ? `Update packages: ${pkgs.join(", ")}` : "Update all packages",
      confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
    });
    if (gate) return gate;
    const r = await executeCommand(ctx, "pkg_update", cmd, "slow");
    if (r.exitCode !== 0) return buildCategorizedResponse("pkg_update", ctx.targetHost, r.durationMs, r.stderr, ctx);
    return success("pkg_update", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { output: r.stdout.trim() }, args.dry_run ? { dry_run: true } : undefined);
  });

  // ── pkg_check_updates ───────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_check_updates", description: "List available updates without applying them.",
    module: "packages", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({}),
    annotations: { readOnlyHint: true },
  }, async () => {
    const cmd = ctx.commands.packageCheckUpdates();
    const r = await executeCommand(ctx, "pkg_check_updates", cmd, "normal");
    // dnf check-update returns exit code 100 when updates available
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    return success("pkg_check_updates", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { updates: lines, count: lines.length });
  });

  // ── pkg_history ─────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_history", description: "Show package transaction history.",
    module: "packages", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({ limit: z.number().int().min(1).max(200).optional().default(50) }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const cmd = ctx.commands.packageHistory();
    const r = await executeCommand(ctx, "pkg_history", cmd, "quick");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const limit = (args.limit as number) ?? 50;
    return success("pkg_history", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { history: lines.slice(0, limit) }, {
      total: lines.length, returned: Math.min(lines.length, limit), truncated: lines.length > limit,
    });
  });

  // ── pkg_rollback ────────────────────────────────────────────────
  registerTool(ctx, {
    name: "pkg_rollback", description: "Roll back to a previous package version. High risk.",
    module: "packages", riskLevel: "high", duration: "slow",
    inputSchema: z.object({
      package: z.string().min(1).describe("Package name to roll back"), version: z.string().optional().describe("Target version (omit for previous)"),
      confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes."),
    }),
    annotations: { destructiveHint: true },
  }, async (args) => {
    const pkg = args.package as string;
    const ver = args.version as string | undefined;
    // Build rollback command per Section 6.1
    const cmdStr = ctx.distro.family === "debian"
      ? ver ? `sudo apt install -y ${pkg}=${ver}` : `sudo apt install -y ${pkg}-`
      : ver ? `sudo dnf downgrade -y ${pkg}-${ver}` : `sudo dnf history undo -y last`;
    const gate = ctx.safetyGate.check({
      toolName: "pkg_rollback", toolRiskLevel: "high", targetHost: ctx.targetHost,
      command: cmdStr, description: `Rollback ${pkg}${ver ? ` to ${ver}` : " to previous version"}`,
      confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
    });
    if (gate) return gate;
    const r = await ctx.executor.execute({ argv: ["bash", "-c", cmdStr] }, 60_000);
    if (r.exitCode !== 0) return buildCategorizedResponse("pkg_rollback", ctx.targetHost, r.durationMs, r.stderr, ctx);
    return success("pkg_rollback", ctx.targetHost, r.durationMs, cmdStr, { output: r.stdout.trim() });
  });
}
