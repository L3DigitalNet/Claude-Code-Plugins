import { z } from "zod";
import type { PluginContext } from "../context.js";
import type { FirewallRule } from "../../types/firewall.js";
import { registerTool, success, error, executeCommand, executeBash } from "../helpers.js";

const ruleSchema = z.object({
  action: z.enum(["allow", "deny", "reject"]), direction: z.enum(["in", "out"]),
  port: z.union([z.number(), z.string()]), protocol: z.enum(["tcp", "udp", "any"]).optional().default("any"),
  source: z.string().optional(), destination: z.string().optional(), comment: z.string().optional(),
});

export function registerFirewallTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "fw_status", description: "Show firewall status and active rules.", module: "firewall", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const cmd = ctx.commands.firewallStatus();
    const r = await executeCommand(ctx, "fw_status", cmd, "quick");
    return success("fw_status", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { output: r.stdout.trim(), backend: ctx.distro.firewall_backend });
  });

  registerTool(ctx, { name: "fw_list_rules", description: "List all firewall rules in detail.", module: "firewall", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const cmd = ctx.commands.firewallListRules();
    const r = await executeCommand(ctx, "fw_list_rules", cmd, "quick");
    return success("fw_list_rules", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { rules: r.stdout.trim(), backend: ctx.distro.firewall_backend });
  });

  registerTool(ctx, { name: "fw_add_rule", description: "Add a firewall rule. High risk.", module: "firewall", riskLevel: "high", duration: "quick", inputSchema: ruleSchema.extend({ confirmed: z.boolean().optional().default(false), dry_run: z.boolean().optional().default(false) }), annotations: { destructiveHint: false } }, async (args) => {
    const rule: FirewallRule = { action: args.action as "allow"|"deny"|"reject", direction: args.direction as "in"|"out", port: args.port as number|string, protocol: args.protocol as "tcp"|"udp"|"any"|undefined, source: args.source as string|undefined, destination: args.destination as string|undefined, comment: args.comment as string|undefined };
    const cmd = ctx.commands.firewallAddRule(rule, { dryRun: args.dry_run as boolean });
    const gate = ctx.safetyGate.check({ toolName: "fw_add_rule", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: `Add firewall rule: ${rule.action} ${rule.direction} port ${rule.port}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    const r = await executeCommand(ctx, "fw_add_rule", cmd, "quick");
    if (r.exitCode !== 0) return error("fw_add_rule", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("fw_add_rule", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { added: rule }, args.dry_run ? { dry_run: true } : undefined);
  });

  registerTool(ctx, { name: "fw_remove_rule", description: "Remove a firewall rule. High risk.", module: "firewall", riskLevel: "high", duration: "quick", inputSchema: ruleSchema.extend({ confirmed: z.boolean().optional().default(false) }), annotations: { destructiveHint: true } }, async (args) => {
    const rule: FirewallRule = { action: args.action as "allow"|"deny"|"reject", direction: args.direction as "in"|"out", port: args.port as number|string, protocol: args.protocol as "tcp"|"udp"|"any"|undefined, source: args.source as string|undefined };
    const cmd = ctx.commands.firewallRemoveRule(rule);
    const gate = ctx.safetyGate.check({ toolName: "fw_remove_rule", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: `Remove firewall rule: port ${rule.port}`, confirmed: args.confirmed as boolean });
    if (gate) return gate;
    const r = await executeCommand(ctx, "fw_remove_rule", cmd, "quick");
    if (r.exitCode !== 0) return error("fw_remove_rule", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("fw_remove_rule", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { removed: rule });
  });

  registerTool(ctx, { name: "fw_enable", description: "Enable the firewall. Critical risk.", module: "firewall", riskLevel: "critical", duration: "quick", inputSchema: z.object({ confirmed: z.boolean().optional().default(false) }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = ctx.commands.firewallEnable();
    const gate = ctx.safetyGate.check({ toolName: "fw_enable", toolRiskLevel: "critical", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: "Enable firewall", confirmed: args.confirmed as boolean });
    if (gate) return gate;
    const r = await executeCommand(ctx, "fw_enable", cmd, "quick");
    if (r.exitCode !== 0) return error("fw_enable", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("fw_enable", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { enabled: true });
  });

  registerTool(ctx, { name: "fw_disable", description: "Disable the firewall. Critical risk.", module: "firewall", riskLevel: "critical", duration: "quick", inputSchema: z.object({ confirmed: z.boolean().optional().default(false) }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = ctx.commands.firewallDisable();
    const gate = ctx.safetyGate.check({ toolName: "fw_disable", toolRiskLevel: "critical", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: "Disable firewall", confirmed: args.confirmed as boolean });
    if (gate) return gate;
    const r = await executeCommand(ctx, "fw_disable", cmd, "quick");
    if (r.exitCode !== 0) return error("fw_disable", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("fw_disable", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { disabled: true });
  });
}
