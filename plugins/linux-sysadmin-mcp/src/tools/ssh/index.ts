import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerSSHTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "ssh_session_info", description: "SSH transport diagnostics: current target, connection status.", module: "ssh", riskLevel: "read-only", duration: "instant", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    return success("ssh_session_info", ctx.targetHost, 0, null, { target_host: ctx.targetHost, is_remote: ctx.isRemote, connection_status: ctx.isRemote ? "connected" : "local" });
  });

  registerTool(ctx, { name: "ssh_config_list", description: "List SSH client config entries from ~/.ssh/config.", module: "ssh", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "cat ~/.ssh/config 2>/dev/null || echo 'No SSH config found'", "quick");
    return success("ssh_config_list", ctx.targetHost, r.durationMs, "cat ~/.ssh/config", { config: r.stdout.trim() });
  });

  registerTool(ctx, { name: "ssh_key_list", description: "List SSH keys on the local system.", module: "ssh", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "ls -la ~/.ssh/*.pub 2>/dev/null && echo '---' && ssh-add -l 2>/dev/null || echo 'No SSH agent or keys found'", "quick");
    return success("ssh_key_list", ctx.targetHost, r.durationMs, "ls ~/.ssh/*.pub + ssh-add -l", { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "ssh_test_connection", description: "Test SSH connectivity to a host without connecting.", module: "ssh", riskLevel: "read-only", duration: "normal", inputSchema: z.object({ host: z.string().min(1), port: z.number().int().optional().default(22), user: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const user = args.user ? `${args.user}@` : "";
    const r = await executeBash(ctx, `ssh -o ConnectTimeout=5 -o BatchMode=yes -p ${(args.port as number) ?? 22} ${user}${args.host} 'echo OK' 2>&1`, "normal");
    const connected = r.stdout.includes("OK");
    return success("ssh_test_connection", ctx.targetHost, r.durationMs, `ssh ${user}${args.host}`, { host: args.host, reachable: connected, output: (r.stdout + r.stderr).trim() });
  });

  registerTool(ctx, { name: "ssh_key_generate", description: "Generate a new SSH key pair. Low risk.", module: "ssh", riskLevel: "low", duration: "quick", inputSchema: z.object({ type: z.enum(["ed25519", "rsa"]).optional().default("ed25519"), comment: z.string().optional(), filename: z.string().optional() }), annotations: { destructiveHint: false } }, async (args) => {
    const keyType = (args.type as string) ?? "ed25519";
    const fname = (args.filename as string) ?? `~/.ssh/id_${keyType}`;
    const commentArg = args.comment ? `-C '${args.comment}'` : "";
    const r = await executeBash(ctx, `ssh-keygen -t ${keyType} -f ${fname} -N '' ${commentArg} 2>&1`, "quick");
    if (r.exitCode !== 0) return error("ssh_key_generate", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: (r.stderr.trim() || r.stdout.trim()) || "ssh-keygen failed" });
    return success("ssh_key_generate", ctx.targetHost, r.durationMs, `ssh-keygen -t ${keyType}`, { generated: fname, type: keyType });
  });

  registerTool(ctx, { name: "ssh_authorized_keys", description: "View authorized_keys on the active target.", module: "ssh", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ user: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const u = args.user ? `/home/${args.user}` : "~";
    const r = await executeBash(ctx, `cat ${u}/.ssh/authorized_keys 2>/dev/null || echo 'No authorized_keys found'`, "quick");
    return success("ssh_authorized_keys", ctx.targetHost, r.durationMs, "cat authorized_keys", { keys: r.stdout.trim() });
  });
}
