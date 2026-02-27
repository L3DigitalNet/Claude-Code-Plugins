import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, executeBash } from "../helpers.js";

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
    const failedServices = failedR.stdout.trim().split("\n").filter(Boolean);
    const failedCount = failedServices.length;
    const hasFailedHealthChecks = profileResults.some(p => p.checks.some(c => !c.passed));
    // Use the full severity scale: >5 failed services = critical, >2 = high, any = warning
    const severity = failedCount > 5 ? "critical" as const
      : failedCount > 2 ? "high" as const
      : (failedCount > 0 || hasFailedHealthChecks) ? "warning" as const
      : "info" as const;
    // Parse listening ports from ss output into structured records
    const listenLines = listeningR.stdout.trim().split("\n").filter(Boolean);
    const listening_ports: Array<{ proto: string; local_addr: string; port: number; process?: string }> = [];
    for (const line of listenLines) {
      // ss -tlnp format: Netid State Recv-Q Send-Q Local Address:Port Peer Address:Port Process
      const parts = line.trim().split(/\s+/);
      if (parts[0] === "tcp" || parts[0] === "udp") {
        const localPart = parts[4] ?? "";
        const lastColon = localPart.lastIndexOf(":");
        if (lastColon !== -1) {
          const addr = localPart.slice(0, lastColon);
          const port = parseInt(localPart.slice(lastColon + 1));
          if (!isNaN(port)) {
            listening_ports.push({
              proto: parts[0],
              local_addr: addr,
              port,
              // Process column appears at index 6 if present (requires sudo for ss -p)
              ...(parts[6] ? { process: parts[6].replace(/users:\(\("?([^"]+)"?,.*\)/, "$1") } : {}),
            });
          }
        }
      }
    }
    // Parse SSH warning lines: journalctl "short" format is "MMM DD HH:MM:SS host unit[pid]: message".
    // Lines that don't match (boot markers, dividers) are counted as unparsed.
    const sshLines = loginR.stdout.trim().split("\n").filter(Boolean);
    const recent_ssh_warnings: Array<{ timestamp: string; message: string }> = [];
    let ssh_unparsed = 0;
    for (const line of sshLines) {
      const m = line.match(/^(\w{3}\s+\d+\s+[\d:]+)\s+\S+\s+\S+:\s+(.+)$/);
      if (m) recent_ssh_warnings.push({ timestamp: m[1], message: m[2] });
      else if (line !== "No SSH logs available") ssh_unparsed++;
    }
    // Three commands ran in parallel — report actual wall-clock time, not just the first sub-command's duration.
    return success("sec_audit", ctx.targetHost, Math.max(failedR.durationMs, listeningR.durationMs, loginR.durationMs), "multiple", {
      failed_services: failedServices.length > 0 ? failedServices : "none",
      listening_ports,
      recent_ssh_warnings,
      ...(ssh_unparsed > 0 ? { ssh_warnings_unparsed_count: ssh_unparsed } : {}),
      profile_health: profileResults,
    }, { summary: `${failedCount} failed services. ${profileResults.length} profiles checked.`, severity });
  });
}
