/**
 * Layer 4 — Safety Gate Unit Tests
 *
 * Tests the SafetyGate risk classification logic in isolation.
 * No system or container needed.
 */

import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = join(__dirname, "../..");
const { SafetyGate } = await import(join(PLUGIN_ROOT, "dist/safety/gate.js"));

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------
let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed = passed + 1;
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed = failed + 1;
    failures.push({ name, error: err.message });
    console.log(`  FAIL  ${name}`);
    console.log(`        ${err.message}`);
  }
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg);
}

function assertEqual(actual, expected, msg) {
  if (actual !== expected) {
    throw new Error(`${msg || "Assertion failed"}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function makeGate(threshold = "moderate", dryRunBypass = true) {
  return new SafetyGate({
    confirmation_threshold: threshold,
    dry_run_bypass_confirmation: dryRunBypass,
  });
}

function checkParams(overrides = {}) {
  return {
    toolName: "test_tool",
    toolRiskLevel: "moderate",
    targetHost: "testhost",
    command: "test command",
    description: "Test operation",
    confirmed: false,
    dryRun: false,
    ...overrides,
  };
}

// ===========================================================================
// Risk Threshold Classification (6 tests)
// ===========================================================================
console.log("\n--- Risk Threshold Classification ---");

test("1. read-only tools always pass", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "read-only" }));
  assertEqual(result, null, "read-only should return null");
});

test("2. low-risk tools pass at default threshold (moderate)", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "low" }));
  assertEqual(result, null, "low-risk should return null at moderate threshold");
});

test("3. moderate-risk triggers confirmation at moderate threshold", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "moderate" }));
  assert(result !== null, "moderate-risk should not return null at moderate threshold");
  assertEqual(result.status, "confirmation_required", "status should be confirmation_required");
});

test("4. high-risk triggers confirmation at moderate threshold", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "high" }));
  assert(result !== null, "high-risk should not return null at moderate threshold");
  assertEqual(result.status, "confirmation_required", "status should be confirmation_required");
});

test("5. critical-risk triggers confirmation at critical threshold", () => {
  const gate = makeGate("critical");
  const result = gate.check(checkParams({ toolRiskLevel: "critical" }));
  assert(result !== null, "critical-risk should not return null at critical threshold");
  assertEqual(result.status, "confirmation_required", "status should be confirmation_required");
});

test("6. moderate-risk passes when threshold set to high", () => {
  const gate = makeGate("high");
  const result = gate.check(checkParams({ toolRiskLevel: "moderate" }));
  assertEqual(result, null, "moderate-risk should return null when threshold is high");
});

// ===========================================================================
// Confirmation Bypass (3 tests)
// ===========================================================================
console.log("\n--- Confirmation Bypass ---");

test("7. confirmed: true bypasses moderate", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "moderate", confirmed: true }));
  assertEqual(result, null, "confirmed moderate should return null");
});

test("8. confirmed: true bypasses high", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "high", confirmed: true }));
  assertEqual(result, null, "confirmed high should return null");
});

test("9. confirmed: true bypasses critical", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "critical", confirmed: true }));
  assertEqual(result, null, "confirmed critical should return null");
});

// ===========================================================================
// Dry-Run Bypass (2 tests)
// ===========================================================================
console.log("\n--- Dry-Run Bypass ---");

test("10. dryRun: true bypasses when dry_run_bypass_confirmation enabled", () => {
  const gate = makeGate("moderate", true);
  const result = gate.check(checkParams({ toolRiskLevel: "high", dryRun: true }));
  assertEqual(result, null, "dry-run with bypass enabled should return null");
});

test("11. dryRun: true does NOT bypass when disabled", () => {
  const gate = makeGate("moderate", false);
  const result = gate.check(checkParams({ toolRiskLevel: "high", dryRun: true }));
  assert(result !== null, "dry-run with bypass disabled should not return null");
  assertEqual(result.status, "confirmation_required", "status should be confirmation_required");
});

// ===========================================================================
// Knowledge Profile Escalation (5 tests)
// ===========================================================================
console.log("\n--- Knowledge Profile Escalation ---");

test("12. Escalation raises moderate to high on command match", () => {
  const gate = makeGate("moderate");
  gate.addEscalations([
    { trigger: "dangerous", profileId: "prod-db", warning: "Production database!", riskLevel: "high" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "run dangerous migration",
  }));
  assert(result !== null, "escalated operation should require confirmation");
  assertEqual(result.risk_level, "high", "risk_level should be escalated to high");
});

test("13. Escalation raises moderate to critical on command match", () => {
  const gate = makeGate("moderate");
  gate.addEscalations([
    { trigger: "drop table", profileId: "prod-db", warning: "Data loss risk!", riskLevel: "critical" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "drop table users",
  }));
  assert(result !== null, "escalated operation should require confirmation");
  assertEqual(result.risk_level, "critical", "risk_level should be escalated to critical");
});

test("14. Escalation matches on serviceName field", () => {
  const gate = makeGate("moderate");
  gate.addEscalations([
    { trigger: "nginx", profileId: "web-server", warning: "Web server change!", riskLevel: "high" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "restart service",
    serviceName: "nginx",
  }));
  assert(result !== null, "serviceName-matched escalation should require confirmation");
  assertEqual(result.risk_level, "high", "risk_level should be escalated to high");
});

test("15. Non-matching escalation does not change risk level", () => {
  const gate = makeGate("high");
  gate.addEscalations([
    { trigger: "unrelated", profileId: "other", warning: "Unrelated warning", riskLevel: "critical" },
  ]);
  // moderate tool with "high" threshold, non-matching escalation -> null
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "safe operation",
  }));
  assertEqual(result, null, "non-matching escalation should not raise risk; moderate < high threshold -> null");
});

test("16. Multiple escalations - highest wins", () => {
  const gate = makeGate("moderate");
  gate.addEscalations([
    { trigger: "multi", profileId: "profile-a", warning: "High risk!", riskLevel: "high" },
    { trigger: "multi", profileId: "profile-b", warning: "Critical risk!", riskLevel: "critical" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "multi target operation",
  }));
  assert(result !== null, "escalated operation should require confirmation");
  assertEqual(result.risk_level, "critical", "highest escalation should win (critical)");
});

// ===========================================================================
// Response Shape (2 tests)
// ===========================================================================
console.log("\n--- Response Shape ---");

test("17. Confirmation response has all required fields", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({
    toolRiskLevel: "high",
    toolName: "svc_restart",
    targetHost: "prod-server",
    command: "systemctl restart nginx",
    description: "Restart nginx service",
  }));
  assert(result !== null, "should return confirmation response");

  // Top-level fields
  assertEqual(result.status, "confirmation_required", "status");
  assertEqual(result.tool, "svc_restart", "tool");
  assertEqual(result.target_host, "prod-server", "target_host");
  assert(typeof result.risk_level === "string", "risk_level should be a string");
  assert(typeof result.dry_run_available === "boolean", "dry_run_available should be a boolean");

  // Preview object
  assert(result.preview !== undefined, "preview should exist");
  assertEqual(result.preview.command, "systemctl restart nginx", "preview.command");
  assertEqual(result.preview.description, "Restart nginx service", "preview.description");
  assert(Array.isArray(result.preview.warnings), "preview.warnings should be an array");
});

test("18. Escalation reason included in preview.escalation_reason", () => {
  const gate = makeGate("moderate");
  gate.addEscalations([
    { trigger: "critical-op", profileId: "production-db", warning: "Prod DB!", riskLevel: "critical" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "run critical-op now",
  }));
  assert(result !== null, "should return confirmation response");
  assert(result.preview.escalation_reason !== undefined, "escalation_reason should be defined");
  assert(
    result.preview.escalation_reason.includes("production-db"),
    `escalation_reason should mention profileId 'production-db', got: ${result.preview.escalation_reason}`,
  );
});

// ===========================================================================
// Summary
// ===========================================================================
console.log("\n===================================");
console.log(`  Results: ${passed} passed, ${failed} failed (${passed + failed} total)`);
console.log("===================================");

if (failures.length > 0) {
  console.log("\nFailures:");
  for (const f of failures) {
    console.log(`  - ${f.name}: ${f.error}`);
  }
  process.exit(1);
}

console.log("\nAll tests passed.");
process.exit(0);
