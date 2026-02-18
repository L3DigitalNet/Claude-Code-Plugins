import type { RiskLevel } from "./risk.js";
import type { DistroFamily, PackageManager, FirewallBackend, MACSystem, ContainerRuntime, LogSystem, UserManagement } from "./distro.js";

/** Full plugin configuration (Section 9.2). */
export interface PluginConfig {
  integration_mode: "standalone" | "complementary" | "override";
  privilege: {
    method: "sudo";
    degrade_without_sudo: boolean;
  };
  output: {
    default_limit: number;
    log_default_limit: number;
  };
  errors: {
    max_retries: number;
    retry_backoff_seconds: number;
    command_timeout_ceiling: number;
  };
  safety: {
    confirmation_threshold: RiskLevel;
    dry_run_bypass_confirmation: boolean;
  };
  ssh: {
    keepalive_interval: number;
    keepalive_max_missed: number;
    auto_reconnect: boolean;
    max_reconnect_attempts: number;
  };
  knowledge: {
    additional_paths: string[];
    disabled_profiles: string[];
  };
  documentation: {
    repo_path: string | null;
    auto_suggest: boolean;
    commit_prefix: string;
    config_backup: {
      auto_backup_on_change: boolean;
      preserve_metadata: boolean;
    };
  };
  distro?: Partial<{
    family: DistroFamily;
    name: string;
    version: string;
    codename: string | null;
    package_manager: PackageManager;
    firewall_backend: FirewallBackend;
    mac_system: MACSystem;
    container_runtime: ContainerRuntime;
    log_system: LogSystem;
    user_management: UserManagement;
  }>;
}
