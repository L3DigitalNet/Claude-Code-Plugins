import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash, executeCommand } from "../helpers.js";

export function registerUserTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "user_list", description: "List system users.", module: "users", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ include_system: z.boolean().optional().default(false) }), annotations: { readOnlyHint: true } }, async (args) => {
    const filter = args.include_system ? "" : "| awk -F: '$3 >= 1000 || $3 == 0 {print}'";
    const r = await executeBash(ctx, `getent passwd ${filter}`, "quick");
    const users = r.stdout.trim().split("\n").filter(Boolean).map((l) => { const [name,,uid,gid,comment,home,shell] = l.split(":"); return { name, uid: parseInt(uid??"0"), gid: parseInt(gid??"0"), comment, home, shell }; });
    return success("user_list", ctx.targetHost, r.durationMs, "getent passwd", { users, count: users.length });
  });

  registerTool(ctx, { name: "user_info", description: "Detailed info for a user.", module: "users", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ username: z.string().min(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    const u = args.username as string;
    const [idR, lastR] = await Promise.all([executeBash(ctx, `id ${u}`, "instant"), executeBash(ctx, `lastlog -u ${u} 2>/dev/null || echo 'N/A'`, "instant")]);
    if (idR.exitCode !== 0) return error("user_info", ctx.targetHost, idR.durationMs, { code: "USER_NOT_FOUND", category: "not_found", message: `User '${u}' not found` });
    return success("user_info", ctx.targetHost, idR.durationMs, "id + lastlog", { identity: idR.stdout.trim(), last_login: lastR.stdout.trim() });
  });

  registerTool(ctx, { name: "user_create", description: "Create a user account. Moderate risk.", module: "users", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ username: z.string().min(1).max(32), shell: z.string().optional().describe("Login shell path (e.g. '/bin/bash'; omit for system default)"), home: z.string().optional().describe("Home directory path (omit to use system default)"), groups: z.array(z.string()).optional().describe("Additional groups to add the user to"), system: z.boolean().optional().default(false).describe("Create as a system account (no home dir, UID below 1000)"), comment: z.string().optional().describe("GECOS/display name for the account"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = ctx.commands.userCreate({ username: args.username as string, shell: args.shell as string|undefined, home: args.home as string|undefined, groups: args.groups as string[]|undefined, system: args.system as boolean, comment: args.comment as string|undefined });
    const gate = ctx.safetyGate.check({ toolName: "user_create", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: `Create user ${args.username}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("user_create", ctx.targetHost, null, null, { preview_command: cmd.argv.join(" ") }, { dry_run: true });
    const r = await executeCommand(ctx, "user_create", cmd, "quick");
    if (r.exitCode !== 0) return error("user_create", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "user_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("user_create", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { created: args.username }, docHint);
  });

  registerTool(ctx, { name: "user_modify", description: "Modify user properties. Moderate risk.", module: "users", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ username: z.string().min(1), shell: z.string().optional(), groups: z.array(z.string()).optional(), append_groups: z.boolean().optional().default(true), lock: z.boolean().optional(), unlock: z.boolean().optional(), comment: z.string().optional(), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = ctx.commands.userModify(args.username as string, { shell: args.shell as string|undefined, groups: args.groups as string[]|undefined, append_groups: args.append_groups as boolean|undefined, lock: args.lock as boolean|undefined, unlock: args.unlock as boolean|undefined, comment: args.comment as string|undefined });
    const gate = ctx.safetyGate.check({ toolName: "user_modify", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: `Modify user ${args.username}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("user_modify", ctx.targetHost, null, null, { preview_command: cmd.argv.join(" ") }, { dry_run: true });
    const r = await executeCommand(ctx, "user_modify", cmd, "quick");
    if (r.exitCode !== 0) return error("user_modify", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("user_modify", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { modified: args.username });
  });

  registerTool(ctx, { name: "user_delete", description: "Delete a user. Critical risk.", module: "users", riskLevel: "critical", duration: "quick", inputSchema: z.object({ username: z.string().min(1), remove_home: z.boolean().optional().default(false), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = ctx.commands.userDelete(args.username as string, { removeHome: args.remove_home as boolean });
    const gate = ctx.safetyGate.check({ toolName: "user_delete", toolRiskLevel: "critical", targetHost: ctx.targetHost, command: cmd.argv.join(" "), description: `Delete user ${args.username}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("user_delete", ctx.targetHost, null, null, { preview_command: cmd.argv.join(" ") }, { dry_run: true });
    const r = await executeCommand(ctx, "user_delete", cmd, "quick");
    if (r.exitCode !== 0) return error("user_delete", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "user_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("user_delete", ctx.targetHost, r.durationMs, cmd.argv.join(" "), { deleted: args.username }, docHint);
  });

  registerTool(ctx, { name: "group_list", description: "List groups and members.", module: "users", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ filter: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const r = await executeBash(ctx, `getent group ${args.filter ? `| grep -i '${args.filter}'` : ""}`, "quick");
    const groups = r.stdout.trim().split("\n").filter(Boolean).map((l) => { const [name,,gid,members] = l.split(":"); return { name, gid: parseInt(gid??"0"), members: members?.split(",").filter(Boolean) ?? [] }; });
    return success("group_list", ctx.targetHost, r.durationMs, "getent group", { groups, count: groups.length });
  });

  registerTool(ctx, { name: "group_create", description: "Create a group. Moderate risk.", module: "users", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ name: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const gate = ctx.safetyGate.check({ toolName: "group_create", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: `sudo groupadd ${args.name}`, description: `Create group ${args.name}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("group_create", ctx.targetHost, null, null, { preview_command: `sudo groupadd ${args.name}` }, { dry_run: true });
    const r = await executeBash(ctx, `sudo groupadd ${args.name}`, "quick");
    if (r.exitCode !== 0) return error("group_create", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "user_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("group_create", ctx.targetHost, r.durationMs, `sudo groupadd ${args.name}`, { created: args.name }, docHint);
  });

  registerTool(ctx, { name: "group_delete", description: "Delete a group. High risk.", module: "users", riskLevel: "high", duration: "quick", inputSchema: z.object({ name: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const gate = ctx.safetyGate.check({ toolName: "group_delete", toolRiskLevel: "high", targetHost: ctx.targetHost, command: `sudo groupdel ${args.name}`, description: `Delete group ${args.name}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("group_delete", ctx.targetHost, null, null, { preview_command: `sudo groupdel ${args.name}` }, { dry_run: true });
    const r = await executeBash(ctx, `sudo groupdel ${args.name}`, "quick");
    if (r.exitCode !== 0) return error("group_delete", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "user_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("group_delete", ctx.targetHost, r.durationMs, `sudo groupdel ${args.name}`, { deleted: args.name }, docHint);
  });

  registerTool(ctx, { name: "perms_check", description: "Check file/directory permissions.", module: "users", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ path: z.string().min(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    const r = await executeBash(ctx, `stat -c '%A %U:%G %s %n' '${args.path}' && ls -la '${args.path}' 2>/dev/null | head -20`, "quick");
    // Parse stat output (first line: "mode owner:group size name") and ls -la entries.
    const [statLine, ...lsLines] = r.stdout.trim().split("\n");
    const result: Record<string, unknown> = { path: args.path };
    const statParts = (statLine ?? "").split(" ");
    if (statParts.length >= 3) {
      result.mode = statParts[0];
      const [owner, group] = (statParts[1] ?? "").split(":");
      result.owner = owner;
      result.group = group;
      result.size_bytes = parseInt(statParts[2] ?? "0");
    }
    const entries = lsLines
      .filter((l) => l.match(/^[dlrwx-]/))
      .map((l) => { const p = l.split(/\s+/); return { mode: p[0], owner: p[2], group: p[3], size: p[4], name: p[p.length - 1] }; });
    if (entries.length) result.entries = entries;
    return success("perms_check", ctx.targetHost, r.durationMs, "stat+ls", result);
  });

  registerTool(ctx, { name: "perms_set", description: "Set permissions/ownership. Moderate risk.", module: "users", riskLevel: "moderate", duration: "quick", inputSchema: z.object({ path: z.string().min(1), mode: z.string().optional().describe("Permission mode in octal or symbolic notation (e.g. '755', '644', 'u+x')"), owner: z.string().optional().describe("Owner in user[:group] format (e.g. 'www-data', 'deploy:www-data')"), recursive: z.boolean().optional().default(false), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmds: string[] = []; const rec = args.recursive ? "-R " : "";
    if (args.mode) cmds.push(`sudo chmod ${rec}${args.mode} '${args.path}'`);
    if (args.owner) cmds.push(`sudo chown ${rec}${args.owner} '${args.path}'`);
    if (!cmds.length) return error("perms_set", ctx.targetHost, null, { code: "VALIDATION_ERROR", category: "validation", message: "Specify mode or owner" });
    const cmd = cmds.join(" && ");
    const gate = ctx.safetyGate.check({ toolName: "perms_set", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Set perms on ${args.path}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("perms_set", ctx.targetHost, null, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "quick");
    if (r.exitCode !== 0) return error("perms_set", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "permissions_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("perms_set", ctx.targetHost, r.durationMs, cmd, { path: args.path }, docHint);
  });
}
