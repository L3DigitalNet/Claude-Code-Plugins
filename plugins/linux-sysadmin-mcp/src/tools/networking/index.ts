import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerNetworkingTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "net_interfaces", description: "List network interfaces and config.", module: "networking", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "ip -c addr show 2>/dev/null || ip addr show", "quick");
    return success("net_interfaces", ctx.targetHost, r.durationMs, "ip addr show", { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "net_connections", description: "Show active connections (like ss/netstat).", module: "networking", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ listening_only: z.boolean().optional().default(false) }), annotations: { readOnlyHint: true } }, async (args) => {
    const flags = args.listening_only ? "-tlnp" : "-tanp";
    const r = await executeBash(ctx, `sudo -n ss ${flags} 2>/dev/null || ss ${flags.replace("p","")}`, "quick");
    return success("net_connections", ctx.targetHost, r.durationMs, `ss ${flags}`, { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "net_dns_show", description: "Show DNS configuration.", module: "networking", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "cat /etc/resolv.conf && echo '---' && resolvectl status 2>/dev/null || systemd-resolve --status 2>/dev/null || echo 'systemd-resolved not active'", "quick");
    return success("net_dns_show", ctx.targetHost, r.durationMs, "resolv.conf + resolvectl", { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "net_routes_show", description: "Show routing table.", module: "networking", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "ip route show", "quick");
    return success("net_routes_show", ctx.targetHost, r.durationMs, "ip route show", { routes: r.stdout.trim() });
  });

  registerTool(ctx, { name: "net_test", description: "Connectivity tests: ping, traceroute, dig.", module: "networking", riskLevel: "read-only", duration: "normal", inputSchema: z.object({ target: z.string().min(1), test: z.enum(["ping", "traceroute", "dig", "all"]).optional().default("ping").describe("Test to run: 'ping' (ICMP reachability), 'traceroute' (path hops), 'dig' (DNS lookup), or 'all' (runs all three)") }), annotations: { readOnlyHint: true } }, async (args) => {
    const t = args.target as string;
    const test = (args.test as string) ?? "ping";
    const results: Record<string, string> = {};
    if (test === "ping" || test === "all") { const r = await executeBash(ctx, `ping -c 4 -W 3 ${t} 2>&1`, "normal"); results.ping = r.stdout.trim(); }
    if (test === "traceroute" || test === "all") { const r = await executeBash(ctx, `traceroute -m 15 ${t} 2>&1 || tracepath ${t} 2>&1`, "normal"); results.traceroute = r.stdout.trim(); }
    if (test === "dig" || test === "all") { const r = await executeBash(ctx, `dig ${t} +short 2>&1`, "quick"); results.dig = r.stdout.trim(); }
    return success("net_test", ctx.targetHost, 0, `connectivity test: ${test}`, results);
  });

  registerTool(ctx, { name: "net_dns_modify", description: "Modify DNS configuration. Moderate risk.", module: "networking", riskLevel: "moderate", duration: "normal", inputSchema: z.object({ nameservers: z.array(z.string()).min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const ns = (args.nameservers as string[]).map((s) => `nameserver ${s}`).join("\n");
    const cmd = `sudo cp /etc/resolv.conf /etc/resolv.conf.bak && echo '${ns}' | sudo tee /etc/resolv.conf`;
    const gate = ctx.safetyGate.check({ toolName: "net_dns_modify", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Set DNS servers: ${(args.nameservers as string[]).join(", ")}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("net_dns_modify", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("net_dns_modify", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("net_dns_modify", ctx.targetHost, r.durationMs, cmd, { nameservers: args.nameservers, backup: "/etc/resolv.conf.bak" });
  });

  registerTool(ctx, { name: "net_routes_modify", description: "Add/delete routing table entries. High risk.", module: "networking", riskLevel: "high", duration: "quick", inputSchema: z.object({ action: z.enum(["add", "delete"]), destination: z.string().min(1).describe("Route destination in CIDR notation or 'default' (e.g. '192.168.1.0/24')"), gateway: z.string().optional().describe("Next-hop gateway IP address (omit for interface-only routes)"), interface: z.string().optional().describe("Network interface to use (e.g. 'eth0', 'ens3')"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    let cmd = `sudo ip route ${args.action} ${args.destination}`;
    if (args.gateway) cmd += ` via ${args.gateway}`;
    if (args.interface) cmd += ` dev ${args.interface}`;
    const gate = ctx.safetyGate.check({ toolName: "net_routes_modify", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `${args.action} route ${args.destination}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("net_routes_modify", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("net_routes_modify", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("net_routes_modify", ctx.targetHost, r.durationMs, cmd, { action: args.action, destination: args.destination });
  });
}
