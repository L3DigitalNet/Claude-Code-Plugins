import { readFileSync, readdirSync, existsSync } from "node:fs";
import { join, basename } from "node:path";
import { parse as parseYaml } from "yaml";
import type { Escalation } from "../safety/gate.js";
import { logger } from "../logger.js";

/** Schema for a knowledge profile (Section 5.2). */
export interface KnowledgeProfile {
  id: string;
  name: string;
  schema_version: number;
  version_notes?: string;
  category: string;
  homepage?: string;
  service: {
    unit_names: string[];
    type?: string;
    restart_command?: string;
    reload_command?: string;
    reload_notes?: string;
  };
  config: {
    primary: string;
    additional?: Array<{ path: string; description: string; mutable?: boolean }>;
    validate_command?: string | null;
    backup_paths?: string[];
  };
  logs?: Array<{ path?: string; journald_unit?: string; description?: string }>;
  ports?: Array<{ port: number; protocol: string; scope: string; description: string }>;
  health_checks?: Array<{ command: string; description: string; expect_exit?: number; expect_output?: boolean | string; expect_contains?: string }>;
  cli_tools?: Array<{ command: string; subcommands: string[] }>;
  dependencies?: {
    requires?: Array<{ role: string; reason: string; impact_if_down: string; typical_services?: string[] }>;
    required_by?: Array<{ role: string; reason: string }>;
  };
  interactions?: Array<{ trigger: string; warning: string; risk_escalation?: string | null }>;
  troubleshooting?: Array<{ symptom: string; checks: string[]; common_causes: string[] }>;
}

/** Resolved profile with runtime status. */
export interface ResolvedProfile {
  profile: KnowledgeProfile;
  status: "active" | "inactive" | "error";
  rolesResolved: Record<string, string>;
  unresolved_roles: string[];
  error?: string;
}

/** Knowledge base state. */
export interface KnowledgeBase {
  readonly profiles: Map<string, KnowledgeProfile>;
  readonly resolved: ResolvedProfile[];
  readonly escalations: Escalation[];
  /** Profiles that failed to parse — surfaced in sysadmin_session_info so users can fix syntax errors. */
  readonly loadErrors: readonly string[];
  getProfile(id: string): KnowledgeProfile | undefined;
  getActiveProfiles(): ResolvedProfile[];
}

interface LoadOptions {
  builtinDir: string;
  additionalPaths: string[];
  disabledIds: string[];
  activeUnitNames: string[];
}

/** Load all profiles and resolve against running services (Section 5.5). */
export function loadKnowledgeBase(options: LoadOptions): KnowledgeBase {
  const profiles = new Map<string, KnowledgeProfile>();
  const errors: string[] = [];

  // 1. Load built-in profiles
  loadProfilesFromDir(options.builtinDir, profiles, errors);

  // 2. Load user profiles (override built-ins with same id)
  for (const dir of options.additionalPaths) {
    if (existsSync(dir)) loadProfilesFromDir(dir, profiles, errors);
  }

  // 3. Remove disabled profiles
  for (const id of options.disabledIds) profiles.delete(id);

  // 4. Resolve profiles against active units (Section 5.5)
  const activeSet = new Set(options.activeUnitNames);
  const resolved: ResolvedProfile[] = [];
  const activeProfileIds = new Set<string>();

  for (const [id, profile] of profiles) {
    const isActive = profile.service.unit_names.some((u) => activeSet.has(u));
    if (isActive) activeProfileIds.add(id);

    resolved.push({
      profile,
      status: isActive ? "active" : "inactive",
      rolesResolved: {},
      unresolved_roles: [],
    });
  }

  // 5. Resolve abstract roles (Section 5.5 step 4)
  for (const r of resolved) {
    if (r.status !== "active") continue;
    const deps = r.profile.dependencies?.requires ?? [];
    for (const dep of deps) {
      const filler = dep.typical_services?.find((s) => {
        // Check if any profile with this service id is active
        return activeProfileIds.has(s);
      });
      if (filler) {
        r.rolesResolved[dep.role] = filler;
      } else {
        r.unresolved_roles.push(dep.role);
      }
    }
  }

  // 6. Extract escalations from active profile interactions
  const escalations: Escalation[] = [];
  for (const r of resolved) {
    if (r.status !== "active") continue;
    for (const interaction of r.profile.interactions ?? []) {
      if (interaction.risk_escalation) {
        escalations.push({
          trigger: interaction.trigger,
          profileId: r.profile.id,
          warning: interaction.warning,
          riskLevel: interaction.risk_escalation as "low" | "moderate" | "high" | "critical",
        });
      }
    }
  }

  logger.info({
    total: profiles.size,
    active: resolved.filter((r) => r.status === "active").length,
    escalations: escalations.length,
  }, "Knowledge base loaded");

  return {
    profiles,
    resolved,
    escalations,
    loadErrors: errors,
    getProfile: (id) => profiles.get(id),
    getActiveProfiles: () => resolved.filter((r) => r.status === "active"),
  };
}

function loadProfilesFromDir(
  dir: string,
  profiles: Map<string, KnowledgeProfile>,
  errors: string[],
): void {
  if (!existsSync(dir)) return;
  try {
    const files = readdirSync(dir).filter((f) => f.endsWith(".yaml") || f.endsWith(".yml"));
    for (const file of files) {
      try {
        const content = readFileSync(join(dir, file), "utf-8");
        const profile = parseYaml(content) as KnowledgeProfile;
        // Basic validation (Section 5.6)
        if (!profile.id || !profile.name || !profile.service?.unit_names?.length) {
          errors.push(`${file}: missing required fields (id, name, service.unit_names)`);
          continue;
        }
        profiles.set(profile.id, profile);
      } catch (err) {
        errors.push(`${file}: ${err instanceof Error ? err.message : String(err)}`);
      }
    }
  } catch {
    logger.warn({ dir }, "Could not read knowledge directory");
  }
}
