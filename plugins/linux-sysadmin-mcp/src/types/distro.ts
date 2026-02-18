/** Distribution family (Section 4). */
export type DistroFamily = "debian" | "rhel";

/** Package manager resolved from distro family. */
export type PackageManager = "apt" | "dnf";

/** Init system — v1 only supports systemd. */
export type InitSystem = "systemd";

/** Firewall backend detected at runtime. */
export type FirewallBackend = "ufw" | "firewalld" | "nftables" | "none";

/** Mandatory access control system. */
export type MACSystem = "apparmor" | "selinux" | "none";

/** MAC enforcement mode. */
export type MACMode = "enforcing" | "permissive" | "complaining" | "disabled";

/** Container runtime. */
export type ContainerRuntime = "docker" | "podman" | "none";

/** Log system configuration. */
export type LogSystem = "journald" | "rsyslog" | "both";

/** Preferred user management commands. */
export type UserManagement = "adduser" | "useradd";

/**
 * Runtime distro context populated at session start (Section 4).
 * Consumed by all tool modules for command construction.
 */
export interface DistroContext {
  readonly family: DistroFamily;
  readonly name: string;
  readonly version: string;
  readonly codename: string | null;
  readonly package_manager: PackageManager;
  readonly init_system: InitSystem;
  readonly firewall_backend: FirewallBackend;
  readonly mac_system: MACSystem;
  readonly mac_mode: MACMode | null;
  readonly container_runtime: ContainerRuntime;
  readonly log_system: LogSystem;
  readonly user_management: UserManagement;
}
