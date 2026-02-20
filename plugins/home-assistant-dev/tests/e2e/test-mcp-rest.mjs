// REST API integration tests for HA instance
// Tests the same capabilities the MCP server tools will use

import { readFile } from "fs/promises";
import { writeFileSync, mkdirSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const CONFIG_PATH = join(homedir(), ".config", "ha-dev-mcp", "config.json");

async function loadConfig() {
  const content = await readFile(CONFIG_PATH, "utf-8");
  return JSON.parse(content);
}

async function haApi(path, token, method = "GET", body = null) {
  const opts = {
    method,
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
  };
  if (body) opts.body = JSON.stringify(body);
  const res = await fetch(`http://localhost:8123${path}`, opts);
  const text = await res.text();
  try { return { ok: res.ok, status: res.status, data: JSON.parse(text) }; }
  catch { return { ok: res.ok, status: res.status, data: text }; }
}

const results = [];
function record(name, pass, detail = "") {
  results.push({ name, pass, detail });
  console.log(`${pass ? "PASS" : "FAIL"} | ${name}${detail ? " — " + detail : ""}`);
}

async function main() {
  const config = await loadConfig();
  const token = config.homeAssistant.token;

  console.log("\n=== MCP Server Integration Tests (REST API) ===\n");

  // Test 1: HA Connection — version, location, components
  try {
    const { data } = await haApi("/api/config", token);
    record("HA Connection: version", !!data.version, `v${data.version}`);
    record("HA Connection: location", !!data.location_name, data.location_name);
    record("HA Connection: components loaded", Array.isArray(data.components) && data.components.length > 0,
      `${data.components.length} components`);
    record("HA Connection: demo integration", data.components.includes("demo"));
  } catch (e) {
    record("HA Connection", false, e.message);
  }

  // Test 2: Entity Query — list sensors
  try {
    const { data: states } = await haApi("/api/states", token);
    const sensors = states.filter(s => s.entity_id.startsWith("sensor."));
    const lights = states.filter(s => s.entity_id.startsWith("light."));
    const switches = states.filter(s => s.entity_id.startsWith("switch."));

    record("Entity Query: total entities", states.length > 0, `${states.length} entities`);
    record("Entity Query: sensors", sensors.length > 0, `${sensors.length} sensors`);
    record("Entity Query: lights", lights.length > 0, `${lights.length} lights`);
    record("Entity Query: switches", switches.length > 0, `${switches.length} switches`);

    const ids = new Set(states.map(s => s.entity_id));
    record("Entity Query: light.bed_light", ids.has("light.bed_light"));
    record("Entity Query: light.ceiling_lights", ids.has("light.ceiling_lights"));
    record("Entity Query: sensor.outside_temperature", ids.has("sensor.outside_temperature"));
  } catch (e) {
    record("Entity Query", false, e.message);
  }

  // Test 3: Service Discovery — light domain
  try {
    const { data: services } = await haApi("/api/services", token);
    const lightDomain = services.find(s => s.domain === "light");

    record("Service Discovery: domains returned", services.length > 0, `${services.length} domains`);
    record("Service Discovery: light domain", !!lightDomain);

    if (lightDomain) {
      const names = Object.keys(lightDomain.services);
      record("Service Discovery: light.turn_on", names.includes("turn_on"));
      record("Service Discovery: light.turn_off", names.includes("turn_off"));
      record("Service Discovery: light.toggle", names.includes("toggle"));
    }
  } catch (e) {
    record("Service Discovery", false, e.message);
  }

  // Test 4: Dry Run — validate light.turn_on without executing
  try {
    const { data: states } = await haApi("/api/states", token);
    const { data: services } = await haApi("/api/services", token);
    const bedLight = states.find(s => s.entity_id === "light.bed_light");
    const lightDomain = services.find(s => s.domain === "light");
    const serviceExists = lightDomain && Object.keys(lightDomain.services).includes("turn_on");

    record("Dry Run: service light.turn_on exists", serviceExists);
    record("Dry Run: target light.bed_light exists", !!bedLight);

    if (serviceExists && bedLight) {
      record("Dry Run: validation passed", true,
        `Would call light.turn_on on light.bed_light (state: ${bedLight.state})`);
    }

    const fakeEntity = states.find(s => s.entity_id === "light.nonexistent");
    record("Dry Run: non-existent entity rejected", !fakeEntity, "light.nonexistent correctly not found");
  } catch (e) {
    record("Dry Run", false, e.message);
  }

  // Test 5: Entity attributes
  try {
    const { data: states } = await haApi("/api/states", token);
    const bedLight = states.find(s => s.entity_id === "light.bed_light");

    record("Entity Attributes: has attributes", !!bedLight?.attributes);
    record("Entity Attributes: has friendly_name",
      !!bedLight?.attributes?.friendly_name,
      bedLight?.attributes?.friendly_name);
    record("Entity Attributes: has supported_features",
      bedLight?.attributes?.supported_features !== undefined,
      `features: ${bedLight?.attributes?.supported_features}`);
  } catch (e) {
    record("Entity Attributes", false, e.message);
  }

  // Test 6: Logs endpoint
  try {
    const res = await fetch("http://localhost:8123/api/error_log", {
      headers: { "Authorization": `Bearer ${token}` }
    });
    const text = await res.text();
    record("Logs: accessible", res.ok, `${text.split("\n").length} lines`);
  } catch (e) {
    record("Logs", false, e.message);
  }

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
  const md = `## REST API Integration Tests

**Date:** ${new Date().toISOString().split("T")[0]}
**Passed:** ${passed}/${results.length}

| Test | Result | Detail |
|------|--------|--------|
${results.map(r => `| ${r.name} | ${r.pass ? "PASS" : "FAIL"} | ${r.detail} |`).join("\n")}
`;
  const outDir = join(homedir(), "ha-plugin-test-workspace");
  mkdirSync(outDir, { recursive: true });
  writeFileSync(join(outDir, "REST_API_TEST_RESULTS.md"), md);
  console.log("\nResults saved to ~/ha-plugin-test-workspace/REST_API_TEST_RESULTS.md");

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
