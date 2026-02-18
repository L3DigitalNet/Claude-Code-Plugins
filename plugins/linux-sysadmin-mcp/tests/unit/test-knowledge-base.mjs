/**
 * Layer 5 — Knowledge Base Unit Tests
 *
 * 23 tests validating the knowledge base loader:
 * YAML parsing, profile resolution, escalation extraction,
 * user overrides, and the KB interface.
 *
 * Run: node tests/unit/test-knowledge-base.mjs
 */

import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = join(__dirname, "../..");
const KNOWLEDGE_DIR = join(PLUGIN_ROOT, "knowledge");

const { loadKnowledgeBase } = await import(
  join(PLUGIN_ROOT, "dist/knowledge/loader.js")
);

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------
let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  \u2713 ${name}`);
  } catch (err) {
    failed++;
    failures.push({ name, error: err.message });
    console.log(`  \u2717 ${name}\n    ${err.message}`);
  }
}

function assert(condition, message) {
  if (!condition) throw new Error(message || "Assertion failed");
}

function assertEqual(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(
      `${label || "Value"}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

// ---------------------------------------------------------------------------
// Helper: load with defaults
// ---------------------------------------------------------------------------
function load(overrides = {}) {
  return loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
    ...overrides,
  });
}

// ---------------------------------------------------------------------------
// YAML Parsing & Validation (6 tests)
// ---------------------------------------------------------------------------
console.log("\nYAML Parsing & Validation");

test("1. All 8 built-in profiles parse without error", () => {
  const kb = load();
  assertEqual(kb.profiles.size, 8, "profiles.size");
});

test("2. Each profile has required fields (id, name, schema_version, category, service.unit_names)", () => {
  const kb = load();
  for (const [id, profile] of kb.profiles) {
    assert(typeof profile.id === "string" && profile.id.length > 0, `${id}: missing id`);
    assert(typeof profile.name === "string" && profile.name.length > 0, `${id}: missing name`);
    assert(typeof profile.schema_version === "number", `${id}: missing schema_version`);
    assert(typeof profile.category === "string" && profile.category.length > 0, `${id}: missing category`);
    assert(Array.isArray(profile.service.unit_names), `${id}: missing service.unit_names`);
    assert(profile.service.unit_names.length > 0, `${id}: empty service.unit_names`);
  }
});

test("3. Profile id matches filename (sshd.yaml -> id: sshd)", () => {
  const kb = load();
  // All 8 known profiles: their id should match what we expect from filenames
  const expectedIds = [
    "crowdsec", "docker", "fail2ban", "nginx", "pihole", "sshd", "ufw", "unbound",
  ];
  for (const id of expectedIds) {
    assert(kb.profiles.has(id), `Profile '${id}' not found (expected from ${id}.yaml)`);
    assertEqual(kb.profiles.get(id).id, id, `Profile id for ${id}.yaml`);
  }
});

test("4. All unit_names are non-empty strings", () => {
  const kb = load();
  for (const [id, profile] of kb.profiles) {
    for (const name of profile.service.unit_names) {
      assert(typeof name === "string" && name.length > 0, `${id}: unit_name is empty or not a string`);
    }
  }
});

test("5. Malformed YAML is skipped (not crash)", () => {
  const tmpDir = join(PLUGIN_ROOT, "tests", "unit", "_tmp_bad_yaml");
  try {
    mkdirSync(tmpDir, { recursive: true });
    writeFileSync(join(tmpDir, "broken.yaml"), ":\n  :\n    - [invalid: {yaml: ]]]");
    const kb = loadKnowledgeBase({
      builtinDir: tmpDir,
      additionalPaths: [],
      disabledIds: [],
      activeUnitNames: [],
    });
    assertEqual(kb.profiles.size, 0, "profiles.size from malformed YAML dir");
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("6. Missing required field (empty unit_names) causes profile to be skipped", () => {
  const tmpDir = join(PLUGIN_ROOT, "tests", "unit", "_tmp_missing_fields");
  try {
    mkdirSync(tmpDir, { recursive: true });
    writeFileSync(
      join(tmpDir, "incomplete.yaml"),
      `id: incomplete\nname: "Incomplete"\nschema_version: 1\ncategory: test\nservice:\n  unit_names: []\n`
    );
    const kb = loadKnowledgeBase({
      builtinDir: tmpDir,
      additionalPaths: [],
      disabledIds: [],
      activeUnitNames: [],
    });
    assertEqual(kb.profiles.size, 0, "profiles.size with empty unit_names");
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
});

// ---------------------------------------------------------------------------
// Profile Resolution (5 tests)
// ---------------------------------------------------------------------------
console.log("\nProfile Resolution");

test("7. Matching unit_name -> status: active (activeUnitNames: [sshd])", () => {
  const kb = load({ activeUnitNames: ["sshd"] });
  const sshdResolved = kb.resolved.find((r) => r.profile.id === "sshd");
  assert(sshdResolved, "sshd resolved profile not found");
  assertEqual(sshdResolved.status, "active", "sshd status");
});

test("8. No matching unit_name -> status: inactive (empty activeUnitNames)", () => {
  const kb = load({ activeUnitNames: [] });
  const sshdResolved = kb.resolved.find((r) => r.profile.id === "sshd");
  assert(sshdResolved, "sshd resolved profile not found");
  assertEqual(sshdResolved.status, "inactive", "sshd status with no active units");
});

test('9. Matching on second unit_name (sshd.yaml has ["ssh", "sshd"]) — activeUnitNames: ["ssh"]', () => {
  const kb = load({ activeUnitNames: ["ssh"] });
  const sshdResolved = kb.resolved.find((r) => r.profile.id === "sshd");
  assert(sshdResolved, "sshd resolved profile not found");
  assertEqual(sshdResolved.status, "active", "sshd status via ssh unit_name");
});

test("10. Empty activeUnitNames -> all inactive (count active === 0)", () => {
  const kb = load({ activeUnitNames: [] });
  const activeCount = kb.resolved.filter((r) => r.status === "active").length;
  assertEqual(activeCount, 0, "active count");
});

test('11. Disabled IDs excluded (disable "sshd","nginx" -> profiles.size === 6)', () => {
  const kb = load({ disabledIds: ["sshd", "nginx"] });
  assertEqual(kb.profiles.size, 6, "profiles.size after disabling 2");
  assert(!kb.profiles.has("sshd"), "sshd should be removed");
  assert(!kb.profiles.has("nginx"), "nginx should be removed");
});

// ---------------------------------------------------------------------------
// Dependency Role Resolution (3 tests)
// ---------------------------------------------------------------------------
console.log("\nDependency Role Resolution");

test("12. Active profile with matching typical_service -> role resolved", () => {
  // pihole requires role "upstream_dns" with typical_services: ["unbound", ...]
  // If both pihole-FTL and unbound are active, the role should resolve.
  const kb = load({ activeUnitNames: ["pihole-FTL", "unbound"] });
  const piholeResolved = kb.resolved.find((r) => r.profile.id === "pihole");
  assert(piholeResolved, "pihole resolved profile not found");
  assertEqual(piholeResolved.status, "active", "pihole status");
  assert(
    piholeResolved.rolesResolved["upstream_dns"] === "unbound",
    `Expected upstream_dns resolved to "unbound", got "${piholeResolved.rolesResolved["upstream_dns"]}"`
  );
});

test("13. No matching typical_service -> unresolved_roles populated", () => {
  // pihole active but unbound NOT active -> upstream_dns unresolved
  const kb = load({ activeUnitNames: ["pihole-FTL"] });
  const piholeResolved = kb.resolved.find((r) => r.profile.id === "pihole");
  assert(piholeResolved, "pihole resolved profile not found");
  assert(
    piholeResolved.unresolved_roles.includes("upstream_dns"),
    `Expected "upstream_dns" in unresolved_roles, got [${piholeResolved.unresolved_roles}]`
  );
});

test("14. Inactive profile dependencies not resolved (all rolesResolved empty)", () => {
  // pihole inactive (pihole-FTL not in activeUnitNames) -> rolesResolved should be empty
  const kb = load({ activeUnitNames: ["unbound"] });
  const piholeResolved = kb.resolved.find((r) => r.profile.id === "pihole");
  assert(piholeResolved, "pihole resolved profile not found");
  assertEqual(piholeResolved.status, "inactive", "pihole status");
  assertEqual(
    Object.keys(piholeResolved.rolesResolved).length,
    0,
    "rolesResolved key count for inactive pihole"
  );
  assertEqual(
    piholeResolved.unresolved_roles.length,
    0,
    "unresolved_roles length for inactive pihole"
  );
});

// ---------------------------------------------------------------------------
// Escalation Extraction (5 tests)
// ---------------------------------------------------------------------------
console.log("\nEscalation Extraction");

test("15. Active profile with risk_escalation -> escalation extracted (sshd active -> escalations.length > 0)", () => {
  const kb = load({ activeUnitNames: ["sshd"] });
  assert(kb.escalations.length > 0, `Expected escalations > 0, got ${kb.escalations.length}`);
  const sshdEscalations = kb.escalations.filter((e) => e.profileId === "sshd");
  assert(sshdEscalations.length > 0, "Expected at least one sshd escalation");
});

test('16. risk_escalation: null -> no escalation (sshd "restart sshd" has null)', () => {
  const kb = load({ activeUnitNames: ["sshd"] });
  const restartEscalation = kb.escalations.find(
    (e) => e.profileId === "sshd" && e.trigger === "restart sshd"
  );
  assertEqual(restartEscalation, undefined, "restart sshd escalation");
});

test("17. Inactive profile -> no escalations (empty activeUnitNames -> escalations.length === 0)", () => {
  const kb = load({ activeUnitNames: [] });
  assertEqual(kb.escalations.length, 0, "escalations.length with no active units");
});

test("18. Escalation has correct fields (trigger, profileId, warning, riskLevel)", () => {
  const kb = load({ activeUnitNames: ["sshd"] });
  const escalation = kb.escalations.find((e) => e.profileId === "sshd");
  assert(escalation, "Expected at least one sshd escalation");
  assert(typeof escalation.trigger === "string" && escalation.trigger.length > 0, "trigger must be non-empty string");
  assert(typeof escalation.profileId === "string" && escalation.profileId.length > 0, "profileId must be non-empty string");
  assert(typeof escalation.warning === "string" && escalation.warning.length > 0, "warning must be non-empty string");
  assert(typeof escalation.riskLevel === "string" && escalation.riskLevel.length > 0, "riskLevel must be non-empty string");
});

test('19. sshd "edit /etc/ssh/sshd_config" -> high escalation (riskLevel === "high")', () => {
  const kb = load({ activeUnitNames: ["sshd"] });
  const editEscalation = kb.escalations.find(
    (e) => e.profileId === "sshd" && e.trigger === "edit /etc/ssh/sshd_config"
  );
  assert(editEscalation, 'Expected escalation for "edit /etc/ssh/sshd_config"');
  assertEqual(editEscalation.riskLevel, "high", "riskLevel for edit sshd_config");
});

// ---------------------------------------------------------------------------
// User Profile Override (2 tests)
// ---------------------------------------------------------------------------
console.log("\nUser Profile Override");

test("20. additionalPaths profile with same id overrides built-in", () => {
  const tmpDir = join(PLUGIN_ROOT, "tests", "unit", "_tmp_override");
  try {
    mkdirSync(tmpDir, { recursive: true });
    writeFileSync(
      join(tmpDir, "sshd.yaml"),
      [
        'id: sshd',
        'name: "Custom SSH Override"',
        'schema_version: 1',
        'category: remote_access',
        'service:',
        '  unit_names: ["sshd"]',
        'config:',
        '  primary: "/etc/ssh/sshd_config"',
      ].join("\n")
    );
    const kb = loadKnowledgeBase({
      builtinDir: KNOWLEDGE_DIR,
      additionalPaths: [tmpDir],
      disabledIds: [],
      activeUnitNames: [],
    });
    const sshd = kb.profiles.get("sshd");
    assert(sshd, "sshd profile should exist");
    assertEqual(sshd.name, "Custom SSH Override", "sshd name after override");
  } finally {
    rmSync(tmpDir, { recursive: true, force: true });
  }
});

test("21. Non-existent additionalPaths directory -> no crash (profiles.size still 8)", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: ["/tmp/nonexistent-knowledge-dir-9999"],
    disabledIds: [],
    activeUnitNames: [],
  });
  assertEqual(kb.profiles.size, 8, "profiles.size with non-existent additionalPaths");
});

// ---------------------------------------------------------------------------
// Interface (2 tests)
// ---------------------------------------------------------------------------
console.log("\nInterface");

test('22. getProfile("sshd") returns profile, getProfile("fake") -> undefined', () => {
  const kb = load();
  const sshd = kb.getProfile("sshd");
  assert(sshd, 'getProfile("sshd") should return a profile');
  assertEqual(sshd.id, "sshd", "returned profile id");
  const fake = kb.getProfile("fake");
  assertEqual(fake, undefined, 'getProfile("fake")');
});

test("23. getActiveProfiles() returns only active profiles", () => {
  const kb = load({ activeUnitNames: ["sshd", "nginx"] });
  const active = kb.getActiveProfiles();
  assertEqual(active.length, 2, "active profiles count");
  const activeIds = active.map((r) => r.profile.id).sort();
  assert(activeIds[0] === "nginx" && activeIds[1] === "sshd",
    `Expected ["nginx","sshd"], got ${JSON.stringify(activeIds)}`);
  // All must have status "active"
  for (const r of active) {
    assertEqual(r.status, "active", `${r.profile.id} status`);
  }
});

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
console.log("\n" + "=".repeat(60));
console.log(`Results: ${passed} passed, ${failed} failed, ${passed + failed} total`);

if (failures.length > 0) {
  console.log("\nFailures:");
  for (const f of failures) {
    console.log(`  - ${f.name}: ${f.error}`);
  }
}

console.log("=".repeat(60));
process.exit(failed > 0 ? 1 : 0);
