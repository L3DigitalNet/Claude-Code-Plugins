#!/usr/bin/env node
/**
 * Home Assistant Development MCP Server
 *
 * Provides tools for:
 * - Connecting to Home Assistant instances
 * - Querying states, services, devices
 * - Searching developer documentation
 * - Validating integration code
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

import { loadConfig } from "./config.js";
import { HaClient } from "./ha-client.js";
import { DocsIndex } from "./docs-index.js";
import { SafetyChecker } from "./safety.js";

// Import tool handlers
import { handleHaConnect } from "./tools/ha-connect.js";
import { handleHaGetStates } from "./tools/ha-states.js";
import { handleHaGetServices } from "./tools/ha-services.js";
import { handleHaCallService } from "./tools/ha-call-service.js";
import { handleHaGetDevices } from "./tools/ha-devices.js";
import { handleHaGetLogs } from "./tools/ha-logs.js";
import { handleDocsSearch } from "./tools/docs-search.js";
import { handleDocsFetch } from "./tools/docs-fetch.js";
import { handleDocsExamples } from "./tools/docs-examples.js";
import { handleValidateManifest } from "./tools/validate-manifest.js";
import { handleValidateStrings } from "./tools/validate-strings.js";
import { handleCheckPatterns } from "./tools/check-patterns.js";

import type {
  HaConnectInput,
  HaGetStatesInput,
  HaGetServicesInput,
  HaCallServiceInput,
  HaGetDevicesInput,
  HaGetLogsInput,
  DocsSearchInput,
  DocsFetchInput,
  ValidateManifestInput,
  ValidateStringsInput,
  CheckPatternsInput,
} from "./types.js";

// Tool definitions
const TOOLS: Tool[] = [
  // Home Assistant tools
  {
    name: "ha_connect",
    description: "Connect to a Home Assistant instance",
    inputSchema: {
      type: "object",
      properties: {
        url: { type: "string", description: "Home Assistant URL (e.g., http://192.168.1.100:8123)" },
        token: { type: "string", description: "Long-lived access token" },
        verify_ssl: { type: "boolean", description: "Verify SSL certificate (default: true)" },
      },
      required: ["url", "token"],
    },
  },
  {
    name: "ha_get_states",
    description: "Get entity states from connected Home Assistant instance",
    inputSchema: {
      type: "object",
      properties: {
        domain: { type: "string", description: "Filter by domain (e.g., 'sensor', 'light')" },
        entity_id: { type: "string", description: "Specific entity ID" },
        area: { type: "string", description: "Filter by area" },
      },
    },
  },
  {
    name: "ha_get_services",
    description: "List available services from connected Home Assistant instance",
    inputSchema: {
      type: "object",
      properties: {
        domain: { type: "string", description: "Filter by domain" },
      },
    },
  },
  {
    name: "ha_call_service",
    description: "Call a Home Assistant service (dry-run by default for safety)",
    inputSchema: {
      type: "object",
      properties: {
        domain: { type: "string", description: "Service domain" },
        service: { type: "string", description: "Service name" },
        data: { type: "object", description: "Service data" },
        target: {
          type: "object",
          properties: {
            entity_id: { type: ["string", "array"], description: "Target entity ID(s)" },
            device_id: { type: ["string", "array"], description: "Target device ID(s)" },
            area_id: { type: ["string", "array"], description: "Target area ID(s)" },
          },
        },
        dry_run: { type: "boolean", description: "If true (default), validate without executing" },
      },
      required: ["domain", "service"],
    },
  },
  {
    name: "ha_get_devices",
    description: "Get devices from Home Assistant device registry",
    inputSchema: {
      type: "object",
      properties: {
        manufacturer: { type: "string", description: "Filter by manufacturer" },
        model: { type: "string", description: "Filter by model" },
        integration: { type: "string", description: "Filter by integration" },
      },
    },
  },
  {
    name: "ha_get_logs",
    description: "Get Home Assistant logs",
    inputSchema: {
      type: "object",
      properties: {
        domain: { type: "string", description: "Filter by integration domain" },
        level: { type: "string", enum: ["DEBUG", "INFO", "WARNING", "ERROR"], description: "Minimum log level" },
        lines: { type: "number", description: "Number of lines to return (default: 100)" },
        since: { type: "string", description: "ISO timestamp to filter from" },
      },
    },
  },

  // Documentation tools
  {
    name: "docs_search",
    description: "Search Home Assistant developer documentation",
    inputSchema: {
      type: "object",
      properties: {
        query: { type: "string", description: "Search query" },
        section: { type: "string", enum: ["core", "frontend", "architecture", "api"], description: "Documentation section" },
        limit: { type: "number", description: "Max results (default: 5)" },
      },
      required: ["query"],
    },
  },
  {
    name: "docs_fetch",
    description: "Fetch a specific documentation page",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Documentation path (e.g., 'core/integration-quality-scale')" },
      },
      required: ["path"],
    },
  },
  {
    name: "docs_examples",
    description: "Get code examples for common patterns",
    inputSchema: {
      type: "object",
      properties: {
        pattern: {
          type: "string",
          enum: ["coordinator", "config_flow", "entity", "service", "sensor", "switch", "binary_sensor", "light", "climate"],
          description: "Pattern to get examples for",
        },
        style: { type: "string", enum: ["minimal", "full"], description: "Example complexity" },
      },
      required: ["pattern"],
    },
  },

  // Validation tools
  {
    name: "validate_manifest",
    description: "Validate a manifest.json file",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Path to manifest.json" },
        mode: { type: "string", enum: ["core", "hacs"], description: "Validation mode (default: hacs)" },
      },
      required: ["path"],
    },
  },
  {
    name: "validate_strings",
    description: "Validate strings.json and sync with config_flow.py",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "Path to strings.json" },
      },
      required: ["path"],
    },
  },
  {
    name: "check_patterns",
    description: "Check code for anti-patterns and deprecations",
    inputSchema: {
      type: "object",
      properties: {
        path: { type: "string", description: "File or directory path" },
      },
      required: ["path"],
    },
  },
];

// Server state
let haClient: HaClient | null = null;
let docsIndex: DocsIndex | null = null;
let safetyChecker: SafetyChecker | null = null;

async function main() {
  // Load configuration
  const config = await loadConfig();

  // Initialize components
  safetyChecker = new SafetyChecker(config.safety);
  docsIndex = new DocsIndex(config.cache);

  // Create MCP server
  const server = new Server(
    {
      name: "ha-dev-mcp-server",
      version: "0.1.0",
    },
    {
      capabilities: {
        tools: {},
      },
    }
  );

  // List available tools
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    const availableTools = TOOLS.filter((tool) => {
      // Filter based on enabled features
      if (tool.name.startsWith("ha_") && !config.features.enableHaTools) {
        return false;
      }
      if (tool.name.startsWith("docs_") && !config.features.enableDocsTools) {
        return false;
      }
      if (tool.name.startsWith("validate_") || tool.name === "check_patterns") {
        if (!config.features.enableValidationTools) {
          return false;
        }
      }
      return true;
    });

    return { tools: availableTools };
  });

  // Handle tool calls
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;

    try {
      switch (name) {
        // Home Assistant tools
        case "ha_connect":
          haClient = await handleHaConnect(args as unknown as HaConnectInput, config);
          return { content: [{ type: "text", text: JSON.stringify(haClient.getConnectionInfo()) }] };

        case "ha_get_states":
          if (!haClient?.isConnected()) {
            throw new Error("Not connected to Home Assistant. Use ha_connect first.");
          }
          return { content: [{ type: "text", text: JSON.stringify(await handleHaGetStates(haClient, args as unknown as HaGetStatesInput)) }] };

        case "ha_get_services":
          if (!haClient?.isConnected()) {
            throw new Error("Not connected to Home Assistant. Use ha_connect first.");
          }
          return { content: [{ type: "text", text: JSON.stringify(await handleHaGetServices(haClient, args as unknown as HaGetServicesInput)) }] };

        case "ha_call_service":
          if (!haClient?.isConnected()) {
            throw new Error("Not connected to Home Assistant. Use ha_connect first.");
          }
          return { content: [{ type: "text", text: JSON.stringify(await handleHaCallService(haClient, safetyChecker!, args as unknown as HaCallServiceInput)) }] };

        case "ha_get_devices":
          if (!haClient?.isConnected()) {
            throw new Error("Not connected to Home Assistant. Use ha_connect first.");
          }
          return { content: [{ type: "text", text: JSON.stringify(await handleHaGetDevices(haClient, args as unknown as HaGetDevicesInput)) }] };

        case "ha_get_logs":
          if (!haClient?.isConnected()) {
            throw new Error("Not connected to Home Assistant. Use ha_connect first.");
          }
          return { content: [{ type: "text", text: JSON.stringify(await handleHaGetLogs(haClient, args as unknown as HaGetLogsInput)) }] };

        // Documentation tools
        case "docs_search":
          return { content: [{ type: "text", text: JSON.stringify(await handleDocsSearch(docsIndex!, args as unknown as DocsSearchInput)) }] };

        case "docs_fetch":
          return { content: [{ type: "text", text: JSON.stringify(await handleDocsFetch(docsIndex!, args as unknown as DocsFetchInput)) }] };

        case "docs_examples":
          return { content: [{ type: "text", text: JSON.stringify(await handleDocsExamples(args as unknown as { pattern: string; style?: "minimal" | "full" })) }] };

        // Validation tools
        case "validate_manifest":
          return { content: [{ type: "text", text: JSON.stringify(await handleValidateManifest(args as unknown as ValidateManifestInput)) }] };

        case "validate_strings":
          return { content: [{ type: "text", text: JSON.stringify(await handleValidateStrings(args as unknown as ValidateStringsInput)) }] };

        case "check_patterns":
          return { content: [{ type: "text", text: JSON.stringify(await handleCheckPatterns(args as unknown as CheckPatternsInput)) }] };

        default:
          throw new Error(`Unknown tool: ${name}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        content: [{ type: "text", text: JSON.stringify({ error: message }) }],
        isError: true,
      };
    }
  });

  // Start server
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error("HA Dev MCP Server started");
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
