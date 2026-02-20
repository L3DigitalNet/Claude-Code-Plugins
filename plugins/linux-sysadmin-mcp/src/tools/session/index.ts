import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success } from "../helpers.js";

export function registerSessionTools(ctx: PluginContext): void {
  registerTool(ctx, {
    name: "sysadmin_session_info",
    description: "Full session context: target host, distro, sudo status, MAC system, detected knowledge profiles with resolved dependency roles, documentation repo status, integration mode. Call this first in every session.",
    module: "session",
    riskLevel: "read-only",
    duration: "instant",
    inputSchema: z.object({
      show_sudoers_reference: z.boolean().optional().default(false).describe("Include per-module sudoers fragments"),
    }),
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true },
  }, async (args) => {
    const profiles = ctx.knowledgeBase.resolved.map((r) => ({
      id: r.profile.id,
      name: r.profile.name,
      status: r.status,
      roles_resolved: r.rolesResolved,
      ...(r.unresolved_roles.length ? { unresolved_roles: r.unresolved_roles } : {}),
    }));

    // Build per-module tool count for capability discovery (B-013 fix)
    const toolsByModule: Record<string, number> = {};
    for (const [, tool] of ctx.registry.getAll()) {
      const mod = tool.metadata.module;
      toolsByModule[mod] = (toolsByModule[mod] ?? 0) + 1;
    }

    const data: Record<string, unknown> = {
      target_host: ctx.targetHost,
      distro: {
        family: ctx.distro.family,
        name: ctx.distro.name,
        version: ctx.distro.version,
        codename: ctx.distro.codename,
      },
      sudo_available: ctx.sudoAvailable,
      mac_system: { type: ctx.distro.mac_system, mode: ctx.distro.mac_mode },
      detected_profiles: profiles,
      // Profile parse failures — non-empty means a knowledge file has a syntax error
      profile_load_errors: ctx.knowledgeBase.loadErrors.length > 0 ? ctx.knowledgeBase.loadErrors : undefined,
      unresolved_roles: profiles.flatMap((p) => (p as Record<string, unknown>).unresolved_roles as string[] ?? []),
      documentation: ctx.config.documentation.repo_path
        ? { enabled: true, repo_path: ctx.config.documentation.repo_path }
        : { enabled: false, reason: "No documentation repo configured. Set documentation.repo_path in config.yaml." },
      // integration_mode is a behavioral hint to Claude — it signals intent for how this
      // server should coexist with other MCPs, but has no runtime enforcement effect.
      integration_mode: ctx.config.integration_mode,
      tools_registered: ctx.registry.size,
      tools_by_module: toolsByModule,
    };

    if (ctx.firstRun) {
      data.first_run = true;
      data.config_generated = ctx.configPath;
      data.setup_hints = [
        ...(ctx.sudoAvailable ? [] : ["Configure passwordless sudo for full functionality."]),
        `Configuration file at ${ctx.configPath} — customize as needed.`,
        ...(ctx.config.documentation.repo_path ? [] : ["Set documentation.repo_path in config.yaml to enable documentation."]),
      ];
    }

    if (!ctx.sudoAvailable) {
      data.degraded_mode = true;
      data.degraded_reason = "Passwordless sudo not configured. State-changing tools are disabled.";
    }

    return success("sysadmin_session_info", ctx.targetHost, 0, null, data);
  });
}
