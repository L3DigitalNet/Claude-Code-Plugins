import type { Command } from "../../types/command.js";
import type { FirewallRule, UserCreateParams, UserModifyParams } from "../../types/firewall.js";

/**
 * Distro-specific command dispatch interface (Section 4).
 * Tool modules call these methods to express intent;
 * implementations translate to distro-specific commands.
 */
export interface DistroCommands {
  // Package management
  packageInstall(packages: string[], options?: { dryRun?: boolean }): Command;
  packageRemove(packages: string[], options?: { purge?: boolean; dryRun?: boolean }): Command;
  packageSearch(query: string): Command;
  packageInfo(pkg: string): Command;
  packageListInstalled(filter?: string): Command;
  packageCheckUpdates(): Command;
  packageUpdate(packages?: string[], options?: { dryRun?: boolean }): Command;
  packageHistory(): Command;

  // Firewall
  firewallStatus(): Command;
  firewallListRules(): Command;
  firewallAddRule(rule: FirewallRule, options?: { dryRun?: boolean }): Command;
  firewallRemoveRule(rule: FirewallRule): Command;
  firewallEnable(): Command;
  firewallDisable(): Command;

  // User management
  userCreate(params: UserCreateParams): Command;
  userDelete(username: string, options?: { removeHome?: boolean }): Command;
  userModify(username: string, params: UserModifyParams): Command;

  // Service management (shared systemctl — included for completeness)
  serviceControl(unit: string, action: "start" | "stop" | "restart" | "reload" | "enable" | "disable"): Command;
  serviceStatus(unit: string): Command;
}
