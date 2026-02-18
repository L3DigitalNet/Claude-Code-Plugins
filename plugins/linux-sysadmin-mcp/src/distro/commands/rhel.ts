import type { Command } from "../../types/command.js";
import type { FirewallRule, UserCreateParams, UserModifyParams } from "../../types/firewall.js";
import type { DistroCommands } from "./interface.js";

/** RHEL/Fedora command implementations. */
export class RHELCommands implements DistroCommands {
  packageInstall(packages: string[], options?: { dryRun?: boolean }): Command {
    const argv = ["sudo", "dnf", "install", "-y", ...packages];
    if (options?.dryRun) { argv[3] = "--assumeno"; argv.splice(4, 0); }
    return { argv };
  }

  packageRemove(packages: string[], options?: { purge?: boolean; dryRun?: boolean }): Command {
    const argv = ["sudo", "dnf", "remove", "-y", ...packages];
    if (options?.dryRun) { argv[3] = "--assumeno"; }
    return { argv };
  }

  packageSearch(query: string): Command {
    return { argv: ["dnf", "search", query] };
  }

  packageInfo(pkg: string): Command {
    return { argv: ["dnf", "info", pkg] };
  }

  packageListInstalled(filter?: string): Command {
    const argv = ["rpm", "-qa", "--queryformat", "%{NAME}\\t%{VERSION}-%{RELEASE}\\t%{ARCH}\\n"];
    if (filter) return { argv: ["bash", "-c", `${argv.join(" ")} | grep -i '${filter}'`] };
    return { argv };
  }

  packageCheckUpdates(): Command {
    return { argv: ["dnf", "check-update"] };
  }

  packageUpdate(packages?: string[], options?: { dryRun?: boolean }): Command {
    const argv = packages?.length
      ? ["sudo", "dnf", "upgrade", "-y", ...packages]
      : ["sudo", "dnf", "upgrade", "-y"];
    if (options?.dryRun) { argv[3] = "--assumeno"; }
    return { argv };
  }

  packageHistory(): Command {
    return { argv: ["dnf", "history", "list", "--reverse"] };
  }

  firewallStatus(): Command {
    return { argv: ["sudo", "firewall-cmd", "--state"] };
  }

  firewallListRules(): Command {
    return { argv: ["sudo", "firewall-cmd", "--list-all"] };
  }

  firewallAddRule(rule: FirewallRule, options?: { dryRun?: boolean }): Command {
    const proto = rule.protocol && rule.protocol !== "any" ? rule.protocol : "tcp";
    const ruleStr = `rule family="ipv4"${rule.source ? ` source address="${rule.source}"` : ""} port port="${rule.port}" protocol="${proto}" ${rule.action === "allow" ? "accept" : rule.action === "reject" ? "reject" : "drop"}`;
    const argv = ["sudo", "firewall-cmd", "--permanent", `--add-rich-rule=${ruleStr}`];
    // If not dry-run, also reload
    if (!options?.dryRun) {
      return { argv: ["bash", "-c", `${argv.join(" ")} && sudo firewall-cmd --reload`] };
    }
    return { argv };
  }

  firewallRemoveRule(rule: FirewallRule): Command {
    const proto = rule.protocol && rule.protocol !== "any" ? rule.protocol : "tcp";
    const ruleStr = `rule family="ipv4"${rule.source ? ` source address="${rule.source}"` : ""} port port="${rule.port}" protocol="${proto}" ${rule.action === "allow" ? "accept" : rule.action === "reject" ? "reject" : "drop"}`;
    return { argv: ["bash", "-c", `sudo firewall-cmd --permanent --remove-rich-rule='${ruleStr}' && sudo firewall-cmd --reload`] };
  }

  firewallEnable(): Command {
    return { argv: ["bash", "-c", "sudo systemctl enable --now firewalld"] };
  }

  firewallDisable(): Command {
    return { argv: ["bash", "-c", "sudo systemctl disable --now firewalld"] };
  }

  userCreate(params: UserCreateParams): Command {
    const argv = ["sudo", "useradd"];
    if (params.shell) argv.push("-s", params.shell);
    if (params.home) argv.push("-d", params.home);
    if (params.groups?.length) argv.push("-G", params.groups.join(","));
    if (params.system) argv.push("-r");
    if (params.comment) argv.push("-c", params.comment);
    argv.push("-m", params.username);
    return { argv };
  }

  userDelete(username: string, options?: { removeHome?: boolean }): Command {
    const argv = ["sudo", "userdel"];
    if (options?.removeHome) argv.push("-r");
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
