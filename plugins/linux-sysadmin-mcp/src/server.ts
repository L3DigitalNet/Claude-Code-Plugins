#!/usr/bin/env node

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { hostname } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

import { logger } from "./logger.js";
import { loadConfig } from "./config/loader.js";
import { detectDistro, verifySudo } from "./distro/detector.js";
import { createDistroCommands } from "./distro/commands/factory.js";
import { LocalExecutor } from "./execution/executor.js";
import { SafetyGate } from "./safety/gate.js";
import { loadKnowledgeBase } from "./knowledge/loader.js";
import { ToolRegistry } from "./tools/registry.js";
import type { PluginContext } from "./tools/context.js";
import type { ToolResponse } from "./types/response.js";

// Tool module registrations
import { registerSessionTools } from "./tools/session/index.js";
import { registerPackageTools } from "./tools/packages/index.js";
import { registerServiceTools } from "./tools/services/index.js";
import { registerPerformanceTools } from "./tools/performance/index.js";
import { registerLogTools } from "./tools/logs/index.js";
import { registerSecurityTools } from "./tools/security/index.js";
import { registerStorageTools } from "./tools/storage/index.js";
import { registerUserTools } from "./tools/users/index.js";
import { registerFirewallTools } from "./tools/firewall/index.js";
import { registerNetworkingTools } from "./tools/networking/index.js";
import { registerContainerTools } from "./tools/containers/index.js";
import { registerCronTools } from "./tools/cron/index.js";
import { registerBackupTools } from "./tools/backup/index.js";
import { registerSSHTools } from "./tools/ssh/index.js";
import { registerDocTools } from "./tools/docs/index.js";

const __dirname = typeof import.meta?.url === "string"
  ? dirname(fileURLToPath(import.meta.url))
  : __filename ? dirname(__filename) : process.cwd();

async function main(): Promise<void> {
  logger.info("Starting linux-sysadmin-mcp server");

  // ── Phase 1: Load config ──────────────────────────────────────
  const configPath = process.env.LINUX_SYSADMIN_CONFIG ?? undefined;
  const { config, configPath: resolvedConfigPath, firstRun } = loadConfig(configPath);
  logger.info({ configPath: resolvedConfigPath, firstRun }, "Configuration loaded");

  // ── Phase 2: Detect distro ────────────────────────────────────
  const distro = detectDistro(config.distro);

  // ── Phase 3: Verify sudo ──────────────────────────────────────
  const sudoAvailable = verifySudo();
  if (!sudoAvailable && config.privilege.degrade_without_sudo) {
    logger.warn("Passwordless sudo not available — running in degraded mode (read-only tools only)");
  } else if (!sudoAvailable) {
    logger.error("Passwordless sudo required but not available — exiting");
    process.exit(1);
  }

  // ── Phase 4: Create command dispatch ──────────────────────────
  const commands = createDistroCommands(distro);

  // ── Phase 5: Create executor ──────────────────────────────────
  const executor = new LocalExecutor();

  // ── Phase 6: Get active systemd units for profile resolution ──
  let activeUnits: string[] = [];
  try {
    const { execSync } = await import("node:child_process");
    const out = execSync("systemctl list-units --type=service --state=running --no-pager --no-legend", { encoding: "utf-8", timeout: 5000 });
    activeUnits = out.trim().split("\n").map((l) => l.trim().split(/\s+/)[0] ?? "").filter(Boolean);
  } catch {
    logger.warn("Could not list active systemd units for profile resolution");
  }

  // ── Phase 7: Load knowledge base ──────────────────────────────
  const knowledgeBase = loadKnowledgeBase({
    builtinDir: join(__dirname, "..", "knowledge"),
    additionalPaths: config.knowledge.additional_paths,
    disabledIds: config.knowledge.disabled_profiles,
    activeUnitNames: activeUnits,
  });

  // ── Phase 8: Create safety gate ───────────────────────────────
  const safetyGate = new SafetyGate(config.safety);
  safetyGate.addEscalations(knowledgeBase.escalations);

  // ── Phase 9: Create tool registry and plugin context ──────────
  const registry = new ToolRegistry();
  const ctx: PluginContext = {
    config, distro, commands, executor, safetyGate, knowledgeBase, registry,
    targetHost: hostname(), sudoAvailable, isRemote: false,
    configPath: resolvedConfigPath, firstRun,
  };

  // ── Phase 10: Register all tool modules ───────────────────────
  registerSessionTools(ctx);
  registerPackageTools(ctx);
  registerServiceTools(ctx);
  registerPerformanceTools(ctx);
  registerLogTools(ctx);
  registerSecurityTools(ctx);
  registerStorageTools(ctx);
  registerUserTools(ctx);
  registerFirewallTools(ctx);
  registerNetworkingTools(ctx);
  registerContainerTools(ctx);
  registerCronTools(ctx);
  registerBackupTools(ctx);
  registerSSHTools(ctx);
  registerDocTools(ctx);

  logger.info({ toolCount: registry.size }, "All tool modules registered");

  // ── Phase 11: Create MCP server ───────────────────────────────
  const server = new McpServer({
    name: "linux-sysadmin-mcp",
    version: "0.1.0",
  });

  // ── Phase 12: Register tools on MCP server ────────────────────
  for (const [name, tool] of registry.getAll()) {
    const meta = tool.metadata;

    // Build Zod input schema with proper shape
    const inputShape: Record<string, z.ZodType> = {};
    if (meta.inputSchema instanceof z.ZodObject) {
      const shape = (meta.inputSchema as z.ZodObject<z.ZodRawShape>).shape;
      for (const [key, value] of Object.entries(shape)) {
        inputShape[key] = value as z.ZodType;
      }
    }

    server.registerTool(
      name,
      {
        title: name,
        description: meta.description,
        inputSchema: inputShape,
        annotations: {
          readOnlyHint: meta.annotations?.readOnlyHint ?? meta.riskLevel === "read-only",
          destructiveHint: meta.annotations?.destructiveHint ?? false,
          idempotentHint: meta.annotations?.idempotentHint ?? false,
          openWorldHint: meta.annotations?.openWorldHint ?? false,
        },
      },
      async (args: Record<string, unknown>) => {
        try {
          const response: ToolResponse = await tool.execute(args, {
            targetHost: ctx.targetHost,
            isRemote: ctx.isRemote,
          });

          return {
            content: [{ type: "text" as const, text: JSON.stringify(response, null, 2) }],
          };
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          logger.error({ tool: name, error: message }, "Tool execution error");
          return {
            content: [{
              type: "text" as const,
              text: JSON.stringify({
                status: "error",
                tool: name,
                target_host: ctx.targetHost,
                duration_ms: 0,
                command_executed: null,
                error_code: "INTERNAL_ERROR",
                error_category: "state",
                message,
                transient: false,
                retried: false,
                retry_count: 0,
                remediation: ["Check server logs for details"],
              }),
            }],
          };
        }
      },
    );
  }

  // ── Phase 13: Connect transport ───────────────────────────────
  const transport = new StdioServerTransport();
  await server.connect(transport);
  logger.info({ tools: registry.size, host: hostname() }, "linux-sysadmin-mcp server running on stdio");
}

main().catch((err) => {
  logger.fatal({ error: err }, "Fatal startup error");
  process.exit(1);
});
