import type { Command } from "../../types/command.js";
import type { FirewallRule, UserCreateParams, UserModifyParams } from "../../types/firewall.js";
import type { DistroCommands } from "./interface.js";

/** Debian/Ubuntu command implementations. */
export class DebianCommands implements DistroCommands {
  private readonly env = { DEBIAN_FRONTEND: "noninteractive" };

  packageInstall(packages: string[], options?: { dryRun?: boolean }): Command {
    const argv = ["sudo", "apt", "install", "-y", ...packages];
    if (options?.dryRun) argv.splice(3, 0, "--dry-run");
    return { argv, env: this.env };
  }

  packageRemove(packages: string[], options?: { purge?: boolean; dryRun?: boolean }): Command {
    const cmd = options?.purge ? "purge" : "remove";
    const argv = ["sudo", "apt", cmd, "-y", ...packages];
    if (options?.dryRun) argv.splice(3, 0, "--dry-run");
    return { argv, env: this.env };
  }

  packageSearch(query: string): Command {
    return { argv: ["apt", "search", query] };
  }

  packageInfo(pkg: string): Command {
    return { argv: ["apt", "show", pkg] };
  }

  packageListInstalled(filter?: string): Command {
    const argv = ["dpkg-query", "-W", "-f", "${Package}\\t${Version}\\t${Architecture}\\t${Status}\\n"];
    if (filter) return { argv: ["bash", "-c", `${argv.join(" ")} | grep -i '${filter}'`] };
    return { argv };
  }

  packageCheckUpdates(): Command {
    return { argv: ["apt", "list", "--upgradable"], env: this.env };
  }

  packageUpdate(packages?: string[], options?: { dryRun?: boolean }): Command {
    const argv = packages?.length
      ? ["sudo", "apt", "install", "--only-upgrade", "-y", ...packages]
      : ["sudo", "apt", "upgrade", "-y"];
    if (options?.dryRun) argv.splice(3, 0, "--dry-run");
    return { argv, env: this.env };
  }

  packageHistory(): Command {
    return { argv: ["bash", "-c", "cat /var/log/apt/history.log | tail -200"] };
  }

  firewallStatus(): Command {
    return { argv: ["sudo", "ufw", "status", "verbose"] };
  }

  firewallListRules(): Command {
    return { argv: ["sudo", "ufw", "status", "numbered"] };
  }

  firewallAddRule(rule: FirewallRule, options?: { dryRun?: boolean }): Command {
    const argv = ["sudo", "ufw"];
    if (options?.dryRun) argv.push("--dry-run");
    argv.push(rule.action, rule.direction);
    if (rule.source) argv.push("from", rule.source);
    if (rule.destination) argv.push("to", rule.destination);
    argv.push("port", String(rule.port));
    if (rule.protocol && rule.protocol !== "any") argv.push("proto", rule.protocol);
    if (rule.comment) argv.push("comment", rule.comment);
    return { argv };
  }

  firewallRemoveRule(rule: FirewallRule): Command {
    const argv = ["sudo", "ufw", "delete", rule.action, rule.direction];
    if (rule.source) argv.push("from", rule.source);
    argv.push("port", String(rule.port));
    if (rule.protocol && rule.protocol !== "any") argv.push("proto", rule.protocol);
    return { argv };
  }

  firewallEnable(): Command { return { argv: ["sudo", "ufw", "--force", "enable"] }; }
  firewallDisable(): Command { return { argv: ["sudo", "ufw", "disable"] }; }

  userCreate(params: UserCreateParams): Command {
    const argv = ["sudo", "adduser", "--disabled-password", "--gecos", params.comment ?? ""];
    if (params.shell) argv.push("--shell", params.shell);
    if (params.home) argv.push("--home", params.home);
    if (params.system) argv.push("--system");
    argv.push(params.username);
    return { argv };
  }

  userDelete(username: string, options?: { removeHome?: boolean }): Command {
    const argv = ["sudo", "deluser"];
    if (options?.removeHome) argv.push("--remove-home");
    argv.push(username);
    return { argv };
  }

  userModify(username: string, params: UserModifyParams): Command {
    const argv = ["sudo", "usermod"];
    if (params.shell) argv.push("-s", params.shell);
    if (params.groups?.length) {
      argv.push(params.append_groups !== false ? "-aG" : "-G", params.groups.join(","));
    }
    if (params.lock) argv.push("-L");
    if (params.unlock) argv.push("-U");
    if (params.comment) argv.push("-c", params.comment);
    argv.push(username);
    return { argv };
  }

  serviceControl(unit: string, action: "start" | "stop" | "restart" | "reload" | "enable" | "disable"): Command {
    return { argv: ["sudo", "systemctl", action, unit] };
  }

  serviceStatus(unit: string): Command {
    return { argv: ["systemctl", "status", unit, "--no-pager"] };
  }
}
