// MCP Server WebSocket integration tests
// Tests the actual HaClient and SafetyChecker classes against live HA

import { readFile } from "fs/promises";
import { writeFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// Resolve MCP dist relative to this test file
const MCP_DIST = join(new URL(".", import.meta.url).pathname, "../../mcp-server/dist");

const results = [];
function record(name, pass, detail = "") {
  results.push({ name, pass, detail });
  console.log(`${pass ? "PASS" : "FAIL"} | ${name}${detail ? " — " + detail : ""}`);
}

async function main() {
  const { HaClient } = await import(join(MCP_DIST, "ha-client.js"));
  const { SafetyChecker } = await import(join(MCP_DIST, "safety.js"));
  const { loadConfig } = await import(join(MCP_DIST, "config.js"));

  const config = await loadConfig();
  const client = new HaClient(config);
  const safety = new SafetyChecker(config.safety);

  console.log("\n=== MCP Server HaClient Tests (WebSocket) ===\n");

  // Test 1: WebSocket Connect
  let connectInfo;
  try {
    connectInfo = await client.connect(config.homeAssistant.url, config.homeAssistant.token);
    record("WS Connect: connected", connectInfo.connected);
    record("WS Connect: version", !!connectInfo.version, `v${connectInfo.version}`);
    record("WS Connect: location", !!connectInfo.location, connectInfo.location);
    record("WS Connect: components", connectInfo.components.length > 0,
      `${connectInfo.components.length} components`);
    record("WS Connect: demo loaded", connectInfo.components.includes("demo"));
    record("WS Connect: isConnected()", client.isConnected());
  } catch (e) {
    record("WS Connect", false, e.message);
    console.error("\nFatal: Cannot connect to HA. Aborting.");
    process.exit(1);
  }

  // Wait a moment for entity subscription to populate cache
  await new Promise(resolve => setTimeout(resolve, 2000));

  // Test 2: getStates — all
  try {
    const allStates = await client.getStates();
    record("getStates: all entities", allStates.length > 0, `${allStates.length} entities`);

    // Verify state shape
    const sample = allStates[0];
    record("getStates: has entity_id", !!sample?.entity_id, sample?.entity_id);
    record("getStates: has state", sample?.state !== undefined, `state: ${sample?.state}`);
    record("getStates: has attributes", !!sample?.attributes);
    record("getStates: has last_changed", !!sample?.last_changed);
  } catch (e) {
    record("getStates: all", false, e.message);
  }

  // Test 3: getStates — domain filter
  try {
    const sensors = await client.getStates({ domain: "sensor" });
    record("getStates: domain=sensor", sensors.length > 0, `${sensors.length} sensors`);
    const allSensor = sensors.every(s => s.entity_id.startsWith("sensor."));
    record("getStates: domain filter correct", allSensor);
  } catch (e) {
    record("getStates: domain filter", false, e.message);
  }

  // Test 4: getStates — entity filter
  try {
    const specific = await client.getStates({ entityId: "light.bed_light" });
    record("getStates: entity=light.bed_light", specific.length === 1,
      `state: ${specific[0]?.state}`);
    record("getStates: entity attributes", !!specific[0]?.attributes?.friendly_name,
      specific[0]?.attributes?.friendly_name);
  } catch (e) {
    record("getStates: entity filter", false, e.message);
  }

  // Test 5: getServices — all
  try {
    const allServices = await client.getServices();
    record("getServices: all", allServices.length > 0, `${allServices.length} services`);

    // Verify service shape
    const sample = allServices.find(s => s.domain === "light" && s.service === "turn_on");
    record("getServices: light.turn_on found", !!sample);
    record("getServices: has description", !!sample?.description);
    record("getServices: has fields", !!sample?.fields);
  } catch (e) {
    record("getServices: all", false, e.message);
  }

  // Test 6: getServices — domain filter
  try {
    const lightServices = await client.getServices("light");
    record("getServices: domain=light", lightServices.length > 0,
      lightServices.map(s => s.service).join(", "));
    const allLight = lightServices.every(s => s.domain === "light");
    record("getServices: domain filter correct", allLight);
  } catch (e) {
    record("getServices: domain filter", false, e.message);
  }

  // Test 7: validateServiceCall — valid
  try {
    const valid = await client.validateServiceCall("light", "turn_on", {}, {
      entity_id: "light.bed_light"
    });
    record("validateServiceCall: valid call", valid.valid, JSON.stringify(valid.errors));
  } catch (e) {
    record("validateServiceCall: valid", false, e.message);
  }

  // Test 8: validateServiceCall — invalid entity
  try {
    const invalid = await client.validateServiceCall("light", "turn_on", {}, {
      entity_id: "light.nonexistent"
    });
    record("validateServiceCall: invalid entity", !invalid.valid,
      invalid.errors.join(", "));
  } catch (e) {
    record("validateServiceCall: invalid entity", false, e.message);
  }

  // Test 9: validateServiceCall — fake service
  try {
    const noService = await client.validateServiceCall("fake", "missing");
    record("validateServiceCall: fake service", !noService.valid,
      noService.errors.join(", "));
  } catch (e) {
    record("validateServiceCall: fake service", false, e.message);
  }

  // Test 10: SafetyChecker
  try {
    const blocked = safety.checkServiceCall("homeassistant", "stop", false);
    record("Safety: homeassistant.stop blocked", !blocked.allowed, blocked.reason);

    const allowed = safety.checkServiceCall("light", "turn_on", true);
    record("Safety: light.turn_on allowed (dry_run)", allowed.allowed);

    const safeInfo = safety.getSafetyInfo();
    record("Safety: getSafetyInfo()", safeInfo.blockedCount > 0,
      `calls=${safeInfo.serviceCallsEnabled}, dryRun=${safeInfo.dryRunRequired}, blocked=${safeInfo.blockedCount}`);

    const isSafe = safety.isSafeDomain("input_boolean");
    record("Safety: input_boolean is safe", isSafe);

    const notSafe = safety.isSafeDomain("homeassistant");
    record("Safety: homeassistant is not safe", !notSafe);

    const redacted = safety.redactSensitiveData({ api_key: "secret123", brightness: 255, password: "hidden" });
    record("Safety: redacts api_key", redacted.api_key === "**REDACTED**");
    record("Safety: redacts password", redacted.password === "**REDACTED**");
    record("Safety: preserves brightness", redacted.brightness === 255);
  } catch (e) {
    record("Safety", false, e.message);
  }

  // Test 11: getDevices
  try {
    const devices = await client.getDevices();
    record("getDevices: accessible", true, `${devices.length} devices`);

    if (devices.length > 0) {
      const sample = devices[0];
      record("getDevices: has id", !!sample?.id);
      record("getDevices: has name", !!sample?.name, sample?.name);
    }
  } catch (e) {
    record("getDevices", false, e.message);
  }

  // Test 12: getLogs
  try {
    const logs = await client.getLogs();
    record("getLogs: accessible", true, `${logs.length} log entries`);
  } catch (e) {
    // system_log may be empty on fresh install
    if (e.message.includes("Unknown command")) {
      record("getLogs: system_log not available", true, "expected on minimal install");
    } else {
      record("getLogs", false, e.message);
    }
  }

  // Test 13: getConnectionInfo
  try {
    const info = client.getConnectionInfo();
    record("getConnectionInfo: returns data", info.connected);
    record("getConnectionInfo: matches connect", info.version === connectInfo.version);
  } catch (e) {
    record("getConnectionInfo", false, e.message);
  }

  // Disconnect
  await client.disconnect();
  record("Disconnect: clean", !client.isConnected());

  // Summary
  console.log("\n=== Summary ===\n");
  const passed = results.filter(r => r.pass).length;
  const failed = results.filter(r => !r.pass).length;
  console.log(`Total: ${results.length} | Passed: ${passed} | Failed: ${failed}`);

  if (failed > 0) {
    console.log("\nFailed tests:");
    results.filter(r => !r.pass).forEach(r => console.log(`  - ${r.name}: ${r.detail}`));
  }

  // Save results
  const md = `## MCP Server WebSocket Tests

**Date:** ${new Date().toISOString().split("T")[0]}
**Passed:** ${passed}/${results.length}

| Test | Result | Detail |
|------|--------|--------|
${results.map(r => `| ${r.name} | ${r.pass ? "PASS" : "FAIL"} | ${r.detail} |`).join("\n")}
`;
  writeFileSync(join(homedir(), "ha-plugin-test-workspace", "MCP_WS_TEST_RESULTS.md"), md);
  console.log("\nResults saved to ~/ha-plugin-test-workspace/MCP_WS_TEST_RESULTS.md");

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
