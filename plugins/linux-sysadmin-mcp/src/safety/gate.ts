// Safety gate — intercepts every state-changing tool invocation before execution.
// Three-step classification: tool default risk → profile escalation → threshold check.
// Consumed by all tool modules via ctx.safetyGate.check(); changing threshold logic here
// affects ALL tools regardless of their own riskLevel annotation.
import type { RiskLevel } from "../types/risk.js";
import { RISK_ORDER } from "../types/risk.js";
import type { ConfirmationResponse } from "../types/response.js";
import { logger } from "../logger.js";

/** Escalation entry from a knowledge profile interaction. */
export interface Escalation {
  readonly trigger: string;
  readonly profileId: string;
  readonly warning: string;
  readonly riskLevel: RiskLevel;
}

/**
 * Safety Gate (Section 7.4).
 * Intercepts state-changing tool invocations.
 * Three-step risk classification: tool default → profile escalation → threshold check.
 */
export class SafetyGate {
  private readonly threshold: RiskLevel;
  private readonly dryRunBypass: boolean;
  private escalations: Escalation[] = [];

  constructor(config: { confirmation_threshold: RiskLevel; dry_run_bypass_confirmation: boolean }) {
    this.threshold = config.confirmation_threshold;
    this.dryRunBypass = config.dry_run_bypass_confirmation;
  }

  /** Register escalations from knowledge profiles (Section 5.4). */
  addEscalations(escalations: Escalation[]): void {
    this.escalations.push(...escalations);
  }

  /**
   * Check if an operation requires confirmation.
   * Returns null if allowed, or a ConfirmationResponse if confirmation needed.
   */
  check(params: {
    toolName: string;
    toolRiskLevel: RiskLevel;
    targetHost: string;
    command: string;
    description: string;
    confirmed?: boolean;
    dryRun?: boolean;
    serviceName?: string;
    // Whether this tool exposes a dry_run parameter. Omit or set true if yes.
    // Set false for tools that have no dry_run path (e.g., fw_enable, fw_disable).
    supportsDryRun?: boolean;
  }): ConfirmationResponse | null {
    // Dry-run bypasses confirmation (Section 7.4.3)
    if (params.dryRun && this.dryRunBypass) return null;

    // Read-only and low risk never need confirmation
    if (RISK_ORDER[params.toolRiskLevel] < RISK_ORDER["moderate"]) return null;

    // Step 1: Start with tool default
    let effectiveRisk = params.toolRiskLevel;
    let escalationReason: string | undefined;
    const warnings: string[] = [];

    // Step 2: Check profile escalations
    for (const esc of this.escalations) {
      const triggerMatch =
        params.command.includes(esc.trigger) ||
        (params.serviceName && esc.trigger.includes(params.serviceName));

      if (triggerMatch && RISK_ORDER[esc.riskLevel] > RISK_ORDER[effectiveRisk]) {
        effectiveRisk = esc.riskLevel;
        escalationReason = `Knowledge profile '${esc.profileId}' escalates from ${params.toolRiskLevel} to ${esc.riskLevel}: '${esc.warning}'`;
        warnings.push(esc.warning);
      }
    }

    // Step 3: Threshold check
    if (RISK_ORDER[effectiveRisk] < RISK_ORDER[this.threshold]) return null;

    // Already confirmed — allow
    if (params.confirmed) return null;

    logger.info({ tool: params.toolName, effectiveRisk, threshold: this.threshold }, "Confirmation required");

    return {
      status: "confirmation_required",
      tool: params.toolName,
      target_host: params.targetHost,
      // null = no command executed; 0 would be ambiguous with "ran instantly"
      duration_ms: null,
      command_executed: null,
      risk_level: effectiveRisk,
      dry_run_available: params.supportsDryRun !== false,
      preview: {
        command: params.command,
        description: params.description,
        warnings,
        affected_services: params.serviceName ? [params.serviceName] : undefined,
        escalation_reason: escalationReason,
      },
    };
  }
}
