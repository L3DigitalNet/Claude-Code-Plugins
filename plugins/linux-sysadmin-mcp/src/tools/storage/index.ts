import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerStorageTools(ctx: PluginContext): void {
  registerTool(ctx, { name: "disk_usage", description: "Show disk usage by filesystem.", module: "storage", riskLevel: "read-only", duration: "quick", inputSchema: z.object({ path: z.string().optional() }), annotations: { readOnlyHint: true } }, async (args) => {
    const cmd = args.path ? `df -h '${args.path}'` : "df -h --output=source,size,used,avail,pcent,target -x tmpfs -x devtmpfs 2>/dev/null || df -h";
    const r = await executeBash(ctx, cmd, "quick");
    // Parse df -h output: skip header, split columns (source size used avail use% target).
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const filesystems = lines.slice(1).map((l) => {
      const p = l.trim().split(/\s+/);
      if (p.length >= 6) return { source: p[0], size: p[1], used: p[2], avail: p[3], use_pct: p[4], mount: p[5] };
      return null;
    }).filter(Boolean);
    return success("disk_usage", ctx.targetHost, r.durationMs, cmd, { filesystems });
  });

  registerTool(ctx, { name: "disk_usage_top", description: "Find largest directories under a path.", module: "storage", riskLevel: "read-only", duration: "normal", inputSchema: z.object({ path: z.string().optional().default("/"), limit: z.number().int().min(1).max(50).optional().default(20), depth: z.number().int().min(1).max(5).optional().default(1) }), annotations: { readOnlyHint: true } }, async (args) => {
    // --one-file-system prevents du from crossing mount boundaries (NFS, pCloud, /proc, /sys).
    // Without it, scanning "/" can block for 30+ seconds on network mounts and return empty results.
    const cmd = `sudo -n du -h --one-file-system --max-depth=${(args.depth as number) ?? 1} '${(args.path as string) ?? "/"}' 2>/dev/null | sort -rh | head -n ${(args.limit as number) ?? 20}`;
    const r = await executeBash(ctx, cmd, "normal");
    // Parse "size\tpath" du output into structured records (tab-separated by du).
    const entries = r.stdout.trim().split("\n").filter(Boolean).map((line) => {
      const tab = line.indexOf("\t");
      return tab !== -1 ? { size: line.slice(0, tab).trim(), path: line.slice(tab + 1).trim() } : { size: line.trim(), path: "" };
    });
    return success("disk_usage_top", ctx.targetHost, r.durationMs, "du + sort", { entries });
  });

  registerTool(ctx, { name: "mount_list", description: "List all mounted filesystems.", module: "storage", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "findmnt --real -o TARGET,SOURCE,FSTYPE,OPTIONS --noheadings 2>/dev/null || mount", "quick");
    // Parse findmnt columns (TARGET SOURCE FSTYPE OPTIONS); fall back to raw string if format differs.
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    const mounts = lines.map((l) => { const p = l.trim().split(/\s+/); return { target: p[0], source: p[1], fstype: p[2], options: p.slice(3).join(" ") }; });
    return success("mount_list", ctx.targetHost, r.durationMs, "findmnt", { mounts, count: mounts.length });
  });

  registerTool(ctx, { name: "mount_add", description: "Add fstab entry and mount. Moderate risk.", module: "storage", riskLevel: "moderate", duration: "normal", inputSchema: z.object({ device: z.string().min(1), mount_point: z.string().min(1), fs_type: z.string().min(1), options: z.string().optional().default("defaults"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const line = `${args.device} ${args.mount_point} ${args.fs_type} ${(args.options as string) || "defaults"} 0 2`;
    const cmd = `sudo mkdir -p '${args.mount_point}' && echo '${line}' | sudo tee -a /etc/fstab && sudo mount '${args.mount_point}'`;
    const gate = ctx.safetyGate.check({ toolName: "mount_add", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Add fstab: ${line}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("mount_add", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("mount_add", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    return success("mount_add", ctx.targetHost, r.durationMs, cmd, { fstab_entry: line, mounted: true });
  });

  registerTool(ctx, { name: "mount_remove", description: "Unmount and remove fstab entry. High risk.", module: "storage", riskLevel: "high", duration: "normal", inputSchema: z.object({ mount_point: z.string().min(1), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const mp = args.mount_point as string;
    const gate = ctx.safetyGate.check({ toolName: "mount_remove", toolRiskLevel: "high", targetHost: ctx.targetHost, command: `umount ${mp}`, description: `Unmount ${mp} and remove from fstab`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("mount_remove", ctx.targetHost, 0, null, { preview_command: `sudo umount '${mp}' && sudo sed -i '\\|${mp}|d' /etc/fstab` }, { dry_run: true });
    const r = await executeBash(ctx, `sudo umount '${mp}' && sudo sed -i '\\|${mp}|d' /etc/fstab`, "normal");
    if (r.exitCode !== 0) return error("mount_remove", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "storage_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("mount_remove", ctx.targetHost, r.durationMs, "umount + sed", { unmounted: mp }, docHint);
  });

  registerTool(ctx, { name: "lvm_status", description: "Show LVM PVs, VGs, and LVs.", module: "storage", riskLevel: "read-only", duration: "quick", inputSchema: z.object({}), annotations: { readOnlyHint: true } }, async () => {
    const r = await executeBash(ctx, "sudo -n pvs 2>/dev/null && echo '---VGS---' && sudo -n vgs 2>/dev/null && echo '---LVS---' && sudo -n lvs 2>/dev/null || echo 'LVM not available'", "quick");
    const output = r.stdout.trim();
    if (output === "LVM not available" || output === "") {
      return success("lvm_status", ctx.targetHost, r.durationMs, "pvs+vgs+lvs", { available: false });
    }
    // Split on the echo separator markers: "---VGS---" and "---LVS---".
    const [pvsRaw = "", vgsRaw = "", lvsRaw = ""] = output.split(/---(?:VGS|LVS)---/).map((s) => s.trim());
    // Parse each section into typed records: strip header row, split data rows on 2+ spaces.
    // Two-space split handles variable column widths while tolerating single spaces within values.
    const parseLvmSection = (raw: string): Record<string, string>[] => {
      const lines = raw.split("\n").filter(Boolean);
      if (lines.length < 2) return [];
      const headers = lines[0].trim().split(/\s{2,}/).map((h) => h.trim().toLowerCase());
      return lines.slice(1).map((line) => {
        const values = line.trim().split(/\s{2,}/);
        const record: Record<string, string> = {};
        headers.forEach((h, i) => { record[h] = (values[i] ?? "").trim(); });
        return record;
      });
    };
    return success("lvm_status", ctx.targetHost, r.durationMs, "pvs+vgs+lvs", {
      available: true, pvs: parseLvmSection(pvsRaw), vgs: parseLvmSection(vgsRaw), lvs: parseLvmSection(lvsRaw),
    });
  });

  registerTool(ctx, { name: "lvm_create_lv", description: "Create a logical volume. Moderate risk.", module: "storage", riskLevel: "moderate", duration: "normal", inputSchema: z.object({ name: z.string().min(1).describe("Name for the new logical volume"), vg: z.string().min(1).describe("Volume group name to create the LV in"), size: z.string().min(1).describe("Size with unit suffix (e.g. '10G', '500M')"), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: false } }, async (args) => {
    const cmd = `sudo lvcreate -L ${args.size} -n ${args.name} ${args.vg}`;
    const gate = ctx.safetyGate.check({ toolName: "lvm_create_lv", toolRiskLevel: "moderate", targetHost: ctx.targetHost, command: cmd, description: `Create LV ${args.name} (${args.size}) in VG ${args.vg}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("lvm_create_lv", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("lvm_create_lv", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "storage_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("lvm_create_lv", ctx.targetHost, r.durationMs, cmd, { created: `${args.vg}/${args.name}` }, docHint);
  });

  registerTool(ctx, { name: "lvm_resize", description: "Resize a logical volume. High risk.", module: "storage", riskLevel: "high", duration: "normal", inputSchema: z.object({ lv_path: z.string().min(1).describe("Logical volume device path (e.g. /dev/vg0/data)"), size: z.string().min(1).describe("New absolute size or relative change (e.g. '20G', '+5G')"), resize_fs: z.boolean().optional().default(true), confirmed: z.boolean().optional().default(false).describe("Pass true to confirm execution after reviewing a confirmation_required response."), dry_run: z.boolean().optional().default(false).describe("Preview without executing — returns the command that would run without making changes.") }), annotations: { destructiveHint: true } }, async (args) => {
    const cmd = `sudo lvresize ${args.resize_fs !== false ? "-r" : ""} -L ${args.size} ${args.lv_path}`;
    const gate = ctx.safetyGate.check({ toolName: "lvm_resize", toolRiskLevel: "high", targetHost: ctx.targetHost, command: cmd, description: `Resize ${args.lv_path} to ${args.size}`, confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean });
    if (gate) return gate;
    if (args.dry_run) return success("lvm_resize", ctx.targetHost, 0, null, { preview_command: cmd }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) return error("lvm_resize", ctx.targetHost, r.durationMs, { code: "COMMAND_FAILED", category: "state", message: r.stderr.trim() });
    const docHint = ctx.config.documentation.repo_path
      ? { documentation_action: { type: "storage_changed", suggested_actions: ["doc_generate_host"] } }
      : undefined;
    return success("lvm_resize", ctx.targetHost, r.durationMs, cmd, { resized: args.lv_path }, docHint);
  });
}
