/**
 * Safety Checker for Home Assistant Service Calls
 *
 * Prevents dangerous operations and enforces dry-run mode.
 */

import type { ServerConfig } from "./types.js";

export class SafetyChecker {
  private config: ServerConfig["safety"];

  // Services that are always blocked regardless of configuration
  private readonly ALWAYS_BLOCKED = new Set([
    "homeassistant.stop",
    "hassio.host_shutdown",
    "hassio.host_reboot",
  ]);

  // Services that modify system state significantly
  private readonly DANGEROUS_SERVICES = new Set([
    "homeassistant.restart",
    "homeassistant.reload_all",
    "homeassistant.reload_core_config",
    "homeassistant.reload_config_entry",
    "recorder.purge",
    "recorder.purge_entities",
    "system_log.clear",
    "logbook.log", // Could be used to inject fake events
  ]);

  // Domains that are generally safe for testing
  private readonly SAFE_DOMAINS = new Set([
    "input_boolean",
    "input_number",
    "input_select",
    "input_text",
    "input_datetime",
    "input_button",
    "counter",
    "timer",
    "persistent_notification",
  ]);

  constructor(config: ServerConfig["safety"]) {
    this.config = config;
  }

  /**
   * Check if a service call is allowed
   */
  checkServiceCall(
    domain: string,
    service: string,
    dryRun: boolean
  ): { allowed: boolean; reason?: string; warning?: string } {
    const fullService = `${domain}.${service}`;

    // Always block certain dangerous services
    if (this.ALWAYS_BLOCKED.has(fullService)) {
      return {
        allowed: false,
        reason: `Service ${fullService} is always blocked for safety`,
      };
    }

    // Check configured blocklist
    for (const blocked of this.config.blockedServices) {
      if (blocked.includes("*")) {
        // Wildcard pattern
        const pattern = blocked.replace("*", ".*");
        if (new RegExp(`^${pattern}$`).test(fullService)) {
          return {
            allowed: false,
            reason: `Service ${fullService} matches blocked pattern ${blocked}`,
          };
        }
      } else if (fullService === blocked) {
        return {
          allowed: false,
          reason: `Service ${fullService} is in the blocked list`,
        };
      }
    }

    // Check if service calls are allowed at all
    if (!this.config.allowServiceCalls) {
      return {
        allowed: false,
        reason:
          "Service calls are disabled. Set allowServiceCalls: true in config to enable.",
      };
    }

    // Check dry-run requirement
    if (this.config.requireDryRun && !dryRun) {
      // Safe domains can bypass dry-run requirement
      if (!this.SAFE_DOMAINS.has(domain)) {
        return {
          allowed: false,
          reason:
            "Dry-run mode is required. Set dry_run: false explicitly to execute, " +
            "or disable requireDryRun in config.",
        };
      }
    }

    // Warn about dangerous services even if allowed
    if (this.DANGEROUS_SERVICES.has(fullService)) {
      return {
        allowed: true,
        warning: `Service ${fullService} can modify system state significantly`,
      };
    }

    return { allowed: true };
  }

  /**
   * Get a summary of safety settings
   */
  getSafetyInfo(): {
    serviceCallsEnabled: boolean;
    dryRunRequired: boolean;
    blockedCount: number;
  } {
    return {
      serviceCallsEnabled: this.config.allowServiceCalls,
      dryRunRequired: this.config.requireDryRun,
      blockedCount: this.config.blockedServices.length + this.ALWAYS_BLOCKED.size,
    };
  }

  /**
   * Check if a domain is considered safe for testing
   */
  isSafeDomain(domain: string): boolean {
    return this.SAFE_DOMAINS.has(domain);
  }

  /**
   * Redact sensitive data from service call data
   */
  redactSensitiveData(data: Record<string, unknown>): Record<string, unknown> {
    const sensitiveKeys = new Set([
      "password",
      "token",
      "api_key",
      "secret",
      "credential",
      "auth",
    ]);

    const redacted: Record<string, unknown> = {};

    for (const [key, value] of Object.entries(data)) {
      const lowerKey = key.toLowerCase();
      const isSensitive = Array.from(sensitiveKeys).some((s) =>
        lowerKey.includes(s)
      );

      if (isSensitive) {
        redacted[key] = "**REDACTED**";
      } else if (typeof value === "object" && value !== null) {
        redacted[key] = this.redactSensitiveData(value as Record<string, unknown>);
      } else {
        redacted[key] = value;
      }
    }

    return redacted;
  }
}
