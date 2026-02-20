# Self-Test Protocol: linux-sysadmin-mcp

## Quick Start

```bash
# Full run (container auto-managed)
cd plugins/linux-sysadmin-mcp
bash tests/run_tests.sh

# Unit tests only (no container, no sudo required)
bash tests/run_tests.sh --unit-only

# Container tests only (assumes container running)
bash tests/run_tests.sh --container-only

# Fresh container (rebuild and restart)
bash tests/run_tests.sh --fresh
```

## Prerequisites

- **Python 3.10+** with pytest and pyyaml
- **Node.js 20+** with npm
- **Docker 24+** or Podman 4+ (for Layers 2-3)
- **Bash 4+**

Install test dependencies:
```bash
pip install pytest pyyaml
npm install
npm run build
```

## 5-Layer Test Architecture

### Layer 1: Structural Validation (~92 tests)
Pytest-based validation of plugin layout, manifests, TypeScript sources, knowledge profiles, and cross-references. Runs anywhere without Docker or sudo. Validates bundle compilation, package.json dependencies, and YAML syntax across all 8 knowledge profiles.

### Layer 2: MCP Server Startup (14 tests)
Node.js tests inside a Fedora 43 container that verify the MCP server starts, all 106 tools register correctly, distro detection succeeds, and knowledge base loads. Validates JSON logging from pino and startup timing (<5 seconds). Container provides systemd, sshd, nginx, crond, firewalld services for realistic environment.

### Layer 3: Tool Execution (116 invocations / 1188 assertions)
All 106 tools executed via MCP stdio protocol inside the container, each validated against ToolResponse schema. State-changing tools tested twice: once without `confirmed` (blocked with `confirmation_required`), once with `confirmed: true` (succeeds). Read-only tools invoked once. Order: read-only first, then state-changing (unconfirmed, then confirmed), then cleanup tools.

Note: the "~150" estimate in early planning referred to tool invocations. Actual results show 116 invocations (106 tools, some with multiple test variants) producing 1188 individual assertion checks. "Tests" here means invocations, not assertions.

### Layer 4: Safety Gate (26 tests)
Two parts: **Unit tests** (18 tests on host) verify risk classification, confirmation bypass, dry-run override, and knowledge profile escalation logic deterministically. **E2E tests** (8 tests in container) validate that state-changing tools actually require confirmation and escalations are applied correctly for profile-matched commands.

### Layer 5: Knowledge Base (23 tests)
Unit tests validating YAML parsing, profile resolution against active services, dependency role extraction, and escalation detection. Verifies all 8 built-in profiles load, id matches filename, required fields present, activeUnitNames mapping works, and risk escalations extract correctly for sshd and other services.

## Test Catalog

| Layer | File | Test Count | Requires |
|-------|------|-----------|----------|
| 1. Structural | test_plugin_structure.py | 92 | Python only |
| 2. Startup | test-mcp-startup.mjs | 14 | Container (systemd) |
| 3. Tool Execution | test-mcp-tools.mjs | 116 invocations / 1188 assertions | Container (systemd) |
| 4. Safety Gate | test-safety-gate.mjs (18) + test-mcp-safety.mjs (8) | 26 | Host (unit) + Container (e2e) |
| 5. Knowledge Base | test-knowledge-base.mjs | 23 | Host only |
| **Total** | | **~305** | |

## Self-Healing Protocol

When a test fails:

1. **Diagnose** — Run the specific failing layer in isolation:
   ```bash
   pytest tests/test_plugin_structure.py -v     # Layer 1
   npm test -- --testPathPattern=startup         # Layer 2
   npm test -- --testPathPattern=tools           # Layer 3
   npm test -- --testPathPattern=safety-gate     # Layer 4 unit
   npm test -- --testPathPattern=knowledge-base  # Layer 5
   ```

2. **Fix** — Edit source file (src/server.ts, knowledge profiles, etc.), rebuild:
   ```bash
   npm run build
   ```

3. **Retest** — Re-run the specific failing test:
   ```bash
   bash tests/run_tests.sh --unit-only  # For quick layer 1/5 checks
   ```

4. **Document** — Update SELF_TEST_RESULTS.md with findings, root cause, and fix applied.

## Full Design Reference

For complete architecture, tool execution strategy, container setup, test organization, and expected test counts per module, see:

**`docs/plans/2026-02-17-self-testing-framework-design.md`**

## Troubleshooting

**Container won't start:**
```bash
docker compose -f tests/container/docker-compose.yml up -d
docker logs linux-sysadmin-test
```

**Fixtures not applied:**
```bash
docker exec linux-sysadmin-test bash /plugin/tests/container/setup-fixtures.sh
```

**Rebuild bundle and clear cache:**
```bash
rm -rf dist/ node_modules/
npm install
npm run build
bash tests/run_tests.sh --fresh
```

**Check container is ready:**
```bash
docker exec linux-sysadmin-test systemctl is-system-running
```

## Expected Results

All layers should pass. If tests fail, consult SELF_TEST_RESULTS.md for previous runs and the "Issues Found" section for known issues and fixes.
