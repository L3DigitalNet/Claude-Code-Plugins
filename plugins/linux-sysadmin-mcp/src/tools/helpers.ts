import { z } from "zod";
import type { PluginContext } from "./context.js";
import type { ToolResponse, SuccessResponse, ErrorResponse, ErrorCategory } from "../types/response.js";
import type { ToolMetadata, RegisteredTool, ExecutionContext } from "../types/tool.js";
import type { Command } from "../types/command.js";
import type { RiskLevel, DurationCategory } from "../types/risk.js";
import { DURATION_TIMEOUTS } from "../types/risk.js";
import { execBash } from "../execution/executor.js";

// ── Response Builders ──────────────────────────────────────────────

export function success(tool: string, targetHost: string, durationMs: number, commandExecuted: string | null, data: Record<string, unknown>, extra?: Partial<SuccessResponse>): SuccessResponse {
  return { status: "success", tool, target_host: targetHost, duration_ms: durationMs, command_executed: commandExecuted, data, ...extra };
}

export function error(tool: string, targetHost: string, durationMs: number, opts: { code: string; category: ErrorCategory; message: string; transient?: boolean; remediation?: string[] }): ErrorResponse {
  return {
    status: "error", tool, target_host: targetHost, duration_ms: durationMs, command_executed: null,
    error_code: opts.code, error_category: opts.category, message: opts.message,
    transient: opts.transient ?? false, retried: false, retry_count: 0,
    remediation: opts.remediation ?? [],
  };
}

// ── Error Categorization (Section 7.2) ─────────────────────────────

interface ErrorPattern {
  test: (stderr: string) => boolean;
  code: string;
  category: ErrorCategory;
  transient: boolean;
  remediation: (ctx: PluginContext) => string[];
}

const ERROR_PATTERNS: ErrorPattern[] = [
  { test: (s) => s.includes("permission denied") || s.includes("sudo:") || s.includes("Operation not permitted"),
    code: "PERMISSION_DENIED", category: "privilege", transient: false,
    remediation: (ctx) => [
      "Verify passwordless sudo is configured for this user",
      ctx.distro.family === "debian"
        ? "Add NOPASSWD rule to /etc/sudoers.d/linux-sysadmin for apt commands"
        : "Add NOPASSWD rule to /etc/sudoers.d/linux-sysadmin for dnf commands",
      "Run 'sudo -n true' to test sudo access",
    ] },
  { test: (s) => s.includes("Unable to locate package") || s.includes("No match for argument") || s.includes("No packages found"),
    code: "PACKAGE_NOT_FOUND", category: "not_found", transient: false,
    remediation: () => ["Check the package name spelling", "Run pkg_search to find available packages"] },
  { test: (s) => (s.includes("not found") && s.includes("Unit")) || (s.includes("No such file") && s.includes("systemd")),
    code: "SERVICE_NOT_FOUND", category: "not_found", transient: false,
    remediation: () => ["Run svc_list to see available services", "Check if the service is installed"] },
  { test: (s) => s.includes("unmet dependencies") || s.includes("dependency problems") || s.includes("Depsolve Error"),
    code: "DEPENDENCY_CONFLICT", category: "dependency", transient: false,
    remediation: () => ["Review the dependency conflict details", "Try running with dry_run to preview"] },
  { test: (s) => s.includes("No space left on device") || s.includes("Cannot allocate memory"),
    code: "RESOURCE_EXHAUSTED", category: "resource", transient: false,
    remediation: () => ["Check disk usage with disk_usage", "Clean up temporary files or old logs"] },
  { test: (s) => s.includes("Could not get lock") || s.includes("dpkg frontend lock") || s.includes("rpm.lock"),
    code: "RESOURCE_LOCKED", category: "lock", transient: false,
    remediation: () => ["Another package manager process may be running", "Wait for it to complete, then retry"] },
  { test: (s) => s.includes("Could not resolve") || s.includes("Failed to fetch") || s.includes("Connection timed out") || s.includes("Network is unreachable"),
    code: "NETWORK_ERROR", category: "network", transient: true,
    remediation: () => ["Check network connectivity with net_test", "Verify DNS resolution with net_dns_show"] },
];

export function categorizeError(stderr: string, ctx: PluginContext): { code: string; category: ErrorCategory; transient: boolean; remediation: string[] } {
  for (const p of ERROR_PATTERNS) {
    if (p.test(stderr.toLowerCase())) {
      return { code: p.code, category: p.category, transient: p.transient, remediation: p.remediation(ctx) };
    }
  }
  return { code: "COMMAND_FAILED", category: "state", transient: false, remediation: ["Review the error output for details"] };
}

// ── Execution Helpers ──────────────────────────────────────────────

/** Execute a Command through the context's executor and return a ToolResponse. */
export async function executeCommand(ctx: PluginContext, toolName: string, command: Command, duration: DurationCategory): Promise<{ stdout: string; stderr: string; exitCode: number; durationMs: number }> {
  const timeout = ctx.config.errors.command_timeout_ceiling > 0
    ? Math.min(DURATION_TIMEOUTS[duration], ctx.config.errors.command_timeout_ceiling * 1000)
    : DURATION_TIMEOUTS[duration];
  return ctx.executor.execute(command, timeout);
}

/** Execute a bash string and return result. */
export async function executeBash(ctx: PluginContext, cmd: string, duration: DurationCategory): Promise<{ stdout: string; stderr: string; exitCode: number; durationMs: number }> {
  const timeout = ctx.config.errors.command_timeout_ceiling > 0
    ? Math.min(DURATION_TIMEOUTS[duration], ctx.config.errors.command_timeout_ceiling * 1000)
    : DURATION_TIMEOUTS[duration];
  return execBash(ctx.executor, cmd, timeout);
}

// ── Tool Registration Helper ───────────────────────────────────────

/** Register a tool on the context's registry with less boilerplate. */
export function registerTool(
  ctx: PluginContext,
  metadata: ToolMetadata,
  handler: (args: Record<string, unknown>, execCtx: ExecutionContext) => Promise<ToolResponse>,
): void {
  ctx.registry.register({ metadata, execute: handler });
}
