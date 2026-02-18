/** Unified firewall rule schema (Section 6.4). */
export interface FirewallRule {
  action: "allow" | "deny" | "reject";
  direction: "in" | "out";
  port: number | string;
  protocol?: "tcp" | "udp" | "any";
  source?: string;
  destination?: string;
  comment?: string;
}

/** User creation parameters (Section 6.2). */
export interface UserCreateParams {
  username: string;
  shell?: string;
  home?: string;
  groups?: string[];
  system?: boolean;
  comment?: string;
}

/** User modification parameters (Section 6.2). */
export interface UserModifyParams {
  shell?: string;
  groups?: string[];
  append_groups?: boolean;
  lock?: boolean;
  unlock?: boolean;
  comment?: string;
}
