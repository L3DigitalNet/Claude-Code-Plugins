/**
 * validate_manifest tool - Validate manifest.json
 */

import { readFile } from "fs/promises";
import { existsSync } from "fs";
import type { ValidateManifestInput, ValidateManifestOutput, ValidationError } from "../types.js";

const CORE_REQUIRED = new Set([
  "domain",
  "name",
  "codeowners",
  "documentation",
  "integration_type",
  "iot_class",
]);

const HACS_REQUIRED = new Set([
  ...CORE_REQUIRED,
  "version",
  "issue_tracker",
]);

const VALID_INTEGRATION_TYPES = new Set([
  "device",
  "entity",
  "hardware",
  "helper",
  "hub",
  "service",
  "system",
  "virtual",
]);

const VALID_IOT_CLASSES = new Set([
  "assumed_state",
  "cloud_polling",
  "cloud_push",
  "local_polling",
  "local_push",
  "calculated",
]);

const SEMVER_PATTERN = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([\da-zA-Z-]+(?:\.[\da-zA-Z-]+)*))?(?:\+([\da-zA-Z-]+(?:\.[\da-zA-Z-]+)*))?$/;
const DOMAIN_PATTERN = /^[a-z][a-z0-9_]*$/;

export async function handleValidateManifest(
  input: ValidateManifestInput
): Promise<ValidateManifestOutput> {
  const errors: ValidationError[] = [];
  const warnings: ValidationError[] = [];
  const isHacs = input.mode !== "core";

  // Check file exists
  if (!existsSync(input.path)) {
    return {
      valid: false,
      errors: [{ field: "file", message: `File not found: ${input.path}`, severity: "error" }],
      warnings: [],
    };
  }

  // Parse JSON
  let manifest: Record<string, unknown>;
  try {
    const content = await readFile(input.path, "utf-8");
    manifest = JSON.parse(content);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return {
      valid: false,
      errors: [{ field: "json", message: `Invalid JSON: ${message}`, severity: "error" }],
      warnings: [],
    };
  }

  // Check required fields
  const required = isHacs ? HACS_REQUIRED : CORE_REQUIRED;
  for (const field of required) {
    if (!(field in manifest)) {
      errors.push({
        field,
        message: `Missing required field '${field}'`,
        severity: "error",
      });
    }
  }

  // Validate domain
  if (typeof manifest.domain === "string") {
    if (!DOMAIN_PATTERN.test(manifest.domain)) {
      errors.push({
        field: "domain",
        message: `Invalid domain '${manifest.domain}'. Must be lowercase with underscores only.`,
        severity: "error",
      });
    }

    // Check domain matches directory
    const pathParts = input.path.split(/[/\\]/);
    const dirName = pathParts[pathParts.length - 2];
    if (dirName && manifest.domain !== dirName) {
      warnings.push({
        field: "domain",
        message: `Domain '${manifest.domain}' does not match directory name '${dirName}'`,
        severity: "warning",
      });
    }
  }

  // Validate integration_type
  if (typeof manifest.integration_type === "string") {
    if (!VALID_INTEGRATION_TYPES.has(manifest.integration_type)) {
      errors.push({
        field: "integration_type",
        message: `Invalid integration_type '${manifest.integration_type}'. Must be one of: ${[...VALID_INTEGRATION_TYPES].join(", ")}`,
        severity: "error",
      });
    }
  }

  // Validate iot_class
  if (typeof manifest.iot_class === "string") {
    if (!VALID_IOT_CLASSES.has(manifest.iot_class)) {
      errors.push({
        field: "iot_class",
        message: `Invalid iot_class '${manifest.iot_class}'. Must be one of: ${[...VALID_IOT_CLASSES].join(", ")}`,
        severity: "error",
      });
    }
  }

  // Validate version (for HACS)
  if (isHacs && typeof manifest.version === "string") {
    if (!SEMVER_PATTERN.test(manifest.version)) {
      errors.push({
        field: "version",
        message: `Invalid version '${manifest.version}'. Must be valid semver (e.g., 1.0.0)`,
        severity: "error",
      });
    }
  }

  // Validate codeowners
  if (Array.isArray(manifest.codeowners)) {
    if (manifest.codeowners.length === 0) {
      warnings.push({
        field: "codeowners",
        message: "Should have at least one codeowner",
        severity: "warning",
      });
    } else {
      for (const owner of manifest.codeowners) {
        if (typeof owner === "string" && !owner.startsWith("@")) {
          errors.push({
            field: "codeowners",
            message: `Codeowner '${owner}' must start with '@'`,
            severity: "error",
          });
        }
      }
    }
  }

  // Validate URLs
  for (const urlField of ["documentation", "issue_tracker"]) {
    const url = manifest[urlField];
    if (typeof url === "string" && url) {
      if (!url.startsWith("http://") && !url.startsWith("https://")) {
        errors.push({
          field: urlField,
          message: `Invalid URL: ${url}`,
          severity: "error",
        });
      }
    }
  }

  // Check config_flow
  if (manifest.config_flow !== true && manifest.integration_type !== "virtual") {
    warnings.push({
      field: "config_flow",
      message: "Config flow is not enabled. New integrations require config_flow: true",
      severity: "warning",
    });
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}
