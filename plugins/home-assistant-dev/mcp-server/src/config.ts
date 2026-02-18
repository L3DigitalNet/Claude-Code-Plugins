/**
 * Configuration loading for HA Dev MCP Server
 *
 * Priority:
 * 1. Environment variables
 * 2. Config file (~/.config/ha-dev-mcp/config.json)
 * 3. Default values
 */

import { readFile } from "fs/promises";
import { homedir } from "os";
import { join } from "path";
import type { ServerConfig } from "./types.js";

const CONFIG_FILE_PATH = join(homedir(), ".config", "ha-dev-mcp", "config.json");

const DEFAULT_CONFIG: ServerConfig = {
  homeAssistant: {
    url: "",
    token: "",
    verifySsl: true,
  },
  safety: {
    allowServiceCalls: false,
    blockedServices: [
      "homeassistant.restart",
      "homeassistant.stop",
      "homeassistant.reload_all",
      "homeassistant.reload_core_config",
      "persistent_notification.dismiss_all",
      "system_log.clear",
    ],
    requireDryRun: true,
  },
  cache: {
    docsTtlHours: 24,
    statesTtlSeconds: 30,
  },
  features: {
    enableDocsTools: true,
    enableHaTools: true,
    enableValidationTools: true,
  },
};

/**
 * Load configuration from file
 */
async function loadConfigFile(): Promise<Partial<ServerConfig>> {
  try {
    const content = await readFile(CONFIG_FILE_PATH, "utf-8");
    return JSON.parse(content);
  } catch (error) {
    // Config file doesn't exist or is invalid - that's okay
    return {};
  }
}

/**
 * Load configuration from environment variables
 */
function loadEnvConfig(): Partial<ServerConfig> {
  const config: Partial<ServerConfig> = {};

  // Home Assistant connection
  if (process.env.HA_DEV_MCP_URL || process.env.HA_URL) {
    config.homeAssistant = {
      ...DEFAULT_CONFIG.homeAssistant,
      url: process.env.HA_DEV_MCP_URL || process.env.HA_URL || "",
      token: process.env.HA_DEV_MCP_TOKEN || process.env.HA_TOKEN || "",
      verifySsl: process.env.HA_DEV_MCP_VERIFY_SSL !== "false",
    };
  }

  // Safety settings
  if (process.env.HA_DEV_MCP_ALLOW_SERVICE_CALLS === "true") {
    config.safety = {
      ...DEFAULT_CONFIG.safety,
      allowServiceCalls: true,
    };
  }

  // Feature flags
  if (process.env.HA_DEV_MCP_DISABLE_HA_TOOLS === "true") {
    config.features = {
      ...DEFAULT_CONFIG.features,
      enableHaTools: false,
    };
  }

  return config;
}

/**
 * Deep merge two objects
 */
function deepMerge(target: ServerConfig, source: Partial<ServerConfig>): ServerConfig {
  const result: Record<string, unknown> = { ...target };

  for (const key of Object.keys(source) as Array<keyof ServerConfig>) {
    const sourceValue = source[key];
    const targetValue = target[key];

    if (
      sourceValue !== undefined &&
      typeof sourceValue === "object" &&
      sourceValue !== null &&
      !Array.isArray(sourceValue) &&
      typeof targetValue === "object" &&
      targetValue !== null &&
      !Array.isArray(targetValue)
    ) {
      result[key] = {
        ...targetValue,
        ...sourceValue,
      };
    } else if (sourceValue !== undefined) {
      result[key] = sourceValue;
    }
  }

  return result as unknown as ServerConfig;
}

/**
 * Load and merge all configuration sources
 */
export async function loadConfig(): Promise<ServerConfig> {
  // Load from file
  const fileConfig = await loadConfigFile();

  // Load from environment
  const envConfig = loadEnvConfig();

  // Merge: defaults <- file <- env
  let config = deepMerge(DEFAULT_CONFIG, fileConfig);
  config = deepMerge(config, envConfig);

  // Validate required fields for HA tools
  if (config.features.enableHaTools) {
    if (!config.homeAssistant.url) {
      console.error(
        "Warning: HA tools enabled but no URL configured. " +
          "Set HA_DEV_MCP_URL or configure in ~/.config/ha-dev-mcp/config.json"
      );
    }
    if (!config.homeAssistant.token) {
      console.error(
        "Warning: HA tools enabled but no token configured. " +
          "Set HA_DEV_MCP_TOKEN or configure in ~/.config/ha-dev-mcp/config.json"
      );
    }
  }

  return config;
}

/**
 * Validate configuration
 */
export function validateConfig(config: ServerConfig): string[] {
  const errors: string[] = [];

  if (config.features.enableHaTools) {
    if (!config.homeAssistant.url) {
      errors.push("Home Assistant URL is required when HA tools are enabled");
    } else {
      try {
        new URL(config.homeAssistant.url);
      } catch {
        errors.push(`Invalid Home Assistant URL: ${config.homeAssistant.url}`);
      }
    }

    if (!config.homeAssistant.token) {
      errors.push("Home Assistant token is required when HA tools are enabled");
    }
  }

  if (config.cache.docsTtlHours < 1) {
    errors.push("Docs cache TTL must be at least 1 hour");
  }

  if (config.cache.statesTtlSeconds < 5) {
    errors.push("States cache TTL must be at least 5 seconds");
  }

  return errors;
}
