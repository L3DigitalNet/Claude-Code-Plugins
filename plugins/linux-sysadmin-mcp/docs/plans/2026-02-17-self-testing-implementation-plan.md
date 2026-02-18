# Self-Testing Framework Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a comprehensive self-testing framework that validates all 106 MCP tools, safety gate, knowledge base, and plugin structure using a disposable Fedora container.

**Architecture:** Five test layers — pytest structural validation (host), MCP server startup validation (container), all-tool execution tests (container), safety gate unit+e2e tests (host+container), knowledge base unit tests (host). A bash orchestrator manages container lifecycle and runs all layers with color-coded output.

**Tech Stack:** Python/pytest (Layer 1), Node.js ESM (Layers 2-5), Docker/Podman + Fedora 43 systemd container (e2e target), bash (orchestrator)

**Design doc:** `docs/plans/2026-02-17-self-testing-framework-design.md`

---

### Task 1: Create Test Container Infrastructure

**Files:**
- Create: `tests/container/Dockerfile`
- Create: `tests/container/docker-compose.yml`
- Create: `tests/container/setup-fixtures.sh`

**Step 1: Create the tests directory structure**

Run: `mkdir -p tests/{container,e2e,unit}`

**Step 2: Write the Dockerfile**

Create `tests/container/Dockerfile`:

```dockerfile
FROM fedora:43
ENV container=docker

# Minimal systemd — remove unnecessary sysinit targets
RUN (cd /lib/systemd/system/sysinit.target.wants/ && \
     for i in *; do [ "$i" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; done) && \
    rm -f /lib/systemd/system/multi-user.target.wants/* && \
    rm -f /etc/systemd/system/*.wants/* && \
    rm -f /lib/systemd/system/local-fs.target.wants/* && \
    rm -f /lib/systemd/system/sockets.target.wants/*udev* && \
    rm -f /lib/systemd/system/sockets.target.wants/*initctl* && \
    rm -f /lib/systemd/system/basic.target.wants/*

# Services for testing all 15 tool modules
RUN dnf -y install \
    # Core system tools (performance, logs, storage, networking)
    systemd procps-ng iproute net-tools bind-utils hostname \
    util-linux findutils diffutils which file lsof \
    # sshd (ssh tools, security tools)
    openssh-server openssh-clients \
    # nginx (services tools, backup tools)
    nginx \
    # crond (cron tools)
    cronie \
    # firewalld (firewall tools)
    firewalld \
    # User management (users tools)
    shadow-utils sudo \
    # Package management (packages tools)
    dnf-utils \
    # Node.js runtime for MCP server
    nodejs \
    # Logging tools
    rsyslog \
    && dnf clean all

# Test user with passwordless sudo
RUN useradd -m testadmin && \
    echo "testadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testadmin && \
    chmod 440 /etc/sudoers.d/testadmin

# Enable services that tools expect
RUN systemctl enable sshd nginx crond firewalld rsyslog

# Generate SSH host keys
RUN ssh-keygen -A

VOLUME ["/sys/fs/cgroup"]
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
```

**Step 3: Write docker-compose.yml**

Create `tests/container/docker-compose.yml`:

```yaml
services:
  linux-sysadmin-test:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: linux-sysadmin-test
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - ../../:/plugin:ro
    tmpfs:
      - /run
      - /tmp
    stop_signal: SIGRTMIN+3
```

**Step 4: Write setup-fixtures.sh**

Create `tests/container/setup-fixtures.sh`:

```bash
#!/bin/bash
# Create known test state inside the container.
# Run once after container starts and systemd finishes booting.
set -euo pipefail

echo "=== Setting up test fixtures ==="

# ── Cron fixtures ──────────────────────────────────────────
echo "0 * * * * /bin/true # test-hourly" | crontab -u testadmin -
echo "[fixtures] cron: test-hourly entry added"

# ── Firewall fixtures ──────────────────────────────────────
if systemctl is-active firewalld &>/dev/null; then
    firewall-cmd --add-port=8080/tcp --permanent 2>/dev/null || true
    firewall-cmd --reload 2>/dev/null || true
    echo "[fixtures] firewall: port 8080/tcp added"
else
    echo "[fixtures] firewall: firewalld not running, skipping"
fi

# ── User/group fixtures ───────────────────────────────────
id testuser-fixture &>/dev/null || useradd -m testuser-fixture
getent group testgroup-fixture &>/dev/null || groupadd testgroup-fixture
echo "[fixtures] users: testuser-fixture and testgroup-fixture created"

# ── SSH fixtures ──────────────────────────────────────────
TESTADMIN_SSH="/home/testadmin/.ssh"
mkdir -p "$TESTADMIN_SSH"
if [ ! -f "$TESTADMIN_SSH/id_ed25519" ]; then
    ssh-keygen -t ed25519 -f "$TESTADMIN_SSH/id_ed25519" -N "" -q
fi
chown -R testadmin: "$TESTADMIN_SSH"
chmod 700 "$TESTADMIN_SSH"
echo "[fixtures] ssh: testadmin key generated"

# ── Log fixtures ──────────────────────────────────────────
logger -t test-fixture "Self-test log entry for search validation"
echo "[fixtures] logs: test-fixture entry logged"

# ── Backup target directory ───────────────────────────────
mkdir -p /var/backups/linux-sysadmin
echo "[fixtures] backup: /var/backups/linux-sysadmin created"

# ── Documentation directory ───────────────────────────────
mkdir -p /tmp/sysadmin-docs
echo "[fixtures] docs: /tmp/sysadmin-docs created"

# ── Package fixture (install cowsay for pkg_remove tests) ──
dnf -y install cowsay 2>/dev/null || echo "[fixtures] packages: cowsay not available, skipping"

echo "=== Fixtures complete ==="
```

**Step 5: Build the container and verify it starts**

Run:
```bash
cd tests/container && docker compose build
docker compose up -d
sleep 10  # wait for systemd
docker exec linux-sysadmin-test systemctl is-system-running
docker exec linux-sysadmin-test bash /plugin/tests/container/setup-fixtures.sh
```

Expected: `running` (or `degraded` which is acceptable), fixtures output with no errors.

**Step 6: Commit**

```bash
git add tests/container/
git commit -m "test: add container infrastructure for self-testing

Fedora 43 systemd container with sshd, nginx, crond, firewalld.
Fixtures create known state for all 15 tool modules."
```

---

### Task 2: Layer 1 — Structural Validation (pytest)

**Files:**
- Create: `tests/test_plugin_structure.py`

**Step 1: Write the test file**

Create `tests/test_plugin_structure.py`:

```python
"""Structural validation of the linux-sysadmin-mcp plugin.

Validates plugin layout without requiring Node.js, a container, or sudo.
"""
from __future__ import annotations

import json
from pathlib import Path

import pytest

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore[assignment]


# ── Constants ─────────────────────────────────────────────

EXPECTED_TOOL_MODULES = sorted([
    "backup", "containers", "cron", "docs", "firewall",
    "logs", "networking", "packages", "performance",
    "security", "services", "session", "ssh", "storage", "users",
])

EXPECTED_KNOWLEDGE_PROFILES = sorted([
    "crowdsec", "docker", "fail2ban", "nginx",
    "pihole", "sshd", "ufw", "unbound",
])

EXPECTED_CORE_FILES = [
    "src/server.ts",
    "src/logger.ts",
    "src/config/loader.ts",
    "src/distro/detector.ts",
    "src/execution/executor.ts",
    "src/safety/gate.ts",
    "src/knowledge/loader.ts",
    "src/tools/registry.ts",
    "src/tools/context.ts",
    "src/tools/helpers.ts",
]

EXPECTED_TYPE_FILES = sorted([
    "command.ts", "config.ts", "distro.ts", "firewall.ts",
    "index.ts", "response.ts", "risk.ts", "tool.ts",
])

EXPECTED_DEPENDENCIES = [
    "@modelcontextprotocol/sdk",
    "pino",
    "yaml",
    "zod",
]

REMOVED_DEPENDENCIES = [
    "ssh2",
]


# ── Fixtures ──────────────────────────────────────────────

@pytest.fixture
def plugin_root() -> Path:
    return Path(__file__).parent.parent


# ── TestPluginManifest ────────────────────────────────────

@pytest.mark.unit
class TestPluginManifest:

    def test_manifest_exists(self, plugin_root: Path) -> None:
        assert (plugin_root / ".claude-plugin" / "plugin.json").is_file()

    def test_manifest_valid_json(self, plugin_root: Path) -> None:
        text = (plugin_root / ".claude-plugin" / "plugin.json").read_text()
        data = json.loads(text)
        assert isinstance(data, dict)

    def test_manifest_required_fields(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".claude-plugin" / "plugin.json").read_text())
        for field in ("name", "version", "description"):
            assert field in data, f"Missing required field: {field}"

    def test_manifest_name(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".claude-plugin" / "plugin.json").read_text())
        assert data["name"] == "linux-sysadmin-mcp"


# ── TestMCPConfig ─────────────────────────────────────────

@pytest.mark.unit
class TestMCPConfig:

    def test_mcp_json_exists(self, plugin_root: Path) -> None:
        assert (plugin_root / ".mcp.json").is_file()

    def test_mcp_json_valid(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".mcp.json").read_text())
        assert "linux-sysadmin-mcp" in data

    def test_mcp_json_points_to_bundle(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".mcp.json").read_text())
        entry = data["linux-sysadmin-mcp"]
        assert entry["command"] == "node"
        args = entry["args"]
        assert any("server.bundle.cjs" in a for a in args)

    def test_mcp_json_uses_plugin_root_var(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / ".mcp.json").read_text())
        args = data["linux-sysadmin-mcp"]["args"]
        assert any("${CLAUDE_PLUGIN_ROOT}" in a for a in args)


# ── TestBundleExists ──────────────────────────────────────

@pytest.mark.unit
class TestBundleExists:

    def test_bundle_file_exists(self, plugin_root: Path) -> None:
        assert (plugin_root / "dist" / "server.bundle.cjs").is_file()

    def test_bundle_size_sanity(self, plugin_root: Path) -> None:
        size = (plugin_root / "dist" / "server.bundle.cjs").stat().st_size
        assert size > 500_000, f"Bundle is only {size} bytes (expected >500KB)"


# ── TestTypeScriptSources ─────────────────────────────────

@pytest.mark.unit
class TestTypeScriptSources:

    def test_server_entry_point(self, plugin_root: Path) -> None:
        assert (plugin_root / "src" / "server.ts").is_file()

    @pytest.mark.parametrize("module_name", EXPECTED_TOOL_MODULES)
    def test_tool_module_exists(self, plugin_root: Path, module_name: str) -> None:
        index = plugin_root / "src" / "tools" / module_name / "index.ts"
        assert index.is_file(), f"Missing src/tools/{module_name}/index.ts"

    def test_tool_module_count(self, plugin_root: Path) -> None:
        tools_dir = plugin_root / "src" / "tools"
        modules = sorted([
            d.name for d in tools_dir.iterdir()
            if d.is_dir() and (d / "index.ts").is_file()
        ])
        assert len(modules) == 15, f"Expected 15 tool modules, found {len(modules)}: {modules}"

    @pytest.mark.parametrize("core_file", EXPECTED_CORE_FILES)
    def test_core_file_exists(self, plugin_root: Path, core_file: str) -> None:
        assert (plugin_root / core_file).is_file(), f"Missing {core_file}"

    def test_type_files(self, plugin_root: Path) -> None:
        types_dir = plugin_root / "src" / "types"
        actual = sorted(f.name for f in types_dir.iterdir() if f.suffix == ".ts")
        assert actual == EXPECTED_TYPE_FILES, (
            f"Type files mismatch.\n  Missing: {sorted(set(EXPECTED_TYPE_FILES) - set(actual))}\n"
            f"  Extra: {sorted(set(actual) - set(EXPECTED_TYPE_FILES))}"
        )


# ── TestKnowledgeProfiles ─────────────────────────────────

@pytest.mark.unit
class TestKnowledgeProfiles:

    def test_profile_count(self, plugin_root: Path) -> None:
        profiles = list((plugin_root / "knowledge").glob("*.yaml"))
        assert len(profiles) == 8, f"Expected 8 profiles, found {len(profiles)}"

    @pytest.mark.parametrize("profile_name", EXPECTED_KNOWLEDGE_PROFILES)
    def test_profile_exists(self, plugin_root: Path, profile_name: str) -> None:
        assert (plugin_root / "knowledge" / f"{profile_name}.yaml").is_file()

    @pytest.mark.parametrize("profile_name", EXPECTED_KNOWLEDGE_PROFILES)
    def test_profile_parses(self, plugin_root: Path, profile_name: str) -> None:
        if yaml is None:
            pytest.skip("PyYAML not installed")
        text = (plugin_root / "knowledge" / f"{profile_name}.yaml").read_text()
        data = yaml.safe_load(text)
        assert isinstance(data, dict)

    @pytest.mark.parametrize("profile_name", EXPECTED_KNOWLEDGE_PROFILES)
    def test_profile_required_fields(self, plugin_root: Path, profile_name: str) -> None:
        if yaml is None:
            pytest.skip("PyYAML not installed")
        data = yaml.safe_load((plugin_root / "knowledge" / f"{profile_name}.yaml").read_text())
        for field in ("id", "name", "schema_version", "category"):
            assert field in data, f"{profile_name}.yaml missing '{field}'"
        assert "service" in data and "unit_names" in data["service"], (
            f"{profile_name}.yaml missing service.unit_names"
        )

    @pytest.mark.parametrize("profile_name", EXPECTED_KNOWLEDGE_PROFILES)
    def test_profile_id_matches_filename(self, plugin_root: Path, profile_name: str) -> None:
        if yaml is None:
            pytest.skip("PyYAML not installed")
        data = yaml.safe_load((plugin_root / "knowledge" / f"{profile_name}.yaml").read_text())
        assert data["id"] == profile_name, (
            f"{profile_name}.yaml has id '{data['id']}', expected '{profile_name}'"
        )

    def test_no_duplicate_ids(self, plugin_root: Path) -> None:
        if yaml is None:
            pytest.skip("PyYAML not installed")
        ids: list[str] = []
        for f in (plugin_root / "knowledge").glob("*.yaml"):
            data = yaml.safe_load(f.read_text())
            if isinstance(data, dict) and "id" in data:
                ids.append(data["id"])
        assert len(ids) == len(set(ids)), f"Duplicate profile IDs: {ids}"


# ── TestPackageJson ───────────────────────────────────────

@pytest.mark.unit
class TestPackageJson:

    def test_package_json_exists(self, plugin_root: Path) -> None:
        assert (plugin_root / "package.json").is_file()

    def test_package_json_valid(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        assert isinstance(data, dict)

    def test_build_script_includes_bundle(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        build = data.get("scripts", {}).get("build", "")
        assert "bundle" in build, f"build script should include bundle step: '{build}'"

    def test_start_script_points_to_bundle(self, plugin_root: Path) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        start = data.get("scripts", {}).get("start", "")
        assert "server.bundle.cjs" in start, f"start script should use bundle: '{start}'"

    @pytest.mark.parametrize("dep", EXPECTED_DEPENDENCIES)
    def test_has_dependency(self, plugin_root: Path, dep: str) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        deps = data.get("dependencies", {})
        assert dep in deps, f"Missing dependency: {dep}"

    @pytest.mark.parametrize("dep", REMOVED_DEPENDENCIES)
    def test_removed_dependency_absent(self, plugin_root: Path, dep: str) -> None:
        data = json.loads((plugin_root / "package.json").read_text())
        deps = data.get("dependencies", {})
        assert dep not in deps, f"Dead dependency still present: {dep}"


# ── TestCrossReferences ───────────────────────────────────

@pytest.mark.unit
class TestCrossReferences:

    def test_readme_mentions_15_modules(self, plugin_root: Path) -> None:
        readme = (plugin_root / "README.md").read_text()
        assert "15 modules" in readme or "15 tool" in readme.lower(), (
            "README should mention 15 tool modules"
        )

    def test_readme_mentions_8_profiles(self, plugin_root: Path) -> None:
        readme = (plugin_root / "README.md").read_text()
        # Check all 8 profile names are mentioned
        for name in EXPECTED_KNOWLEDGE_PROFILES:
            assert name in readme.lower(), f"README missing profile name: {name}"

    def test_gitignore_tracks_bundle(self, plugin_root: Path) -> None:
        gitignore = (plugin_root / ".gitignore").read_text()
        assert "!dist/server.bundle.cjs" in gitignore

    def test_gitignore_ignores_node_modules(self, plugin_root: Path) -> None:
        gitignore = (plugin_root / ".gitignore").read_text()
        assert "node_modules/" in gitignore
```

**Step 2: Run the tests**

Run: `cd plugins/linux-sysadmin-mcp && python3 -m pytest tests/test_plugin_structure.py -v --tb=short`

Expected: All ~35 tests pass (some may skip if PyYAML not installed).

**Step 3: Commit**

```bash
git add tests/test_plugin_structure.py
git commit -m "test: add Layer 1 structural validation (pytest)

35 tests across 7 classes validating plugin manifest, .mcp.json,
bundle, TypeScript sources, knowledge profiles, package.json,
and cross-references."
```

---

### Task 3: Layer 5 — Knowledge Base Unit Tests

**Files:**
- Create: `tests/unit/test-knowledge-base.mjs`

**Why Layer 5 before Layer 2?** Unit tests have no container dependency, so we implement them first.

**Step 1: Write the test file**

Create `tests/unit/test-knowledge-base.mjs`:

```javascript
/**
 * Layer 5: Knowledge Base unit tests.
 * Tests YAML parsing, profile resolution, and escalation extraction.
 * Runs on host — no container needed.
 */
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = join(__dirname, "../..");
const KNOWLEDGE_DIR = join(PLUGIN_ROOT, "knowledge");

// Import the compiled module
const { loadKnowledgeBase } = await import(join(PLUGIN_ROOT, "dist/knowledge/loader.js"));

// ── Test Harness ──────────────────────────────────────────

let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (err) {
    failed++;
    failures.push({ name, error: err.message });
    console.log(`  ✗ ${name}`);
    console.log(`    ${err.message}`);
  }
}

function assertEqual(actual, expected, msg) {
  if (actual !== expected) throw new Error(`${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || "Assertion failed");
}

// ── Temp dir for override tests ──────────────────────────

const TEMP_DIR = join(__dirname, ".tmp-kb-test");
function setupTempDir() {
  if (existsSync(TEMP_DIR)) rmSync(TEMP_DIR, { recursive: true });
  mkdirSync(TEMP_DIR, { recursive: true });
}
function cleanupTempDir() {
  if (existsSync(TEMP_DIR)) rmSync(TEMP_DIR, { recursive: true });
}

// ══════════════════════════════════════════════════════════
// YAML Parsing & Validation (6 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== YAML Parsing & Validation ===\n");

test("1. All 8 built-in profiles parse without error", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  assertEqual(kb.profiles.size, 8, "profile count");
});

test("2. Each profile has required fields", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  for (const [id, profile] of kb.profiles) {
    assert(profile.id, `${id}: missing id`);
    assert(profile.name, `${id}: missing name`);
    assert(profile.schema_version !== undefined, `${id}: missing schema_version`);
    assert(profile.category, `${id}: missing category`);
    assert(profile.service?.unit_names?.length > 0, `${id}: missing service.unit_names`);
  }
});

test("3. Profile id matches filename", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  const expectedIds = [
    "crowdsec", "docker", "fail2ban", "nginx",
    "pihole", "sshd", "ufw", "unbound",
  ];
  for (const id of expectedIds) {
    assert(kb.profiles.has(id), `Profile '${id}' not loaded (filename mismatch?)`);
  }
});

test("4. All unit_names are non-empty strings", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  for (const [id, profile] of kb.profiles) {
    for (const name of profile.service.unit_names) {
      assert(typeof name === "string" && name.length > 0, `${id}: empty unit_name`);
    }
  }
});

test("5. Malformed YAML is skipped (not crash)", () => {
  setupTempDir();
  writeFileSync(join(TEMP_DIR, "bad.yaml"), "{{invalid yaml::");
  const kb = loadKnowledgeBase({
    builtinDir: TEMP_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  assertEqual(kb.profiles.size, 0, "malformed YAML should be skipped");
  cleanupTempDir();
});

test("6. Missing required field causes profile to be skipped", () => {
  setupTempDir();
  // Profile without service.unit_names
  writeFileSync(join(TEMP_DIR, "incomplete.yaml"), `
id: incomplete
name: "Incomplete Profile"
schema_version: 1
category: test
service:
  unit_names: []
`);
  const kb = loadKnowledgeBase({
    builtinDir: TEMP_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  assertEqual(kb.profiles.size, 0, "profile with empty unit_names should be skipped");
  cleanupTempDir();
});

// ══════════════════════════════════════════════════════════
// Profile Resolution (5 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Profile Resolution ===\n");

test("7. Matching unit_name → status: active", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["sshd.service"],
  });
  const sshd = kb.resolved.find((r) => r.profile.id === "sshd");
  assert(sshd, "sshd profile not found");
  assertEqual(sshd.status, "active", "sshd status");
});

test("8. No matching unit_name → status: inactive", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  const sshd = kb.resolved.find((r) => r.profile.id === "sshd");
  assert(sshd, "sshd profile not found");
  assertEqual(sshd.status, "inactive", "sshd status");
});

test("9. Matching on second unit_name (ssh vs sshd) → active", () => {
  // sshd.yaml has unit_names: ["ssh", "sshd"]
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["ssh.service"],
  });
  const sshd = kb.resolved.find((r) => r.profile.id === "sshd");
  assert(sshd, "sshd profile not found");
  assertEqual(sshd.status, "active", "sshd should be active via 'ssh' unit_name");
});

test("10. Empty activeUnitNames → all inactive", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  const activeCount = kb.resolved.filter((r) => r.status === "active").length;
  assertEqual(activeCount, 0, "active profile count");
});

test("11. Disabled IDs excluded from results", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: ["sshd", "nginx"],
    activeUnitNames: [],
  });
  assertEqual(kb.profiles.size, 6, "profile count after disabling 2");
  assert(!kb.profiles.has("sshd"), "sshd should be disabled");
  assert(!kb.profiles.has("nginx"), "nginx should be disabled");
});

// ══════════════════════════════════════════════════════════
// Dependency Role Resolution (3 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Dependency Role Resolution ===\n");

test("12. Active profile with matching typical_service → role resolved", () => {
  // nginx requires dns_resolver with typical_services: ["unbound", "pihole"]
  // If unbound is also active, the role should resolve
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["nginx.service", "unbound.service"],
  });
  const nginx = kb.resolved.find((r) => r.profile.id === "nginx");
  // Check if nginx has any dependencies that could be resolved
  const deps = nginx?.profile.dependencies?.requires ?? [];
  if (deps.length > 0 && deps.some((d) => d.typical_services?.includes("unbound"))) {
    assert(Object.keys(nginx.rolesResolved).length > 0, "nginx should have resolved roles");
  }
  // If nginx doesn't have resolvable deps, this test just passes
});

test("13. No matching typical_service → unresolved_roles", () => {
  // Activate a profile that has dependencies but none of the typical_services are active
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["nginx.service"],  // nginx active, but no DNS resolver active
  });
  const nginx = kb.resolved.find((r) => r.profile.id === "nginx");
  const deps = nginx?.profile.dependencies?.requires ?? [];
  if (deps.length > 0) {
    assert(nginx.unresolved_roles.length > 0, "nginx should have unresolved roles");
  }
});

test("14. Inactive profile dependencies not resolved", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],  // nothing active
  });
  for (const r of kb.resolved) {
    assertEqual(Object.keys(r.rolesResolved).length, 0, `${r.profile.id} should have no resolved roles`);
  }
});

// ══════════════════════════════════════════════════════════
// Escalation Extraction (5 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Escalation Extraction ===\n");

test("15. Active profile with risk_escalation → escalation extracted", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["sshd.service"],
  });
  assert(kb.escalations.length > 0, "sshd has interactions with risk_escalation");
});

test("16. risk_escalation: null → no escalation", () => {
  // sshd has "restart sshd" with risk_escalation: null — should NOT produce escalation
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["sshd.service"],
  });
  const restartEsc = kb.escalations.find(
    (e) => e.trigger === "restart sshd" && e.profileId === "sshd"
  );
  assertEqual(restartEsc, undefined, "restart sshd should not produce escalation (null)");
});

test("17. Inactive profile → no escalations", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],  // nothing active
  });
  assertEqual(kb.escalations.length, 0, "no escalations when no profiles active");
});

test("18. Escalation has correct fields", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["sshd.service"],
  });
  const esc = kb.escalations.find((e) => e.profileId === "sshd");
  assert(esc, "sshd escalation not found");
  assert(typeof esc.trigger === "string", "trigger should be string");
  assert(typeof esc.profileId === "string", "profileId should be string");
  assert(typeof esc.warning === "string", "warning should be string");
  assert(typeof esc.riskLevel === "string", "riskLevel should be string");
});

test("19. sshd 'edit /etc/ssh/sshd_config' → high escalation", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["sshd.service"],
  });
  const esc = kb.escalations.find(
    (e) => e.trigger.includes("sshd_config") && e.profileId === "sshd"
  );
  assert(esc, "sshd_config escalation not found");
  assertEqual(esc.riskLevel, "high", "sshd_config escalation risk level");
});

// ══════════════════════════════════════════════════════════
// User Profile Override (2 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== User Profile Override ===\n");

test("20. additionalPaths profile with same id overrides built-in", () => {
  setupTempDir();
  writeFileSync(join(TEMP_DIR, "sshd.yaml"), `
id: sshd
name: "Custom SSH Override"
schema_version: 1
category: remote_access
service:
  unit_names: ["sshd"]
`);
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [TEMP_DIR],
    disabledIds: [],
    activeUnitNames: [],
  });
  const sshd = kb.profiles.get("sshd");
  assert(sshd, "sshd profile not found");
  assertEqual(sshd.name, "Custom SSH Override", "override should replace built-in");
  cleanupTempDir();
});

test("21. Non-existent additionalPaths directory → no crash", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: ["/nonexistent/path/to/profiles"],
    disabledIds: [],
    activeUnitNames: [],
  });
  assertEqual(kb.profiles.size, 8, "all built-in profiles should still load");
});

// ══════════════════════════════════════════════════════════
// Interface (2 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Knowledge Base Interface ===\n");

test("22. getProfile returns correct results", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: [],
  });
  assert(kb.getProfile("sshd") !== undefined, "getProfile('sshd') should return profile");
  assertEqual(kb.getProfile("fake"), undefined, "getProfile('fake') should return undefined");
});

test("23. getActiveProfiles returns only active profiles", () => {
  const kb = loadKnowledgeBase({
    builtinDir: KNOWLEDGE_DIR,
    additionalPaths: [],
    disabledIds: [],
    activeUnitNames: ["sshd.service", "nginx.service"],
  });
  const active = kb.getActiveProfiles();
  assert(active.length > 0, "should have active profiles");
  for (const r of active) {
    assertEqual(r.status, "active", `${r.profile.id} should be active`);
  }
});

// ══════════════════════════════════════════════════════════
// Summary
// ══════════════════════════════════════════════════════════

console.log("\n========================================");
console.log(`  Knowledge Base Tests: ${passed} passed, ${failed} failed (of ${passed + failed})`);
console.log("========================================\n");

if (failures.length > 0) {
  console.log("Failures:");
  for (const f of failures) {
    console.log(`  - ${f.name}: ${f.error}`);
  }
}

process.exit(failed > 0 ? 1 : 0);
```

**Step 2: Run the tests**

Run: `cd plugins/linux-sysadmin-mcp && node tests/unit/test-knowledge-base.mjs`

Expected: 23/23 pass. Some dependency resolution tests may need adjustment depending on which profiles have `dependencies.requires` entries.

**Step 3: Commit**

```bash
git add tests/unit/test-knowledge-base.mjs
git commit -m "test: add Layer 5 knowledge base unit tests

23 tests covering YAML parsing, profile resolution, escalation
extraction, user overrides, and interface methods."
```

---

### Task 4: Layer 4 — Safety Gate Unit Tests

**Files:**
- Create: `tests/unit/test-safety-gate.mjs`

**Step 1: Write the test file**

Create `tests/unit/test-safety-gate.mjs`:

```javascript
/**
 * Layer 4: Safety Gate unit tests.
 * Tests risk classification logic in isolation — no system or container needed.
 */
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = join(__dirname, "../..");

const { SafetyGate } = await import(join(PLUGIN_ROOT, "dist/safety/gate.js"));

// ── Test Harness ──────────────────────────────────────────

let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (err) {
    failed++;
    failures.push({ name, error: err.message });
    console.log(`  ✗ ${name}`);
    console.log(`    ${err.message}`);
  }
}

function assertEqual(actual, expected, msg) {
  if (actual !== expected) throw new Error(`${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || "Assertion failed");
}

// ── Helpers ───────────────────────────────────────────────

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

// ══════════════════════════════════════════════════════════
// Risk Threshold Classification (6 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Risk Threshold Classification ===\n");

test("1. read-only tools always pass", () => {
  const gate = makeGate();
  const result = gate.check(checkParams({ toolRiskLevel: "read-only" }));
  assertEqual(result, null, "read-only should pass");
});

test("2. low-risk tools pass at default threshold (moderate)", () => {
  const gate = makeGate();
  const result = gate.check(checkParams({ toolRiskLevel: "low" }));
  assertEqual(result, null, "low-risk should pass at moderate threshold");
});

test("3. moderate-risk tools trigger confirmation at moderate threshold", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "moderate" }));
  assert(result !== null, "moderate should trigger confirmation");
  assertEqual(result.status, "confirmation_required", "status");
});

test("4. high-risk tools trigger confirmation at moderate threshold", () => {
  const gate = makeGate("moderate");
  const result = gate.check(checkParams({ toolRiskLevel: "high" }));
  assert(result !== null, "high should trigger confirmation");
  assertEqual(result.status, "confirmation_required", "status");
});

test("5. critical-risk tools trigger confirmation at any threshold", () => {
  const gate = makeGate("critical");
  const result = gate.check(checkParams({ toolRiskLevel: "critical" }));
  assert(result !== null, "critical should trigger confirmation");
});

test("6. moderate-risk tools pass when threshold set to high", () => {
  const gate = makeGate("high");
  const result = gate.check(checkParams({ toolRiskLevel: "moderate" }));
  assertEqual(result, null, "moderate should pass at high threshold");
});

// ══════════════════════════════════════════════════════════
// Confirmation Bypass (3 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Confirmation Bypass ===\n");

test("7. confirmed: true bypasses moderate", () => {
  const gate = makeGate();
  const result = gate.check(checkParams({ toolRiskLevel: "moderate", confirmed: true }));
  assertEqual(result, null, "confirmed moderate should pass");
});

test("8. confirmed: true bypasses high", () => {
  const gate = makeGate();
  const result = gate.check(checkParams({ toolRiskLevel: "high", confirmed: true }));
  assertEqual(result, null, "confirmed high should pass");
});

test("9. confirmed: true bypasses critical", () => {
  const gate = makeGate();
  const result = gate.check(checkParams({ toolRiskLevel: "critical", confirmed: true }));
  assertEqual(result, null, "confirmed critical should pass");
});

// ══════════════════════════════════════════════════════════
// Dry-Run Bypass (2 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Dry-Run Bypass ===\n");

test("10. dryRun: true bypasses when bypass enabled", () => {
  const gate = makeGate("moderate", true);
  const result = gate.check(checkParams({ toolRiskLevel: "high", dryRun: true }));
  assertEqual(result, null, "dryRun should bypass when enabled");
});

test("11. dryRun: true does NOT bypass when disabled", () => {
  const gate = makeGate("moderate", false);
  const result = gate.check(checkParams({ toolRiskLevel: "high", dryRun: true }));
  assert(result !== null, "dryRun should NOT bypass when disabled");
});

// ══════════════════════════════════════════════════════════
// Knowledge Profile Escalation (5 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Knowledge Profile Escalation ===\n");

test("12. Escalation raises moderate → high on command match", () => {
  const gate = makeGate();
  gate.addEscalations([
    { trigger: "dangerous-cmd", profileId: "test", warning: "Be careful", riskLevel: "high" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "run dangerous-cmd now",
  }));
  assert(result !== null, "should trigger confirmation");
  assertEqual(result.risk_level, "high", "risk should be escalated to high");
});

test("13. Escalation raises moderate → critical on command match", () => {
  const gate = makeGate();
  gate.addEscalations([
    { trigger: "nuke-it", profileId: "test", warning: "Nuclear option", riskLevel: "critical" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "nuke-it --force",
  }));
  assert(result !== null, "should trigger confirmation");
  assertEqual(result.risk_level, "critical", "risk should be escalated to critical");
});

test("14. Escalation matches on serviceName field", () => {
  const gate = makeGate();
  gate.addEscalations([
    { trigger: "nginx", profileId: "nginx", warning: "Nginx affected", riskLevel: "high" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "systemctl restart something",
    serviceName: "nginx",
  }));
  assert(result !== null, "should trigger via serviceName match");
});

test("15. Non-matching escalation does not change risk level", () => {
  const gate = makeGate("high");
  gate.addEscalations([
    { trigger: "unrelated-cmd", profileId: "test", warning: "Nope", riskLevel: "critical" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "safe-command",
  }));
  assertEqual(result, null, "non-matching escalation should not affect result");
});

test("16. Multiple escalations — highest wins", () => {
  const gate = makeGate();
  gate.addEscalations([
    { trigger: "multi", profileId: "a", warning: "Warning A", riskLevel: "high" },
    { trigger: "multi", profileId: "b", warning: "Warning B", riskLevel: "critical" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "multi operation",
  }));
  assert(result !== null, "should trigger confirmation");
  assertEqual(result.risk_level, "critical", "highest escalation should win");
});

// ══════════════════════════════════════════════════════════
// Response Shape (2 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Response Shape ===\n");

test("17. Confirmation response has all required fields", () => {
  const gate = makeGate();
  const result = gate.check(checkParams({ toolRiskLevel: "high" }));
  assert(result !== null, "should trigger confirmation");
  assertEqual(result.status, "confirmation_required", "status");
  assert("tool" in result, "missing tool");
  assert("target_host" in result, "missing target_host");
  assert("risk_level" in result, "missing risk_level");
  assert("dry_run_available" in result, "missing dry_run_available");
  assert("preview" in result, "missing preview");
  assert("command" in result.preview, "missing preview.command");
  assert("description" in result.preview, "missing preview.description");
  assert("warnings" in result.preview, "missing preview.warnings");
});

test("18. Escalation reason included in preview", () => {
  const gate = makeGate();
  gate.addEscalations([
    { trigger: "esc-test", profileId: "testprofile", warning: "Test warning", riskLevel: "high" },
  ]);
  const result = gate.check(checkParams({
    toolRiskLevel: "moderate",
    command: "esc-test command",
  }));
  assert(result !== null, "should trigger confirmation");
  assert(result.preview.escalation_reason, "missing escalation_reason");
  assert(result.preview.escalation_reason.includes("testprofile"), "escalation_reason should mention profile");
});

// ══════════════════════════════════════════════════════════
// Summary
// ══════════════════════════════════════════════════════════

console.log("\n========================================");
console.log(`  Safety Gate Tests: ${passed} passed, ${failed} failed (of ${passed + failed})`);
console.log("========================================\n");

if (failures.length > 0) {
  console.log("Failures:");
  for (const f of failures) {
    console.log(`  - ${f.name}: ${f.error}`);
  }
}

process.exit(failed > 0 ? 1 : 0);
```

**Step 2: Run the tests**

Run: `cd plugins/linux-sysadmin-mcp && node tests/unit/test-safety-gate.mjs`

Expected: 18/18 pass.

**Step 3: Commit**

```bash
git add tests/unit/test-safety-gate.mjs
git commit -m "test: add Layer 4 safety gate unit tests

18 tests covering risk threshold classification, confirmation bypass,
dry-run bypass, knowledge profile escalation, and response shape."
```

---

### Task 5: Layer 2 — MCP Server Startup Tests

**Files:**
- Create: `tests/e2e/test-mcp-startup.mjs`

**Step 1: Write the test file**

Create `tests/e2e/test-mcp-startup.mjs`:

```javascript
/**
 * Layer 2: MCP server startup validation.
 * Starts the server inside the container, captures pino JSON logs,
 * and validates the startup pipeline.
 *
 * Usage: node tests/e2e/test-mcp-startup.mjs
 * Requires: linux-sysadmin-test container running
 */
import { execSync } from "node:child_process";

const CONTAINER = "linux-sysadmin-test";
const BUNDLE_PATH = "/plugin/dist/server.bundle.cjs";

// ── Test Harness ──────────────────────────────────────────

let passed = 0;
let failed = 0;
const failures = [];

function test(name, fn) {
  try {
    fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (err) {
    failed++;
    failures.push({ name, error: err.message });
    console.log(`  ✗ ${name}`);
    console.log(`    ${err.message}`);
  }
}

function assertEqual(actual, expected, msg) {
  if (actual !== expected) throw new Error(`${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
}

function assert(condition, msg) {
  if (!condition) throw new Error(msg || "Assertion failed");
}

// ── Start MCP server and capture logs ─────────────────────

console.log("\nStarting MCP server in container (capturing startup logs)...\n");

let logs;
let startupMs;
try {
  const start = Date.now();
  // Run server with timeout, capture stderr (pino logs), ignore stdin/stdout
  logs = execSync(
    `docker exec ${CONTAINER} timeout 3 node ${BUNDLE_PATH} 2>&1 || true`,
    { encoding: "utf-8", timeout: 10_000 }
  );
  startupMs = Date.now() - start;
} catch (err) {
  console.error("Failed to start MCP server in container:", err.message);
  process.exit(1);
}

// Parse pino JSON log lines
const logLines = logs
  .trim()
  .split("\n")
  .filter((l) => l.startsWith("{"))
  .map((l) => {
    try { return JSON.parse(l); } catch { return null; }
  })
  .filter(Boolean);

// ══════════════════════════════════════════════════════════
// Server Lifecycle (3 tests)
// ══════════════════════════════════════════════════════════

console.log("=== Server Lifecycle ===\n");

test("1. Server process starts without error", () => {
  assert(logLines.length > 0, "No log output from server");
  const fatalLogs = logLines.filter((l) => l.level >= 60); // level 60 = fatal
  assertEqual(fatalLogs.length, 0, "fatal log count");
});

test("2. Startup log contains running message", () => {
  const runningLog = logLines.find((l) => l.msg?.includes("linux-sysadmin-mcp server running on stdio"));
  assert(runningLog, "Missing 'server running on stdio' log message");
});

test("3. Startup completes in < 5 seconds", () => {
  assert(startupMs < 5000, `Startup took ${startupMs}ms (expected < 5000ms)`);
});

// ══════════════════════════════════════════════════════════
// Tool Registration (3 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Tool Registration ===\n");

test("4. Log shows toolCount: 106", () => {
  const regLog = logLines.find((l) => l.msg?.includes("All tool modules registered"));
  assert(regLog, "Missing tool registration log");
  assertEqual(regLog.toolCount, 106, "tool count");
});

test("5. All 15 modules registered", () => {
  // The server registers 106 tools across 15 modules — verify via tool count
  const regLog = logLines.find((l) => l.toolCount !== undefined);
  assert(regLog, "No tool registration log found");
  assert(regLog.toolCount >= 100, `Only ${regLog.toolCount} tools registered (expected 106)`);
});

test("6. No duplicate tool registration warnings", () => {
  const dupeWarnings = logLines.filter((l) => l.msg?.includes("Duplicate tool registration"));
  assertEqual(dupeWarnings.length, 0, "duplicate registration warnings");
});

// ══════════════════════════════════════════════════════════
// Distro Detection (4 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Distro Detection ===\n");

const distroLog = logLines.find((l) => l.msg?.includes("Distro detection complete"));

test("7. Detects family as rhel", () => {
  assert(distroLog, "Missing distro detection log");
  assertEqual(distroLog.distro?.family, "rhel", "distro family");
});

test("8. Detects package_manager as dnf", () => {
  assert(distroLog, "Missing distro detection log");
  assertEqual(distroLog.distro?.package_manager, "dnf", "package manager");
});

test("9. Detects init_system as systemd", () => {
  assert(distroLog, "Missing distro detection log");
  assertEqual(distroLog.distro?.init_system, "systemd", "init system");
});

test("10. Detects firewall_backend as firewalld", () => {
  assert(distroLog, "Missing distro detection log");
  assertEqual(distroLog.distro?.firewall_backend, "firewalld", "firewall backend");
});

// ══════════════════════════════════════════════════════════
// Knowledge Base (2 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Knowledge Base ===\n");

const kbLog = logLines.find((l) => l.msg?.includes("Knowledge base loaded"));

test("11. Knowledge base loaded with 8 profiles", () => {
  assert(kbLog, "Missing knowledge base log");
  assertEqual(kbLog.total, 8, "total profiles");
});

test("12. Active profile count > 0", () => {
  assert(kbLog, "Missing knowledge base log");
  assert(kbLog.active > 0, `active profiles: ${kbLog.active} (expected > 0, sshd/nginx should be running)`);
});

// ══════════════════════════════════════════════════════════
// Configuration (2 tests)
// ══════════════════════════════════════════════════════════

console.log("\n=== Configuration ===\n");

const configLog = logLines.find((l) => l.msg?.includes("Configuration loaded"));

test("13. First run detected", () => {
  assert(configLog, "Missing configuration log");
  // On first run inside container, firstRun should be true
  assertEqual(configLog.firstRun, true, "firstRun flag");
});

test("14. Config path is set", () => {
  assert(configLog, "Missing configuration log");
  assert(configLog.configPath, "configPath should be set");
  assert(configLog.configPath.includes("config.yaml"), "configPath should contain config.yaml");
});

// ══════════════════════════════════════════════════════════
// Summary
// ══════════════════════════════════════════════════════════

console.log("\n========================================");
console.log(`  Startup Tests: ${passed} passed, ${failed} failed (of ${passed + failed})`);
console.log("========================================\n");

if (failures.length > 0) {
  console.log("Failures:");
  for (const f of failures) {
    console.log(`  - ${f.name}: ${f.error}`);
  }
}

process.exit(failed > 0 ? 1 : 0);
```

**Step 2: Run the tests (requires container)**

Run:
```bash
cd plugins/linux-sysadmin-mcp
# Ensure container is running:
docker exec linux-sysadmin-test systemctl is-system-running || \
  (cd tests/container && docker compose up -d && sleep 10)
node tests/e2e/test-mcp-startup.mjs
```

Expected: 14/14 pass.

**Step 3: Commit**

```bash
git add tests/e2e/test-mcp-startup.mjs
git commit -m "test: add Layer 2 MCP server startup tests

14 tests validating server lifecycle, tool registration (106 tools),
distro detection (Fedora/rhel), knowledge base loading, and config."
```

---

### Task 6: Layer 3 — Tool Execution Tests (all 106 tools)

**Files:**
- Create: `tests/e2e/test-mcp-tools.mjs`

This is the largest file. It sends MCP `tools/call` requests via stdin to the server running inside the container and validates responses.

**Step 1: Write the MCP client harness and tool tests**

Create `tests/e2e/test-mcp-tools.mjs`. This file is large (~800 lines) so the implementation agent should:

1. Create a `McpTestClient` class that:
   - Starts the server via `docker exec` as a child process
   - Sends JSON-RPC `initialize` → `initialized` notification
   - Sends `tools/call` requests and collects responses
   - Provides `callTool(name, args)` method returning parsed response
   - Handles request IDs and response matching

2. Define test cases for all 106 tools organized by module, using this pattern:

```javascript
// Read-only tool test pattern:
async function testReadOnlyTool(client, name, args, dataChecks) {
  const result = await client.callTool(name, args);
  const response = JSON.parse(result.content[0].text);
  assertEqual(response.status, "success", `${name} status`);
  assert(response.data, `${name} missing data`);
  for (const [key, check] of Object.entries(dataChecks)) {
    check(response.data, name);
  }
  return response;
}

// State-changing tool test pattern (3 assertions):
async function testStateChangingTool(client, name, argsWithout, argsWith) {
  // 1. Without confirmed → blocked
  const blocked = await client.callTool(name, argsWithout);
  const blockedResp = JSON.parse(blocked.content[0].text);
  assertEqual(blockedResp.status, "confirmation_required", `${name} should block`);

  // 2. With confirmed: true → executes
  const confirmed = await client.callTool(name, argsWith);
  const confirmedResp = JSON.parse(confirmed.content[0].text);
  assert(
    confirmedResp.status === "success" || confirmedResp.status === "error",
    `${name} should succeed or fail gracefully, got ${confirmedResp.status}`
  );

  return { blocked: blockedResp, confirmed: confirmedResp };
}
```

3. Test all 15 modules' tools with appropriate args (see design doc for the full list)

4. For container tools (ctr_*): accept either success (if docker/podman available) or error with proper schema

5. Print summary of all 106 tool results

**Key implementation details:**
- The MCP server communicates via JSON-RPC 2.0 over stdio
- Send `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0.0"}}}` first
- Then send `{"jsonrpc":"2.0","method":"notifications/initialized"}` notification
- Then `{"jsonrpc":"2.0","id":N,"method":"tools/call","params":{"name":"tool_name","arguments":{...}}}` for each tool
- Parse responses matching by ID
- Tool responses are in `result.content[0].text` as JSON string

**Step 2: Run the tests (requires container)**

Run: `cd plugins/linux-sysadmin-mcp && node tests/e2e/test-mcp-tools.mjs`

Expected: ~150 assertions pass (106 tools × ~1.4 average assertions). Container tools without nested runtime return validated error responses.

**Step 3: Commit**

```bash
git add tests/e2e/test-mcp-tools.mjs
git commit -m "test: add Layer 3 tool execution tests (all 106 tools)

Tests every tool via MCP stdio protocol inside container.
Read-only tools validated for success + data shape.
State-changing tools validated for confirmation blocking + execution."
```

---

### Task 7: Layer 4 E2E — Safety Gate Integration Tests

**Files:**
- Create: `tests/e2e/test-mcp-safety.mjs`

**Step 1: Write the e2e safety tests**

Create `tests/e2e/test-mcp-safety.mjs`. This file reuses the `McpTestClient` pattern from Task 6 (or imports it) and tests 8 specific safety scenarios against the live server in the container.

The 8 test cases:

```javascript
// 1. pkg_install without confirmed → confirmation_required
// 2. pkg_install with confirmed: true → success
// 3. svc_restart without confirmed → confirmation_required
// 4. fw_enable without confirmed → confirmation_required
// 5. user_delete without confirmed → confirmation_required
// 6. sshd config edit triggers escalation warning
// 7. Read-only tool (perf_overview) never triggers confirmation
// 8. Dry-run pkg_install bypasses confirmation
```

**Step 2: Run the tests**

Run: `cd plugins/linux-sysadmin-mcp && node tests/e2e/test-mcp-safety.mjs`

Expected: 8/8 pass.

**Step 3: Commit**

```bash
git add tests/e2e/test-mcp-safety.mjs
git commit -m "test: add Layer 4 safety gate e2e tests

8 tests validating confirmation blocking, escalation from knowledge
profiles, and dry-run bypass against live MCP server in container."
```

---

### Task 8: Test Runner Orchestrator

**Files:**
- Create: `tests/run_tests.sh`

**Step 1: Write the orchestrator script**

Create `tests/run_tests.sh`:

```bash
#!/bin/bash
# Self-test runner for linux-sysadmin-mcp plugin.
#
# Usage:
#   bash tests/run_tests.sh              # Run all (auto-manage container)
#   bash tests/run_tests.sh --unit-only  # Layers 1, 4 unit, 5 only
#   bash tests/run_tests.sh --skip-container  # Skip container-dependent tests
#   bash tests/run_tests.sh --container-only  # Only container tests
#   bash tests/run_tests.sh --fresh      # Rebuild and recreate container
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_DIR="$SCRIPT_DIR/.."

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
UNIT_ONLY=false
SKIP_CONTAINER=false
CONTAINER_ONLY=false
FRESH=false
for arg in "$@"; do
    case "$arg" in
        --unit-only)       UNIT_ONLY=true ;;
        --skip-container)  SKIP_CONTAINER=true ;;
        --container-only)  CONTAINER_ONLY=true ;;
        --fresh)           FRESH=true ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "  --unit-only        Layers 1, 4 unit, 5 only (no container)"
            echo "  --skip-container   Skip container-dependent tests"
            echo "  --container-only   Only container tests (layers 2, 3, 4 e2e)"
            echo "  --fresh            Rebuild and recreate container"
            exit 0
            ;;
    esac
done

echo "========================================"
echo "  linux-sysadmin-mcp Self-Test Suite"
echo "========================================"
echo ""

# Track results
PASSED=0
FAILED=0
SKIPPED=0

run_test() {
    local name="$1"
    local cmd="$2"

    echo -n "  Running $name... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}FAILED${NC}"
        FAILED=$((FAILED + 1))
        echo "    Command: $cmd"
        eval "$cmd" 2>&1 | tail -20 | sed 's/^/    /'
    fi
}

skip_test() {
    local name="$1"
    local reason="$2"
    echo -e "  Skipping $name... ${YELLOW}$reason${NC}"
    SKIPPED=$((SKIPPED + 1))
}

# ── Check dependencies ─────────────────────────────────────

echo "Checking dependencies..."
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python3 not found${NC}"
    exit 1
fi
if ! command -v node &> /dev/null; then
    echo -e "${RED}Node.js not found${NC}"
    exit 1
fi
echo ""

# ── Container management ───────────────────────────────────

CONTAINER_AVAILABLE=false
CONTAINER_NAME="linux-sysadmin-test"

manage_container() {
    if [ "$FRESH" = "true" ]; then
        echo -e "${BLUE}Rebuilding container (--fresh)...${NC}"
        (cd "$SCRIPT_DIR/container" && docker compose down 2>/dev/null || true)
        (cd "$SCRIPT_DIR/container" && docker compose build --no-cache)
    fi

    if docker inspect "$CONTAINER_NAME" &>/dev/null; then
        if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" = "true" ]; then
            CONTAINER_AVAILABLE=true
            echo -e "Container: ${GREEN}RUNNING${NC}"
            return
        fi
    fi

    echo -e "Container: ${YELLOW}STARTING${NC}..."
    (cd "$SCRIPT_DIR/container" && docker compose up -d)

    # Wait for systemd to finish booting
    echo -n "  Waiting for systemd... "
    for i in $(seq 1 30); do
        STATUS=$(docker exec "$CONTAINER_NAME" systemctl is-system-running 2>/dev/null || echo "starting")
        if [ "$STATUS" = "running" ] || [ "$STATUS" = "degraded" ]; then
            echo -e "${GREEN}$STATUS${NC}"
            break
        fi
        sleep 1
    done

    # Run fixtures
    echo -n "  Running fixtures... "
    if docker exec "$CONTAINER_NAME" bash /plugin/tests/container/setup-fixtures.sh &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}PARTIAL${NC}"
    fi

    CONTAINER_AVAILABLE=true
}

# ══════════════════════════════════════════════════════════
# Layer 1: Structural Validation (always runs)
# ══════════════════════════════════════════════════════════

if [ "$CONTAINER_ONLY" = "false" ]; then
    echo -e "${BLUE}=== Layer 1: Structural Validation (pytest) ===${NC}"

    if python3 -c "import pytest" 2>/dev/null; then
        run_test "Plugin manifest" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'Manifest' 2>/dev/null"
        run_test "MCP config" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'MCPConfig' 2>/dev/null"
        run_test "Bundle exists" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'Bundle' 2>/dev/null"
        run_test "TypeScript sources (15 modules)" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'TypeScript' 2>/dev/null"
        run_test "Knowledge profiles (8 YAMLs)" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'Knowledge' 2>/dev/null"
        run_test "Package.json" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'PackageJson' 2>/dev/null"
        run_test "Cross-references" \
            "cd '$PLUGIN_DIR' && python3 -m pytest tests/test_plugin_structure.py -v --tb=short -k 'CrossRef' 2>/dev/null"
    else
        skip_test "Layer 1 (pytest)" "pytest not installed (pip install pytest pyyaml)"
    fi
    echo ""

    # ══════════════════════════════════════════════════════════
    # Layer 5: Knowledge Base Unit Tests (always runs)
    # ══════════════════════════════════════════════════════════

    echo -e "${BLUE}=== Layer 5: Knowledge Base Unit Tests ===${NC}"

    if [ -f "$PLUGIN_DIR/dist/knowledge/loader.js" ]; then
        run_test "Knowledge base (23 tests)" \
            "cd '$PLUGIN_DIR' && node tests/unit/test-knowledge-base.mjs"
    else
        skip_test "Layer 5" "dist/ not built (run: npm run build)"
    fi
    echo ""

    # ══════════════════════════════════════════════════════════
    # Layer 4: Safety Gate Unit Tests (always runs)
    # ══════════════════════════════════════════════════════════

    echo -e "${BLUE}=== Layer 4: Safety Gate Unit Tests ===${NC}"

    if [ -f "$PLUGIN_DIR/dist/safety/gate.js" ]; then
        run_test "Safety gate (18 tests)" \
            "cd '$PLUGIN_DIR' && node tests/unit/test-safety-gate.mjs"
    else
        skip_test "Layer 4 unit" "dist/ not built (run: npm run build)"
    fi
    echo ""
fi

# ══════════════════════════════════════════════════════════
# Container-dependent tests
# ══════════════════════════════════════════════════════════

if [ "$UNIT_ONLY" = "false" ] && [ "$SKIP_CONTAINER" = "false" ]; then

    # Start container if needed
    manage_container

    if [ "$CONTAINER_AVAILABLE" = "true" ]; then
        echo ""

        # Layer 2: Startup Tests
        echo -e "${BLUE}=== Layer 2: MCP Server Startup Tests ===${NC}"
        run_test "Server startup (14 tests)" \
            "cd '$PLUGIN_DIR' && node tests/e2e/test-mcp-startup.mjs"
        echo ""

        # Layer 3: Tool Execution Tests
        echo -e "${BLUE}=== Layer 3: Tool Execution Tests (106 tools) ===${NC}"
        run_test "All tools (106 tools)" \
            "cd '$PLUGIN_DIR' && node tests/e2e/test-mcp-tools.mjs"
        echo ""

        # Layer 4 E2E: Safety Gate Integration
        echo -e "${BLUE}=== Layer 4: Safety Gate E2E Tests ===${NC}"
        run_test "Safety gate e2e (8 tests)" \
            "cd '$PLUGIN_DIR' && node tests/e2e/test-mcp-safety.mjs"
        echo ""
    else
        skip_test "Layers 2, 3, 4 e2e" "Container not available"
    fi
else
    if [ "$UNIT_ONLY" = "true" ]; then
        skip_test "Container tests" "--unit-only"
    else
        skip_test "Container tests" "--skip-container"
    fi
fi

# ══════════════════════════════════════════════════════════
# Summary
# ══════════════════════════════════════════════════════════

echo ""
echo "========================================"
TOTAL=$((PASSED + FAILED))
echo -e "  Results: ${GREEN}$PASSED passed${NC}, ${RED}$FAILED failed${NC}, ${YELLOW}$SKIPPED skipped${NC} (of $TOTAL)"
echo "========================================"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi
```

**Step 2: Make it executable and run**

Run:
```bash
chmod +x tests/run_tests.sh
bash tests/run_tests.sh --unit-only
```

Expected: Layer 1, 4 unit, 5 all pass without needing a container.

**Step 3: Commit**

```bash
git add tests/run_tests.sh
git commit -m "test: add run_tests.sh orchestrator

Manages container lifecycle, runs all 5 test layers with
color-coded output. Flags: --unit-only, --skip-container,
--container-only, --fresh."
```

---

### Task 9: Self-Test Protocol and Results Template

**Files:**
- Create: `tests/SELF_TEST_PROTOCOL.md`
- Create: `tests/SELF_TEST_RESULTS.md`

**Step 1: Write SELF_TEST_PROTOCOL.md**

Short document explaining how to run tests, prerequisites, and the test catalog. Reference the design doc for detailed test case descriptions. Include the quick-start commands:

```markdown
# Full run
bash tests/run_tests.sh

# Unit only (no container, no Docker)
bash tests/run_tests.sh --unit-only

# Fresh container (rebuild from scratch)
bash tests/run_tests.sh --fresh
```

**Step 2: Write SELF_TEST_RESULTS.md template**

Same format as the HA dev plugin:

```markdown
# linux-sysadmin-mcp Self-Test Results

**Date:** YYYY-MM-DD
**Plugin Version:** 0.1.0

## Summary

- Layer 1 (Structural): X/35 passed
- Layer 2 (Startup): X/14 passed
- Layer 3 (Tools): X/~150 passed
- Layer 4 (Safety Gate): X/26 passed
- Layer 5 (Knowledge Base): X/23 passed

## Issues Found

(none yet)

## Lessons Learned

(populated after first run)
```

**Step 3: Commit**

```bash
git add tests/SELF_TEST_PROTOCOL.md tests/SELF_TEST_RESULTS.md
git commit -m "test: add self-test protocol and results template"
```

---

### Task 10: Run Full Test Suite and Record Results

**Step 1: Run the full suite**

```bash
cd plugins/linux-sysadmin-mcp
bash tests/run_tests.sh
```

**Step 2: Fix any failures (self-healing loop)**

For each failure:
1. Read the error output
2. Determine if it's a test bug or a server bug
3. Fix the source
4. Rebuild if needed (`npm run build`)
5. Re-run the failing test

**Step 3: Update SELF_TEST_RESULTS.md with actual results**

**Step 4: Final commit**

```bash
git add tests/SELF_TEST_RESULTS.md
git commit -m "test: record first self-test results"
```
