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
  // Return a structured invalid result for file/JSON errors (matching the Python twin
  // and validate-manifest), rather than throwing.
  const failure = (message: string): ValidateStringsOutput => ({
    valid: false,
    errors: [message],
    missing_steps: [],
    orphaned_steps: [],
    missing_errors: [],
    missing_data_descriptions: [],
  });

  // Check file exists
  if (!existsSync(input.path)) {
    return failure(`strings.json not found: ${input.path}`);
  }

  // Parse strings.json
  let strings: Record<string, unknown>;
  try {
    const content = await readFile(input.path, "utf-8");
    strings = JSON.parse(content);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return failure(`Invalid JSON in strings.json: ${message}`);
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
  const flowSteps = new Set<string>();
  const flowErrors = new Set<string>();
  const flowAborts = new Set<string>();

  if (existsSync(configFlowPath)) {
    const flowContent = await readFile(configFlowPath, "utf-8");

    // Extract async_step_* methods
    const stepMatches = flowContent.matchAll(/async def async_step_(\w+)\s*\(/g);
    for (const match of stepMatches) {
      flowSteps.add(match[1]);
    }

    // Extract error keys: errors["base"] = "cannot_connect"
    // LIMITATION (literal-only): this matches only string-LITERAL assignments. Common
    // real-world forms — errors["base"] = err_key (variable) or dict comprehensions —
    // are silently missed, so those error keys cannot be cross-checked against strings.json
    // and may produce a false 'valid'. Broadening this safely requires real Python parsing.
    const errorMatches = flowContent.matchAll(
      /errors\s*\[\s*["'](\w+)["']\s*\]\s*=\s*["'](\w+)["']/g
    );
    for (const match of errorMatches) {
      flowErrors.add(match[2]);
    }

    // Extract abort reasons: both keyword (async_abort(reason="x")) and positional
    // (async_abort("x") / self.async_abort('x')) forms. Same literal-only caveat as
    // errors above — a variable-supplied reason is not captured.
    const abortMatches = flowContent.matchAll(
      /async_abort\s*\(\s*(?:reason\s*=\s*)?["'](\w+)["']/g
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
  // A hand-edited but still-parseable strings.json can place a non-object under a step
  // (e.g. "user": null or a string). Object.keys(null) throws, so guard the step entry
  // and each sub-field with object checks: a malformed step is reported as a structured
  // error instead of crashing the tool (PURPOSE 3: no crash on malformed input).
  const malformedSteps: string[] = [];
  const steps = (config?.step as Record<string, unknown>) || {};
  const isObject = (v: unknown): v is Record<string, unknown> =>
    typeof v === "object" && v !== null && !Array.isArray(v);
  for (const [stepName, rawStepData] of Object.entries(steps)) {
    if (!isObject(rawStepData)) {
      malformedSteps.push(`config.step.${stepName} must be an object`);
      continue;
    }
    const stepData = rawStepData;
    const data = stepData.data;
    const dataDescription = stepData.data_description;
    if (isObject(data) && !isObject(dataDescription)) {
      missingDataDescriptions.push(stepName);
    } else if (isObject(data) && isObject(dataDescription)) {
      // Check if all data keys have descriptions
      const dataKeys = new Set(Object.keys(data));
      const descKeys = new Set(Object.keys(dataDescription));
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

  // Aborts are reported under missing_errors, so they must also count toward validity.
  // Malformed (non-object) step entries are surfaced here too, so a parseable-but-bad
  // strings.json yields a structured validation error rather than a thrown exception.
  const allMissingErrors = [...missingErrors, ...missingAborts, ...malformedSteps];

  const valid =
    missingSteps.length === 0 &&
    allMissingErrors.length === 0 &&
    missingDataDescriptions.length === 0;

  return {
    valid,
    missing_steps: missingSteps,
    orphaned_steps: orphanedSteps,
    missing_errors: allMissingErrors,
    missing_data_descriptions: missingDataDescriptions,
  };
}
