import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash } from "../helpers.js";

export function registerSecurityTools(ctx: PluginContext): void {
  registerTool(ctx, {
    name: "sec_audit", description: "Run a security audit: check services, listening ports, failed logins, health checks from knowledge profiles.",
    module: "security", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const [failedR, listeningR, loginR] = await Promise.all([
      executeBash(ctx, "systemctl list-units --type=service --state=failed --no-pager --no-legend 2>/dev/null", "quick"),
      executeBash(ctx, "sudo -n ss -tlnp 2>/dev/null || ss -tln", "quick"),
      executeBash(ctx, "journalctl _SYSTEMD_UNIT=sshd.service -p warning --since '24 hours ago' --no-pager -n 20 2>/dev/null || echo 'No SSH logs available'", "quick"),
    ]);
    // Run health checks from active profiles
    const profileResults: Array<{ profile: string; checks: Array<{ desc: string; passed: boolean }> }> = [];
    for (const rp of ctx.knowledgeBase.getActiveProfiles()) {
      const checks: Array<{ desc: string; passed: boolean }> = [];
      for (const hc of rp.profile.health_checks ?? []) {
        const hr = await executeBash(ctx, hc.command, "quick");
        let passed = hc.expect_exit !== undefined ? hr.exitCode === hc.expect_exit : hr.exitCode === 0;
        if (hc.expect_contains && passed) passed = hr.stdout.includes(hc.expect_contains);
        checks.push({ desc: hc.description, passed });
      }
      if (checks.length) profileResults.push({ profile: rp.profile.name, checks });
    }
    const failedCount = failedR.stdout.trim().split("\n").filter(Boolean).length;
    const severity = failedCount > 0 || profileResults.some(p => p.checks.some(c => !c.passed)) ? "warning" as const : "info" as const;
    return success("sec_audit", ctx.targetHost, failedR.durationMs, "multiple", {
      failed_services: failedR.stdout.trim() || "none",
      listening_ports: listeningR.stdout.trim(),
      recent_ssh_warnings: loginR.stdout.trim(),
      profile_health: profileResults,
    }, { summary: `${failedCount} failed services. ${profileResults.length} profiles checked.`, severity });
  });

  registerTool(ctx, {
    name: "sec_check_ssh", description: "Audit SSH server configuration for security issues.",
    module: "security", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "sudo -n cat /etc/ssh/sshd_config 2>/dev/null || cat /etc/ssh/sshd_config 2>/dev/null || echo 'Cannot read sshd_config'", "quick");
    const config = r.stdout.trim();
    const findings: string[] = [];
    if (config.match(/^PermitRootLogin\s+yes/m)) findings.push("Root login is enabled (PermitRootLogin yes)");
    if (config.match(/^PasswordAuthentication\s+yes/m)) findings.push("Password authentication is enabled");
    if (!config.match(/^MaxAuthTries\s+[1-3]$/m)) findings.push("MaxAuthTries is not restricted (recommend 3)");
    if (config.match(/^X11Forwarding\s+yes/m)) findings.push("X11 forwarding is enabled");
    const severity = findings.length > 2 ? "high" as const : findings.length > 0 ? "warning" as const : "info" as const;
    return success("sec_check_ssh", ctx.targetHost, r.durationMs, "cat /etc/ssh/sshd_config", {
      config_length: config.split("\n").length, findings,
    }, { summary: findings.length ? `${findings.length} SSH hardening recommendations found.` : "SSH configuration looks hardened.", severity });
  });

  registerTool(ctx, {
    name: "sec_harden_ssh", description: "Apply SSH hardening (disable password auth, root login, etc.). High risk.",
    module: "security", riskLevel: "high", duration: "normal",
    inputSchema: z.object({
      actions: z.array(z.enum(["disable_root_login", "disable_password_auth", "set_max_auth_tries", "disable_x11"])).min(1),
      confirmed: z.boolean().optional().default(false), dry_run: z.boolean().optional().default(false),
    }),
    annotations: { destructiveHint: true },
  }, async (args) => {
    const actions = args.actions as string[];
    const sedCmds: string[] = [];
    const descriptions: string[] = [];
    for (const a of actions) {
      switch (a) {
        case "disable_root_login": sedCmds.push("s/^#*PermitRootLogin.*/PermitRootLogin no/"); descriptions.push("Disable root login"); break;
        case "disable_password_auth": sedCmds.push("s/^#*PasswordAuthentication.*/PasswordAuthentication no/"); descriptions.push("Disable password auth"); break;
        case "set_max_auth_tries": sedCmds.push("s/^#*MaxAuthTries.*/MaxAuthTries 3/"); descriptions.push("Set MaxAuthTries to 3"); break;
        case "disable_x11": sedCmds.push("s/^#*X11Forwarding.*/X11Forwarding no/"); descriptions.push("Disable X11 forwarding"); break;
      }
    }
    const cmd = `sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak && sudo sed -i '${sedCmds.join(";")}' /etc/ssh/sshd_config && sudo sshd -t && sudo systemctl reload sshd`;
    const gate = ctx.safetyGate.check({
      toolName: "sec_harden_ssh", toolRiskLevel: "high", targetHost: ctx.targetHost,
      command: cmd, description: `SSH hardening: ${descriptions.join(", ")}`,
      confirmed: args.confirmed as boolean, dryRun: args.dry_run as boolean,
    });
    if (gate) return gate;
    if (args.dry_run) return success("sec_harden_ssh", ctx.targetHost, 0, null, { would_apply: descriptions }, { dry_run: true });
    const r = await executeBash(ctx, cmd, "normal");
    if (r.exitCode !== 0) {
      // Rollback on failure
      await executeBash(ctx, "sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config 2>/dev/null", "quick");
      return error("sec_harden_ssh", ctx.targetHost, r.durationMs, {
        code: "VALIDATION_FAILED", category: "validation", message: `sshd config validation failed — rolled back. ${r.stderr.trim()}`,
        remediation: ["Check sshd_config syntax", "Review /etc/ssh/sshd_config.bak for the previous state"],
      });
    }
    return success("sec_harden_ssh", ctx.targetHost, r.durationMs, cmd, { applied: descriptions, backup: "/etc/ssh/sshd_config.bak" }, {
      documentation_action: { type: "config_changed", service: "sshd", suggested_actions: ["doc_backup_config(service='sshd')", "doc_generate_service(service='sshd')"] },
    });
  });

  registerTool(ctx, {
    name: "sec_update_check", description: "Check for available security updates specifically.",
    module: "security", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const cmd = ctx.distro.family === "debian"
      ? "apt list --upgradable 2>/dev/null | grep -i security"
      : "dnf check-update --security 2>/dev/null";
    const r = await executeBash(ctx, cmd, "normal");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    return success("sec_update_check", ctx.targetHost, r.durationMs, cmd, { security_updates: lines, count: lines.length });
  });

  registerTool(ctx, {
    name: "sec_mac_status", description: "Show MAC system status (SELinux/AppArmor).",
    module: "security", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    let cmd: string;
    if (ctx.distro.mac_system === "selinux") cmd = "getenforce && sestatus 2>/dev/null";
    else if (ctx.distro.mac_system === "apparmor") cmd = "sudo -n aa-status 2>/dev/null || echo 'AppArmor status requires sudo'";
    else cmd = "echo 'No MAC system detected'";
    const r = await executeBash(ctx, cmd, "quick");
    return success("sec_mac_status", ctx.targetHost, r.durationMs, cmd, {
      system: ctx.distro.mac_system, mode: ctx.distro.mac_mode, detail: r.stdout.trim(),
    });
  });

  registerTool(ctx, {
    name: "sec_check_listening", description: "Audit listening ports and identify unexpected services.",
    module: "security", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({}), annotations: { readOnlyHint: true },
  }, async () => {
    const r = await executeBash(ctx, "sudo -n ss -tlnp 2>/dev/null || ss -tln", "quick");
    return success("sec_check_listening", ctx.targetHost, r.durationMs, "ss -tlnp", { listening: r.stdout.trim() });
  });

  registerTool(ctx, {
    name: "sec_check_suid", description: "Find SUID/SGID binaries on the system.",
    module: "security", riskLevel: "read-only", duration: "slow",
    inputSchema: z.object({ path: z.string().optional().default("/").describe("Search root path") }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const p = (args.path as string) ?? "/";
    const r = await executeBash(ctx, `find ${p} -type f \\( -perm -4000 -o -perm -2000 \\) -ls 2>/dev/null | head -100`, "slow");
    const lines = r.stdout.trim().split("\n").filter(Boolean);
    return success("sec_check_suid", ctx.targetHost, r.durationMs, "find ... -perm -4000/-2000", { suid_files: lines, count: lines.length });
  });
}
