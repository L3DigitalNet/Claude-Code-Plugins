/**
 * ha_call_service tool - Call Home Assistant services
 *
 * Includes safety checks for dangerous operations.
 */

import { HaClient } from "../ha-client.js";
import { SafetyChecker } from "../safety.js";
import type { HaCallServiceInput, HaCallServiceOutput } from "../types.js";

export async function handleHaCallService(
  client: HaClient,
  safety: SafetyChecker,
  input: HaCallServiceInput
): Promise<HaCallServiceOutput> {
  const dryRun = input.dry_run !== false; // Default to true

  // Check safety rules
  const safetyCheck = safety.checkServiceCall(input.domain, input.service, dryRun);

  if (!safetyCheck.allowed) {
    return {
      success: false,
      dry_run: dryRun,
      error: safetyCheck.reason,
    };
  }

  // Validate the service call
  const validation = await client.validateServiceCall(
    input.domain,
    input.service,
    input.data,
    input.target
  );

  if (!validation.valid) {
    return {
      success: false,
      dry_run: dryRun,
      error: `Validation failed: ${validation.errors.join(", ")}`,
    };
  }

  // If dry run, return validation success
  if (dryRun) {
    const result: HaCallServiceOutput = {
      success: true,
      dry_run: true,
      result: {
        message: `Service ${input.domain}.${input.service} validated successfully`,
        would_target: input.target,
        would_data: safety.redactSensitiveData(input.data || {}),
      },
    };

    if (safetyCheck.warning) {
      result.result = {
        ...(result.result as Record<string, unknown>),
        warning: safetyCheck.warning,
      };
    }

    return result;
  }

  // Execute the service call
  try {
    const callResult = await client.callService(
      input.domain,
      input.service,
      input.data,
      input.target
    );

    return {
      success: true,
      dry_run: false,
      result: callResult,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return {
      success: false,
      dry_run: false,
      error: `Service call failed: ${message}`,
    };
  }
}
