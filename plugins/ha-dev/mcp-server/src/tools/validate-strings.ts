/**
 * validate_strings tool - Validate strings.json and sync with config_flow.py
 */

import { readFile } from "fs/promises";
import { existsSync } from "fs";
import { dirname, join } from "path";
import type { ValidateStringsInput, ValidateStringsOutput } from "../types.js";

export async function handleValidateStrings(
  input: ValidateStringsInput
): Promise<ValidateStringsOutput> {
  // Check file exists
  if (!existsSync(input.path)) {
    throw new Error(`File not found: ${input.path}`);
  }

  // Parse strings.json
  let strings: Record<string, unknown>;
  try {
    const content = await readFile(input.path, "utf-8");
    strings = JSON.parse(content);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    throw new Error(`Invalid JSON in strings.json: ${message}`);
  }

  // Extract steps, errors, aborts from strings.json
  const config = strings.config as Record<string, unknown> | undefined;
  const stringSteps = new Set(
    Object.keys((config?.step as Record<string, unknown>) || {})
  );
  const stringErrors = new Set(
    Object.keys((config?.error as Record<string, unknown>) || {})
  );
  const stringAborts = new Set(
    Object.keys((config?.abort as Record<string, unknown>) || {})
  );

  // Try to load config_flow.py
  const configFlowPath = join(dirname(input.path), "config_flow.py");
  let flowSteps = new Set<string>();
  let flowErrors = new Set<string>();
  let flowAborts = new Set<string>();

  if (existsSync(configFlowPath)) {
    const flowContent = await readFile(configFlowPath, "utf-8");

    // Extract async_step_* methods
    const stepMatches = flowContent.matchAll(/async def async_step_(\w+)\s*\(/g);
    for (const match of stepMatches) {
      flowSteps.add(match[1]);
    }

    // Extract error keys: errors["base"] = "cannot_connect"
    const errorMatches = flowContent.matchAll(
      /errors\s*\[\s*["'](\w+)["']\s*\]\s*=\s*["'](\w+)["']/g
    );
    for (const match of errorMatches) {
      flowErrors.add(match[2]);
    }

    // Extract abort reasons
    const abortMatches = flowContent.matchAll(
      /async_abort\s*\(\s*reason\s*=\s*["'](\w+)["']/g
    );
    for (const match of abortMatches) {
      flowAborts.add(match[1]);
    }

    // Check for _abort_if_unique_id_configured
    if (flowContent.includes("_abort_if_unique_id_configured")) {
      flowAborts.add("already_configured");
    }
  }

  // Compare and find issues
  const internalSteps = new Set(["reauth", "reauth_confirm", "reconfigure", "reconfigure_confirm"]);

  const missingSteps: string[] = [];
  const orphanedSteps: string[] = [];
  const missingErrors: string[] = [];
  const missingDataDescriptions: string[] = [];

  // Check for missing step strings
  for (const step of flowSteps) {
    if (!stringSteps.has(step) && !internalSteps.has(step)) {
      missingSteps.push(step);
    }
  }

  // Check for orphaned step strings
  for (const step of stringSteps) {
    if (!flowSteps.has(step) && flowSteps.size > 0) {
      orphanedSteps.push(step);
    }
  }

  // Check for missing error strings
  for (const error of flowErrors) {
    if (!stringErrors.has(error)) {
      missingErrors.push(error);
    }
  }

  // Check for missing data_description (IQS Bronze requirement)
  const steps = (config?.step as Record<string, Record<string, unknown>>) || {};
  for (const [stepName, stepData] of Object.entries(steps)) {
    if (stepData.data && !stepData.data_description) {
      missingDataDescriptions.push(stepName);
    } else if (stepData.data && stepData.data_description) {
      // Check if all data keys have descriptions
      const dataKeys = new Set(Object.keys(stepData.data as Record<string, unknown>));
      const descKeys = new Set(Object.keys(stepData.data_description as Record<string, unknown>));
      for (const key of dataKeys) {
        if (!descKeys.has(key)) {
          missingDataDescriptions.push(`${stepName}.${key}`);
        }
      }
    }
  }

  // Check for missing abort strings
  const missingAborts: string[] = [];
  for (const abort of flowAborts) {
    if (!stringAborts.has(abort)) {
      missingAborts.push(abort);
    }
  }

  const valid =
    missingSteps.length === 0 &&
    missingErrors.length === 0 &&
    missingDataDescriptions.length === 0;

  return {
    valid,
    missing_steps: missingSteps,
    orphaned_steps: orphanedSteps,
    missing_errors: [...missingErrors, ...missingAborts],
    missing_data_descriptions: missingDataDescriptions,
  };
}
