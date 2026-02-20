import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerStorageTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "disk_usage", description: "Show disk usage by filesystem.", module: "storage", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ path: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const cmd = args.path ? `df -h '${args.path}'` : "df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null || df -h";
    const r = await executeBash(ctx, cmd, "quick");
    return success("disk_usage", ctx.targetHost, r.durationMs, cmd, { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "disk_usage_top", description: "Find largest directories under a path.", module: "storage", riskLevel: "read-only", duration: "normal", inputSchema: z.object({ path: z.string().optional().default("/"), limit: z.number().int().min(1).max(50).optional().default(20), depth: z.number().int().min(1).max(5).optional().default(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    const r = await executeBash(ctx, `sudo -n du -h --max-depth=${(args.depth as number) ?? 1} '${(args.path as string) ?? "/"}' 2>/dev/null | sort -rh | head -n ${(args.limit as number) ?? 20}`, "normal");
    return success("disk_usage_top", ctx.targetHost, r.durationMs, "du + sort", { entries: r.stdout.trim() });
  });

  registerTool(ctx, { name: "mount_list", description: "List all mounted filesystems.", module: "storage", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS --noheadings 2>/dev/null || mount", "quick");
    return success("mount_list", ctx.targetHost, r.durationMs, "findmnt", { mounts: r.stdout.trim() });
  });

  registerTool(ctx, { name: "mount_add", description: "Add fstab entry and mount. Moderate risk.", module: "storage", riskLevel: "moderate", duration: "normal", inputSchema: z.object({ device: z.string().min(1), mount_point: z.string().min(1), fs_type: z.string().min(1), options: z.string().optional().default("defaults"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const line = `${args.device} ${args.mount_point} ${args.fs_type} ${(args.options as string) || "defaults"} 0 2`;
    const cmd = `sudo mkdir -p '${args.mount_point}' && echo '${line}' | sudo tee -a /etc/fstab && sudo mount '${args.mount_point}'`;
    const gate = ctx.safetyGate.check({ toolName: "mount_add", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Add fstab: ${line}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("mount_add", ctx.targetHost, 0, null, { would_add: line }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("mount_add", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("mount_add", ctx.targetHost, r.durationMs, cmd, { fstab_entry: line, mounted: true });
  });

  registerTool(ctx, { name: "mount_remove", description: "Unmount and remove fstab entry. High risk.", module: "storage", riskLevel: "high", duration: "normal", inputSchema: z.object({ mount_point: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const mp = args.mount_point as string;
    const gate = ctx.safetyGate.check({ toolName: "mount_remove", toolRiskLevel: "high", targetHost: ctx.targetHost, command: `umount ${mp}`, description: `Unmount ${mp} and remove from fstab`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("mount_remove", ctx.targetHost, 0, null, { would_run: `sudo umount '${mp}' && sudo sed -i '\\|${mp}|d' /etc/fstab` }, { dry_run: true });
    const r = await executeBash(ctx, `sudo umount '${mp}' && sudo sed -i '\\|${mp}|d' /etc/fstab`, "normal");
    if (r.exitCode !== 0) return error("mount_remove", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("mount_remove", ctx.targetHost, r.durationMs, "umount + sed", { unmounted: mp });
  });

  registerTool(ctx, { name: "lvm_status", description: "Show LVM PVs, VGs, and LVs.", module: "storage", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "sudo -n pvs 2>/dev/null && echo '---VGS---' && sudo -n vgs 2>/dev/null && echo '---LVS---' && sudo -n lvs 2>/dev/null || echo 'LVM not available'", "quick");
    return success("lvm_status", ctx.targetHost, r.durationMs, "pvs+vgs+lvs", { output: r.stdout.trim() });
  });

  registerTool(ctx, { name: "lvm_create_lv", description: "Create a logical volume. Moderate risk.", module: "storage", riskLevel: "moderate", duration: "normal", inputSchema: z.object({ name: z.string().min(1).describe("Name for the new logical volume"), vg: z.string().min(1).describe("Volume group name to create the LV in"), size: z.string().min(1).describe("Size with unit suffix (e.g. '10G', '500M')"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = `sudo lvcreate -L ${args.size} -n ${args.name} ${args.vg}`;
    const gate = ctx.safetyGate.check({ toolName: "lvm_create_lv", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Create LV ${args.name} (${args.size}) in VG ${args.vg}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("lvm_create_lv", ctx.targetHost, 0, null, { would_run: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("lvm_create_lv", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("lvm_create_lv", ctx.targetHost, r.durationMs, cmd, { created: `${args.vg}/${args.name}` });
  });

  registerTool(ctx, { name: "lvm_resize", description: "Resize a logical volume. High risk.", module: "storage", riskLevel: "high", duration: "normal", inputSchema: z.object({ lv_path: z.string().min(1).describe("Logical volume device path (e.g. /dev/vg0/data)"), size: z.string().min(1).describe("New absolute size or relative change (e.g. '20G', '+5G')"), resize_fs: z.boolean().optional().default(true), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = `sudo lvresize ${args.resize_fs !== false ? "-r" : ""} -L ${args.size} ${args.lv_path}`;
    const gate = ctx.safetyGate.check({ toolName: "lvm_resize", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `Resize ${args.lv_path} to ${args.size}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("lvm_resize", ctx.targetHost, 0, null, { would_run: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("lvm_resize", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("lvm_resize", ctx.targetHost, r.durationMs, cmd, { resized: args.lv_path });
  });
}
