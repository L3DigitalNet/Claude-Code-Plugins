import { z } from "zod";
import type { PluginContext } from "../context.js";
import { registerTool, success, error, executeBash, executeCommand } from "../helpers.js";

export function registerServiceTools(ctx: PluginContext): void {
  // ── svc_status ──────────────────────────────────────────────────
  registerTool(ctx, {
    name: "svc_status", description: "Detailed status of a specific service. Enriched with knowledge profile health checks when available.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({ service: z.string().min(1).describe("Service/unit name") }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string;
    const cmd = ctx.commands.serviceStatus(svc);
    const r = await executeCommand(ctx, "svc_status", cmd, "quick");
    // Parse systemctl status output
    const output = r.stdout.trim();
    const data: Record<string, unknown> = { service: svc, raw_status: output };
    // Extract key fields
    const activeMatch = output.match(/Active:\s+(\S+)\s+\((\S+)\)/);
    if (activeMatch) { data.active_state = activeMatch[1]; data.sub_state = activeMatch[2]; }
    const pidMatch = output.match(/Main PID:\s+(\d+)/);
    if (pidMatch) data.pid = parseInt(pidMatch[1]);
    const memMatch = output.match(/Memory:\s+([\d.]+\S+)/);
    if (memMatch) data.memory = memMatch[1];
    // Check knowledge profile health checks
    const profile = ctx.knowledgeBase.getProfile(svc);
    if (profile?.health_checks) {
      const checks: Array<{ description: string; passed: boolean; output: string }> = [];
      for (const hc of profile.health_checks) {
        const hr = await executeBash(ctx, hc.command, "quick");
        let passed = true;
        if (hc.expect_exit !== undefined) passed = hr.exitCode === hc.expect_exit;
        if (hc.expect_output !== undefined) {
          // Exact line match — avoids "active" matching "inactive" via substring
          if (typeof hc.expect_output === "string") {
            passed = passed && hr.stdout.trim().split("\n").some(line => line.trim() === (hc.expect_output as string));
          } else {
            passed = passed && hr.stdout.trim().length > 0;
          }
        }
        if (hc.expect_contains) passed = passed && hr.stdout.includes(hc.expect_contains);
        checks.push({ description: hc.description, passed, output: hr.stdout.trim().slice(0, 200) });
      }
      data.health_checks = checks;
    }
    return success("svc_status", ctx.targetHost, r.durationMs, cmd.argv.join(" "), data);
  });

  // ── svc_logs ────────────────────────────────────────────────────
  registerTool(ctx, {
    name: "svc_logs", description: "Retrieve recent logs for a service. Consults knowledge profile for all log sources.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({
      service: z.string().min(1).describe("Service or unit name (e.g. 'nginx', 'nginx.service')"), lines: z.number().int().min(1).max(500).optional().default(50).describe("Number of log lines to retrieve (default 50, max 500)"),
      since: z.string().optional().describe("Time filter e.g. '1 hour ago', '2024-01-01'"),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string;
    const lines = (args.lines as number) ?? 50;
    let cmd = `journalctl -u ${svc} -n ${lines} --no-pager`;
    if (args.since) cmd += ` --since '${args.since}'`;
    const r = await executeBash(ctx, cmd, "quick");
    const journalLines = r.stdout.trim().split("\n").filter(Boolean);
    const data: Record<string, unknown> = {
      service: svc,
      journal_logs: journalLines,
      log_line_count: journalLines.length,
      // truncated when returned lines equals the requested limit — more may exist
      truncated: journalLines.length >= lines,
    };
    // Check knowledge profile for additional log paths
    const profile = ctx.knowledgeBase.getProfile(svc);
    if (profile?.logs) {
      const fileLogs: Array<{ path: string; tail: string }> = [];
      for (const log of profile.logs) {
        if (log.path) {
          const lr = await executeBash(ctx, `tail -n ${lines} '${log.path}' 2>/dev/null`, "quick");
          if (lr.exitCode === 0 && lr.stdout.trim()) fileLogs.push({ path: log.path, tail: lr.stdout.trim() });
        }
      }
      if (fileLogs.length) data.file_logs = fileLogs;
    }
    return success("svc_logs", ctx.targetHost, r.durationMs, cmd, data);
  });

  // ── svc_config_validate ─────────────────────────────────────────
  // Runs each active profile's validate_command (sshd -t, nginx -t, etc.)
  // and reports structured pass/fail results. Activates the previously
  // unconsumed config.validate_command profile field.
  registerTool(ctx, {
    name: "svc_config_validate",
    description: "Run config validation commands from knowledge profiles. Validates one service or sweeps all active profiles that declare a validate_command.",
    module: "services", riskLevel: "read-only", duration: "quick",
    inputSchema: z.object({
      service: z.string().min(1).optional().describe("Validate one service; omit to validate all active profiles"),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string | undefined;

    // Determine target profiles
    type ValidateTarget = { id: string; name: string; validate_command: string | null | undefined };
    let targets: ValidateTarget[];

    if (svc) {
      const profile = ctx.knowledgeBase.getProfile(svc);
      if (!profile) {
        return error("svc_config_validate", ctx.targetHost, null, {
          code: "PROFILE_NOT_FOUND", category: "not_found",
          message: `No knowledge profile found for "${svc}"`,
          remediation: ["Run sysadmin_session_info to see available profiles", "Check the service name matches a profile id"],
        });
      }
      targets = [{ id: profile.id, name: profile.name, validate_command: profile.config.validate_command }];
    } else {
      targets = ctx.knowledgeBase.getActiveProfiles().map(rp => ({
        id: rp.profile.id, name: rp.profile.name, validate_command: rp.profile.config.validate_command,
      }));
    }

    const withValidator = targets.filter(t => t.validate_command);
    const withoutValidator = targets.filter(t => !t.validate_command);

    // Run all validate commands in parallel
    const results: Array<{ service: string; command: string; passed: boolean; output: string }> = [];
    let maxDuration = 0;

    await Promise.all(withValidator.map(async (t) => {
      const cmd = `sudo -n ${t.validate_command} 2>&1 || ${t.validate_command} 2>&1`;
      const r = await executeBash(ctx, cmd, "quick");
      maxDuration = Math.max(maxDuration, r.durationMs);
      results.push({
        service: t.id, command: t.validate_command!,
        passed: r.exitCode === 0,
        output: (r.stdout + "\n" + r.stderr).trim().slice(0, 500),
      });
    }));

    const failNames = results.filter(r => !r.passed).map(r => r.service);
    const severity = failNames.length > 0 ? "warning" as const : "info" as const;
    const summaryParts = [`${results.length - failNames.length} of ${results.length} configs valid`];
    if (failNames.length > 0) summaryParts.push(`${failNames.length} failed (${failNames.join(", ")})`);

    return success("svc_config_validate", ctx.targetHost, maxDuration, "multiple", {
      results,
      ...(withoutValidator.length > 0 ? { no_validator: withoutValidator.map(t => t.id) } : {}),
    }, { summary: summaryParts.join(". ") + ".", severity });
  });

  // ── svc_dependency_impact ───────────────────────────────────────
  // Pure profile-graph traversal: walks dependencies.requires and
  // required_by across active profiles to show cascade impact before
  // a stop/restart. No shell commands executed.
  registerTool(ctx, {
    name: "svc_dependency_impact",
    description: "Analyze cascade impact of stopping or restarting a service. Walks the dependency graph across active knowledge profiles to show direct and transitive dependents.",
    module: "services", riskLevel: "read-only", duration: "instant",
    inputSchema: z.object({
      service: z.string().min(1).describe("Service to analyze"),
      action: z.enum(["stop", "restart"]).optional().default("restart").describe("Intended action (default: restart)"),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string;
    const action = (args.action as string) ?? "restart";

    const profile = ctx.knowledgeBase.getProfile(svc);
    if (!profile) {
      return error("svc_dependency_impact", ctx.targetHost, null, {
        code: "PROFILE_NOT_FOUND", category: "not_found",
        message: `No knowledge profile found for "${svc}"`,
        remediation: ["Run sysadmin_session_info to see available profiles"],
      });
    }

    const activeProfiles = ctx.knowledgeBase.getActiveProfiles();

    // Which roles does the target service fill?
    const targetRoles = (profile.dependencies?.required_by ?? []).map(rb => rb.role);

    // Find direct dependents: profiles whose requires match a targetRole
    interface DependentInfo { service: string; name: string; role: string; impact: string }
    const directDependents: DependentInfo[] = [];

    for (const rp of activeProfiles) {
      if (rp.profile.id === svc) continue;
      for (const req of rp.profile.dependencies?.requires ?? []) {
        // Match via declared role OR via runtime role resolution
        if (targetRoles.includes(req.role) || rp.rolesResolved[req.role] === svc) {
          if (!directDependents.some(d => d.service === rp.profile.id && d.role === req.role)) {
            directDependents.push({
              service: rp.profile.id, name: rp.profile.name,
              role: req.role, impact: req.impact_if_down ?? `Depends on ${svc} for ${req.role}`,
            });
          }
        }
      }
    }

    // Transitive walk: dependents of dependents, max depth 3
    interface TransitiveDep { service: string; name: string; path: string[] }
    const transitiveDependents: TransitiveDep[] = [];
    const visited = new Set<string>([svc]);

    function walkDependents(serviceId: string, depth: number, path: string[]): void {
      if (depth >= 3) return;
      visited.add(serviceId);
      const p = ctx.knowledgeBase.getProfile(serviceId);
      if (!p) return;
      const roles = (p.dependencies?.required_by ?? []).map(rb => rb.role);
      for (const rp of activeProfiles) {
        if (visited.has(rp.profile.id)) continue;
        for (const req of rp.profile.dependencies?.requires ?? []) {
          if (roles.includes(req.role) || rp.rolesResolved[req.role] === serviceId) {
            const newPath = [...path, rp.profile.id];
            transitiveDependents.push({ service: rp.profile.id, name: rp.profile.name, path: newPath });
            walkDependents(rp.profile.id, depth + 1, newPath);
          }
        }
      }
    }

    for (const dd of directDependents) walkDependents(dd.service, 1, [svc, dd.service]);

    // Collect interaction warnings relevant to this action
    const warnings = (profile.interactions ?? [])
      .filter(i => i.warning && (i.trigger.includes(action) || i.trigger.includes("restart") || i.trigger.includes("config")))
      .map(i => i.warning);

    const totalDeps = directDependents.length + transitiveDependents.length;
    const severity = totalDeps === 0 ? "info" as const : totalDeps <= 2 ? "warning" as const : "high" as const;
    const actionDesc = action === "stop" ? "Stopping" : "Restarting";

    return success("svc_dependency_impact", ctx.targetHost, null, null, {
      service: svc, action, roles_provided: targetRoles,
      direct_dependents: directDependents,
      ...(transitiveDependents.length > 0 ? { transitive_dependents: transitiveDependents } : {}),
      ...(warnings.length > 0 ? { warnings } : {}),
    }, {
      summary: `${actionDesc} ${svc}: ${directDependents.length} direct dependent${directDependents.length !== 1 ? "s" : ""}${transitiveDependents.length > 0 ? `, ${transitiveDependents.length} transitive` : ""}.`,
      severity,
    });
  });

  // ── svc_port_audit ──────────────────────────────────────────────
  // Three-way correlation: profile-declared ports vs actually listening
  // ports (ss) vs firewall rules (ufw/firewalld). Finds mismatches that
  // indicate services down, missing firewall rules, or stale allows.
  registerTool(ctx, {
    name: "svc_port_audit",
    description: "Three-way audit of profile-declared ports vs listening ports vs firewall rules. Reports expected ports not listening, listening ports missing firewall rules, and unknown firewall allows.",
    module: "services", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({}),
    annotations: { readOnlyHint: true },
  }, async () => {
    const fwBackend = ctx.distro.firewall_backend;
    const fwCmd = fwBackend === "ufw"
      ? "sudo -n ufw status 2>/dev/null || echo 'FW_UNAVAILABLE'"
      : fwBackend === "firewalld"
      ? "sudo -n firewall-cmd --list-ports --list-services 2>/dev/null || echo 'FW_UNAVAILABLE'"
      : "echo 'FW_UNAVAILABLE'";

    // Gather listening ports (TCP + UDP) and firewall state in parallel
    const [ssR, fwR] = await Promise.all([
      executeBash(ctx, "sudo -n ss -tlnup 2>/dev/null || ss -tlnup 2>/dev/null || ss -tlun", "quick"),
      executeBash(ctx, fwCmd, "quick"),
    ]);

    // Parse listening ports from ss output
    const listeningPorts = new Set<number>();
    for (const line of ssR.stdout.trim().split("\n")) {
      const parts = line.trim().split(/\s+/);
      if (parts[0] !== "tcp" && parts[0] !== "udp") continue;
      const localPart = parts[4] ?? "";
      const lastColon = localPart.lastIndexOf(":");
      if (lastColon === -1) continue;
      const port = parseInt(localPart.slice(lastColon + 1));
      if (!isNaN(port)) listeningPorts.add(port);
    }

    // Parse firewall allowed ports into a set of "port/proto" strings
    const firewallAllowed = new Set<string>();
    const fwAvailable = !fwR.stdout.includes("FW_UNAVAILABLE");

    if (fwAvailable && fwBackend === "ufw") {
      for (const line of fwR.stdout.split("\n")) {
        const m = line.match(/^(\S+)\s+ALLOW/);
        if (!m) continue;
        const portSpec = m[1];
        const slashIdx = portSpec.indexOf("/");
        const proto = slashIdx !== -1 ? portSpec.slice(slashIdx + 1) : "any";
        const portsPart = slashIdx !== -1 ? portSpec.slice(0, slashIdx) : portSpec;
        for (const p of portsPart.split(",")) {
          const pNum = parseInt(p.trim());
          if (isNaN(pNum)) continue;
          if (proto === "any" || proto === "tcp") firewallAllowed.add(`${pNum}/tcp`);
          if (proto === "any" || proto === "udp") firewallAllowed.add(`${pNum}/udp`);
        }
      }
    } else if (fwAvailable && fwBackend === "firewalld") {
      for (const token of fwR.stdout.trim().split(/\s+/)) {
        if (token.includes("/")) firewallAllowed.add(token);
      }
    }

    // Collect profile-declared ports from all active profiles
    interface DeclaredPort { service: string; port: number; protocol: string; scope: string; description: string }
    const declaredPorts: DeclaredPort[] = [];
    for (const rp of ctx.knowledgeBase.getActiveProfiles()) {
      for (const p of rp.profile.ports ?? []) {
        declaredPorts.push({ service: rp.profile.id, port: p.port, protocol: p.protocol, scope: p.scope, description: p.description });
      }
    }

    // Three-way diff
    const expectedNotListening: Array<{ service: string; port: number; protocol: string }> = [];
    const listeningNoFirewall: Array<{ service: string; port: number; protocol: string }> = [];
    const healthy: Array<{ service: string; port: number; protocol: string; scope: string }> = [];

    for (const dp of declaredPorts) {
      if (!listeningPorts.has(dp.port)) {
        expectedNotListening.push({ service: dp.service, port: dp.port, protocol: dp.protocol });
        continue;
      }
      if (dp.scope === "network" && fwAvailable) {
        const protos = dp.protocol.includes("/") ? dp.protocol.split("/") : [dp.protocol];
        const hasFwRule = protos.some(proto => firewallAllowed.has(`${dp.port}/${proto}`));
        if (!hasFwRule) {
          listeningNoFirewall.push({ service: dp.service, port: dp.port, protocol: dp.protocol });
          continue;
        }
      }
      healthy.push({ service: dp.service, port: dp.port, protocol: dp.protocol, scope: dp.scope });
    }

    // Firewall rules not matching any active profile
    const profilePortSet = new Set(declaredPorts.map(dp => dp.port));
    const firewallNoProfile: string[] = [];
    for (const rule of firewallAllowed) {
      const port = parseInt(rule.split("/")[0]);
      if (!profilePortSet.has(port)) firewallNoProfile.push(rule);
    }

    const severity = expectedNotListening.length > 0 ? "warning" as const
      : listeningNoFirewall.length > 0 ? "high" as const
      : "info" as const;

    return success("svc_port_audit", ctx.targetHost, Math.max(ssR.durationMs, fwR.durationMs), "multiple", {
      profiles_audited: [...new Set(declaredPorts.map(d => d.service))],
      healthy,
      ...(expectedNotListening.length > 0 ? { expected_not_listening: expectedNotListening } : {}),
      ...(listeningNoFirewall.length > 0 ? { listening_no_firewall: listeningNoFirewall } : {}),
      ...(firewallNoProfile.length > 0 ? { firewall_no_profile: firewallNoProfile } : {}),
      firewall_backend: fwBackend,
      firewall_available: fwAvailable,
    }, {
      summary: `${healthy.length} healthy, ${expectedNotListening.length} not listening, ${listeningNoFirewall.length} missing fw rules.`,
      severity,
    });
  });

  // ── svc_troubleshoot ────────────────────────────────────────────
  // Profile-guided diagnostics: runs a profile's troubleshooting checks,
  // correlates failures with known common causes, and adds health check
  // context. Activates the previously unconsumed troubleshooting field
  // (present in sshd, pihole, unbound profiles).
  registerTool(ctx, {
    name: "svc_troubleshoot",
    description: "Profile-guided diagnostics. Runs troubleshooting checks from a service's knowledge profile and correlates failures with known common causes. Also runs health checks for context.",
    module: "services", riskLevel: "read-only", duration: "normal",
    inputSchema: z.object({
      service: z.string().min(1).describe("Service to troubleshoot"),
      symptom: z.string().optional().describe("Match a specific symptom; omit to run all troubleshooting entries"),
    }),
    annotations: { readOnlyHint: true },
  }, async (args) => {
    const svc = args.service as string;
    const symptomFilter = args.symptom as string | undefined;

    const profile = ctx.knowledgeBase.getProfile(svc);
    if (!profile) {
      return error("svc_troubleshoot", ctx.targetHost, null, {
        code: "PROFILE_NOT_FOUND", category: "not_found",
        message: `No knowledge profile found for "${svc}"`,
        remediation: ["Run sysadmin_session_info to see available profiles"],
      });
    }

    if (!profile.troubleshooting?.length) {
      return error("svc_troubleshoot", ctx.targetHost, null, {
        code: "NO_TROUBLESHOOTING_DATA", category: "validation",
        message: `Profile "${svc}" has no troubleshooting entries`,
        remediation: [
          "Use Claude's Bash tool for manual diagnostics: systemctl status, journalctl, ss",
          "Consider adding troubleshooting entries to the knowledge profile YAML",
        ],
      });
    }

    // Filter entries by symptom if provided
    let entries = profile.troubleshooting;
    if (symptomFilter) {
      const needle = symptomFilter.toLowerCase();
      entries = entries.filter(e => e.symptom.toLowerCase().includes(needle));
      if (entries.length === 0) {
        return error("svc_troubleshoot", ctx.targetHost, null, {
          code: "SYMPTOM_NOT_FOUND", category: "not_found",
          message: `No troubleshooting entry matches "${symptomFilter}" for ${svc}`,
          remediation: [
            `Available symptoms: ${profile.troubleshooting.map(t => t.symptom).join(", ")}`,
            "Omit the symptom parameter to run all troubleshooting entries",
          ],
        });
      }
    }

    // Run all checks across matching entries in parallel
    interface CheckResult { command: string; passed: boolean; output: string }
    interface EntryResult { symptom: string; checks: CheckResult[]; common_causes: string[]; likely_causes: string[] }
    const entryResults: EntryResult[] = [];
    let maxDuration = 0;

    for (const entry of entries) {
      const checks = await Promise.all(entry.checks.map(async (cmd) => {
        const r = await executeBash(ctx, cmd, "quick");
        maxDuration = Math.max(maxDuration, r.durationMs);
        return { command: cmd, passed: r.exitCode === 0, output: r.stdout.trim().slice(0, 200) };
      }));

      // Heuristic correlation: failed check[i] suggests common_causes[i]
      const likely_causes: string[] = [];
      checks.forEach((check, i) => {
        if (!check.passed && i < entry.common_causes.length) {
          likely_causes.push(entry.common_causes[i]);
        }
      });

      entryResults.push({ symptom: entry.symptom, checks, common_causes: entry.common_causes, likely_causes });
    }

    // Run health checks for additional context (same evaluation logic as svc_status)
    const healthResults: Array<{ description: string; passed: boolean; output: string }> = [];
    if (profile.health_checks?.length) {
      const hcResults = await Promise.all(profile.health_checks.map(async (hc) => {
        const hr = await executeBash(ctx, hc.command, "quick");
        maxDuration = Math.max(maxDuration, hr.durationMs);
        let passed = true;
        if (hc.expect_exit !== undefined) passed = hr.exitCode === hc.expect_exit;
        if (hc.expect_output !== undefined) {
          if (typeof hc.expect_output === "string") {
            passed = passed && hr.stdout.trim().split("\n").some(line => line.trim() === (hc.expect_output as string));
          } else {
            passed = passed && hr.stdout.trim().length > 0;
          }
        }
        if (hc.expect_contains) passed = passed && hr.stdout.includes(hc.expect_contains);
        return { description: hc.description, passed, output: hr.stdout.trim().slice(0, 200) };
      }));
      healthResults.push(...hcResults);
    }

    const totalChecks = entryResults.reduce((sum, e) => sum + e.checks.length, 0);
    const failedChecks = entryResults.reduce((sum, e) => sum + e.checks.filter(c => !c.passed).length, 0);
    const failedHealth = healthResults.filter(h => !h.passed).length;
    const likelyCauses = entryResults.flatMap(e => e.likely_causes);

    const severity = failedChecks === 0 && failedHealth === 0 ? "info" as const
      : failedChecks >= totalChecks * 0.5 ? "high" as const
      : "warning" as const;

    return success("svc_troubleshoot", ctx.targetHost, maxDuration, "multiple", {
      service: svc,
      troubleshooting: entryResults,
      ...(healthResults.length > 0 ? { health_checks: healthResults } : {}),
      checks_total: totalChecks, checks_failed: failedChecks,
    }, {
      summary: `${failedChecks} of ${totalChecks} checks failed. ${likelyCauses.length} likely cause${likelyCauses.length !== 1 ? "s" : ""} identified.`,
      severity,
    });
  });
}
