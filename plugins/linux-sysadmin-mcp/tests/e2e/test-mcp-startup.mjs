/**
 * Layer 2 — MCP Server Startup Tests
 *
 * Starts the MCP server inside the linux-sysadmin-test container,
 * captures pino JSON logs from stderr, and validates 14 startup checks.
 *
 * Prerequisites:
 *   - podman container "linux-sysadmin-test" running (Fedora 43 + systemd)
 *   - /plugin/dist/server.bundle.cjs mounted inside the container
 *
 * Usage:
 *   node tests/e2e/test-mcp-startup.mjs
 */

import { execSync } from "node:child_process";

// ---------------------------------------------------------------------------
// Test harness (matches tests/unit/test-safety-gate.mjs pattern)
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
    throw new Error(
      `${msg || "Assertion failed"}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

// ---------------------------------------------------------------------------
// Run the MCP server inside the container and capture logs
// ---------------------------------------------------------------------------
const CONTAINER = "linux-sysadmin-test";
const SERVER_PATH = "/plugin/dist/server.bundle.cjs";

console.log(`\nStarting MCP server in container "${CONTAINER}"...`);

// Clean any prior config so firstRun is true
try {
  execSync(
    `podman exec ${CONTAINER} rm -f /root/.config/linux-sysadmin/config.yaml`,
    { encoding: "utf-8", timeout: 5000 }
  );
} catch {
  // Ignore — config may not exist yet
}

const startTime = Date.now();
let rawOutput;
try {
  rawOutput = execSync(
    `podman exec ${CONTAINER} timeout 3 node ${SERVER_PATH} 2>&1`,
    { encoding: "utf-8", timeout: 15000 }
  );
} catch (err) {
  // timeout exits with code 124, which causes execSync to throw —
  // but stderr/stdout are still captured in the error object
  rawOutput = (err.stdout ?? "") + (err.stderr ?? "");
  if (!rawOutput) {
    console.error("ERROR: Could not capture any output from MCP server.");
    console.error(err.message);
    process.exit(1);
  }
}
const elapsed = Date.now() - startTime;

// ---------------------------------------------------------------------------
// Parse pino JSON log lines
// ---------------------------------------------------------------------------
const lines = rawOutput.split("\n").filter((l) => l.trim().length > 0);
const logEntries = [];
const nonJsonLines = [];

for (const line of lines) {
  const trimmed = line.trim();
  if (trimmed.startsWith("{")) {
    try {
      logEntries.push(JSON.parse(trimmed));
    } catch {
      nonJsonLines.push(trimmed);
    }
  } else {
    nonJsonLines.push(trimmed);
  }
}

console.log(`Captured ${logEntries.length} pino log entries, ${nonJsonLines.length} non-JSON lines`);
console.log(`Server startup took ~${elapsed}ms (wall-clock including podman overhead)\n`);

// ---------------------------------------------------------------------------
// Helper: find a log entry by message substring
// ---------------------------------------------------------------------------
function findLog(msgSubstring) {
  return logEntries.find((e) => e.msg && e.msg.includes(msgSubstring));
}

function findAllLogs(msgSubstring) {
  return logEntries.filter((e) => e.msg && e.msg.includes(msgSubstring));
}

// ===========================================================================
// Server Lifecycle (3 tests)
// ===========================================================================
console.log("--- Server Lifecycle ---");

test("1. Server process starts without error (no fatal logs)", () => {
  // pino levels: 10=trace, 20=debug, 30=info, 40=warn, 50=error, 60=fatal
  const fatalLogs = logEntries.filter((e) => e.level >= 60);
  assertEqual(fatalLogs.length, 0, "Should have no fatal-level log entries");
});

test("2. Startup log contains 'linux-sysadmin-mcp server running on stdio'", () => {
  const entry = findLog("linux-sysadmin-mcp server running on stdio");
  assert(entry !== undefined, "Expected log message 'linux-sysadmin-mcp server running on stdio' not found");
});

test("3. Startup completes in < 5 seconds", () => {
  // Measure from first to last log timestamp (excludes podman overhead)
  assert(logEntries.length >= 2, "Need at least 2 log entries to measure duration");
  const firstTime = logEntries[0].time;
  const lastTime = logEntries[logEntries.length - 1].time;
  const duration = lastTime - firstTime;
  assert(
    duration < 5000,
    `Startup took ${duration}ms (from first to last log), expected < 5000ms`
  );
});

// ===========================================================================
// Tool Registration (3 tests)
// ===========================================================================
console.log("\n--- Tool Registration ---");

test("4. Log shows toolCount: 106", () => {
  const entry = findLog("All tool modules registered");
  assert(entry !== undefined, "Expected 'All tool modules registered' log entry not found");
  assertEqual(entry.toolCount, 106, "toolCount should be 106");
});

test("5. All 15 modules registered (toolCount >= 100)", () => {
  const entry = findLog("All tool modules registered");
  assert(entry !== undefined, "Expected 'All tool modules registered' log entry not found");
  assert(
    entry.toolCount >= 100,
    `toolCount should be >= 100 (got ${entry.toolCount})`
  );
});

test("6. No 'Duplicate tool registration' warnings", () => {
  const dupes = findAllLogs("Duplicate tool registration");
  assertEqual(
    dupes.length,
    0,
    `Found ${dupes.length} duplicate tool registration warning(s)`
  );
});

// ===========================================================================
// Distro Detection (4 tests)
// ===========================================================================
console.log("\n--- Distro Detection ---");

test("7. Detects family as 'rhel' (Fedora container)", () => {
  const entry = findLog("Distro detection complete");
  assert(entry !== undefined, "Expected 'Distro detection complete' log entry not found");
  assert(entry.distro !== undefined, "Expected distro object in log entry");
  assertEqual(entry.distro.family, "rhel", "family should be 'rhel' for Fedora");
});

test("8. Detects package_manager as 'dnf'", () => {
  const entry = findLog("Distro detection complete");
  assert(entry !== undefined, "Expected 'Distro detection complete' log entry not found");
  assertEqual(entry.distro.package_manager, "dnf", "package_manager should be 'dnf'");
});

test("9. Detects init_system as 'systemd'", () => {
  const entry = findLog("Distro detection complete");
  assert(entry !== undefined, "Expected 'Distro detection complete' log entry not found");
  assertEqual(entry.distro.init_system, "systemd", "init_system should be 'systemd'");
});

test("10. Detects firewall_backend as 'firewalld'", () => {
  const entry = findLog("Distro detection complete");
  assert(entry !== undefined, "Expected 'Distro detection complete' log entry not found");
  assertEqual(entry.distro.firewall_backend, "firewalld", "firewall_backend should be 'firewalld'");
});

// ===========================================================================
// Knowledge Base (2 tests)
// ===========================================================================
console.log("\n--- Knowledge Base ---");

test("11. Log shows 'Knowledge base loaded' with total: 8", () => {
  const entry = findLog("Knowledge base loaded");
  assert(entry !== undefined, "Expected 'Knowledge base loaded' log entry not found");
  assertEqual(entry.total, 8, "total should be 8 (8 knowledge profiles)");
});

test("12. Active profile count is reported (>= 0)", () => {
  const entry = findLog("Knowledge base loaded");
  assert(entry !== undefined, "Expected 'Knowledge base loaded' log entry not found");
  assert(
    typeof entry.active === "number" && entry.active >= 0,
    `active should be a non-negative number, got ${entry.active}`
  );
});

// ===========================================================================
// Configuration (2 tests)
// ===========================================================================
console.log("\n--- Configuration ---");

test("13. Log shows firstRun: true on initial startup", () => {
  const entry = findLog("Configuration loaded");
  assert(entry !== undefined, "Expected 'Configuration loaded' log entry not found");
  assertEqual(entry.firstRun, true, "firstRun should be true (config was cleaned before test)");
});

test("14. Config path is set and contains 'config.yaml'", () => {
  const entry = findLog("Configuration loaded");
  assert(entry !== undefined, "Expected 'Configuration loaded' log entry not found");
  assert(
    typeof entry.configPath === "string" && entry.configPath.includes("config.yaml"),
    `configPath should contain 'config.yaml', got ${JSON.stringify(entry.configPath)}`
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
