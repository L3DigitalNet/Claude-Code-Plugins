// Config loader — reads ~/.config/linux-sysadmin/config.yaml and deep-merges with defaults.
// On first run (no config file), generates DEFAULT_CONFIG_YAML and returns firstRun: true.
// deepMerge lets users override only the keys they specify; unset keys inherit defaults.
// Config shape is defined in src/types/config.ts — add new fields there and in DEFAULT_CONFIG.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { homedir } from "node:os";
import { parse as parseYaml } from "yaml";
import type { PluginConfig } from "../types/config.js";
import { logger } from "../logger.js";

/** Default config path per Section 9.1. */
const DEFAULT_CONFIG_DIR = join(homedir(), ".config", "linux-sysadmin");
const DEFAULT_CONFIG_PATH = join(DEFAULT_CONFIG_DIR, "config.yaml");

/** Full default configuration (Section 9.2). */
const DEFAULT_CONFIG: PluginConfig = {
  integration_mode: "complementary",
  privilege: { method: "sudo", degrade_without_sudo: true },
  output: { default_limit: 50, log_default_limit: 100 },
  errors: { max_retries: 3, retry_backoff_seconds: 2, command_timeout_ceiling: 0 },
  safety: { confirmation_threshold: "high", dry_run_bypass_confirmation: true },
  ssh: { keepalive_interval: 15, keepalive_max_missed: 3, auto_reconnect: true, max_reconnect_attempts: 3 },
  knowledge: { additional_paths: [], disabled_profiles: [] },
  documentation: {
    repo_path: null,
    auto_suggest: true,
    commit_prefix: "doc",
    config_backup: { auto_backup_on_change: true, preserve_metadata: true },
  },
};

/** Default config YAML written on first run. */
const DEFAULT_CONFIG_YAML = `# Linux SysAdmin MCP — Configuration
# Generated automatically on first run. All values shown are defaults.

# Integration mode: standalone | complementary | override
integration_mode: complementary

privilege:
  method: sudo
  degrade_without_sudo: true

output:
  default_limit: 50
  log_default_limit: 100

errors:
  max_retries: 3
  retry_backoff_seconds: 2
  command_timeout_ceiling: 0

safety:
  confirmation_threshold: high
  dry_run_bypass_confirmation: true

ssh:
  keepalive_interval: 15
  keepalive_max_missed: 3
  auto_reconnect: true
  max_reconnect_attempts: 3

knowledge:
  additional_paths: []
  disabled_profiles: []

documentation:
  repo_path: null
  auto_suggest: true
  commit_prefix: "doc"
  config_backup:
    auto_backup_on_change: true
    preserve_metadata: true

# Distro override (auto-detected if omitted)
# distro:
#   family: debian
#   package_manager: apt
#   firewall_backend: ufw
`;

export interface ConfigResult {
  config: PluginConfig;
  configPath: string;
  firstRun: boolean;
}

export function loadConfig(explicitPath?: string): ConfigResult {
  const configPath = explicitPath ?? DEFAULT_CONFIG_PATH;

  // First-run: generate default config (Section 9.1)
  if (!existsSync(configPath)) {
    logger.info({ configPath }, "No config file found — generating defaults (first run)");
    try {
      mkdirSync(dirname(configPath), { recursive: true });
      writeFileSync(configPath, DEFAULT_CONFIG_YAML, "utf-8");
    } catch (err) {
      logger.warn({ configPath, error: err }, "Could not write default config file");
    }
    return { config: { ...DEFAULT_CONFIG }, configPath, firstRun: true };
  }

  // Parse existing config
  try {
    const raw = readFileSync(configPath, "utf-8");
    const parsed = parseYaml(raw) as Partial<PluginConfig> | null;
    const config = deepMerge(DEFAULT_CONFIG as unknown as Record<string, unknown>, (parsed ?? {}) as Record<string, unknown>) as unknown as PluginConfig;
    return { config, configPath, firstRun: false };
  } catch (err) {
    logger.error({ configPath, error: err }, "Failed to parse config — using defaults");
    return { config: { ...DEFAULT_CONFIG }, configPath, firstRun: false };
  }
}

/** Deep merge b into a (a provides defaults, b overrides). */
function deepMerge(a: Record<string, unknown>, b: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = { ...a };
  for (const key of Object.keys(b)) {
    const aVal = a[key];
    const bVal = b[key];
    if (
      aVal !== null &&
      bVal !== null &&
      typeof aVal === "object" &&
      typeof bVal === "object" &&
      !Array.isArray(aVal) &&
      !Array.isArray(bVal)
    ) {
      result[key] = deepMerge(aVal as Record<string, unknown>, bVal as Record<string, unknown>);
    } else if (bVal !== undefined) {
      result[key] = bVal;
    }
  }
  return result;
}
