import { readFileSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import type { DistroContext, DistroFamily, PackageManager, FirewallBackend, MACSystem, MACMode, ContainerRuntime, LogSystem, UserManagement } from "../types/distro.js";
import { logger } from "../logger.js";

/** Parse /etc/os-release into key-value pairs. */
function parseOsRelease(content: string): Record<string, string> {
  const result: Record<string, string> = {};
  for (const line of content.split("\n")) {
    const match = line.match(/^([A-Z_]+)=(.*)$/);
    if (match) {
      result[match[1]] = match[2].replace(/^["']|["']$/g, "");
    }
  }
  return result;
}

/** Resolve distro family from os-release fields. */
function resolveFamily(osRelease: Record<string, string>): DistroFamily {
  const idLike = (osRelease.ID_LIKE ?? "").toLowerCase();
  const id = (osRelease.ID ?? "").toLowerCase();
  if (id === "debian" || id === "ubuntu" || idLike.includes("debian") || idLike.includes("ubuntu")) return "debian";
  if (id === "fedora" || id === "rhel" || id === "centos" || id === "rocky" || id === "alma" || idLike.includes("rhel") || idLike.includes("fedora")) return "rhel";
  // Default to debian for broader compatibility
  logger.warn({ id, idLike }, "Unknown distro family — defaulting to debian");
  return "debian";
}

/** Check if a command exists on the system. */
function commandExists(cmd: string): boolean {
  try {
    execSync(`command -v ${cmd}`, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

/** Run a command and return trimmed stdout, or null on failure. */
function tryExec(cmd: string): string | null {
  try {
    return execSync(cmd, { encoding: "utf-8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return null;
  }
}

/**
 * Detect the local distro and populate DistroContext (Section 4).
 * Accepts optional overrides from config.yaml.
 */
export function detectDistro(overrides?: Partial<DistroContext>): DistroContext {
  logger.info("Starting distro detection");

  // 1. Parse /etc/os-release
  let osRelease: Record<string, string> = {};
  try {
    const content = readFileSync("/etc/os-release", "utf-8");
    osRelease = parseOsRelease(content);
  } catch {
    logger.warn("Could not read /etc/os-release — using probe-based detection");
  }

  const family = resolveFamily(osRelease);
  const packageManager: PackageManager = family === "debian" ? "apt" : "dnf";

  // 2. Detect firewall backend
  let firewall: FirewallBackend = "none";
  if (commandExists("ufw")) firewall = "ufw";
  else if (commandExists("firewall-cmd")) firewall = "firewalld";
  else if (commandExists("nft")) firewall = "nftables";

  // 3. Detect MAC system
  let macSystem: MACSystem = "none";
  let macMode: MACMode | null = null;
  const getenforce = tryExec("getenforce 2>/dev/null");
  if (getenforce && ["enforcing", "permissive", "disabled"].includes(getenforce.toLowerCase())) {
    macSystem = "selinux";
    macMode = getenforce.toLowerCase() as MACMode;
  } else if (existsSync("/sys/module/apparmor") || commandExists("aa-status")) {
    macSystem = "apparmor";
    const aaOutput = tryExec("sudo -n aa-status 2>/dev/null | head -1");
    if (aaOutput?.includes("profiles are loaded")) macMode = "enforcing";
    else if (aaOutput?.includes("complain")) macMode = "complaining";
    else macMode = "enforcing"; // default if apparmor module exists
  }

  // 4. Detect container runtime
  let containerRuntime: ContainerRuntime = "none";
  if (commandExists("docker")) containerRuntime = "docker";
  else if (commandExists("podman")) containerRuntime = "podman";

  // 5. Detect log system
  const hasJournald = commandExists("journalctl");
  const hasRsyslog = commandExists("rsyslogd");
  let logSystem: LogSystem = "journald";
  if (hasJournald && hasRsyslog) logSystem = "both";
  else if (hasRsyslog && !hasJournald) logSystem = "rsyslog";

  // 6. Detect user management
  const userMgmt: UserManagement = family === "debian" && commandExists("adduser") ? "adduser" : "useradd";

  const detected: DistroContext = {
    family,
    name: osRelease.NAME ?? osRelease.ID ?? "Unknown",
    version: osRelease.VERSION_ID ?? "unknown",
    codename: osRelease.VERSION_CODENAME ?? null,
    package_manager: packageManager,
    init_system: "systemd",
    firewall_backend: firewall,
    mac_system: macSystem,
    mac_mode: macMode,
    container_runtime: containerRuntime,
    log_system: logSystem,
    user_management: userMgmt,
  };

  // Apply config overrides (Section 4: only explicitly set fields are replaced)
  const context: DistroContext = overrides ? { ...detected, ...stripUndefined(overrides) } : detected;

  logger.info({ distro: context }, "Distro detection complete");
  return context;
}

/** Verify passwordless sudo access (Section 3.3). */
export function verifySudo(): boolean {
  try {
    execSync("sudo -n true", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function stripUndefined(obj: Record<string, unknown>): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj)) {
    if (v !== undefined) result[k] = v;
  }
  return result;
}
