# Self-Testing Framework Design

## Overview

A comprehensive self-testing framework for the linux-sysadmin-mcp plugin that validates all 106 MCP tools across 15 modules, the safety gate, knowledge base, and plugin structure. Tests execute inside a disposable Fedora container to safely exercise both read-only and state-changing tools.

## Architecture

```
┌──────────────────────────────────────────────────┐
│              Self-Test Framework                  │
├──────────────────────────────────────────────────┤
│ Layer 1: Structural Validation (pytest)          │
│   Plugin layout, manifest, .mcp.json, TypeScript │
│   sources, knowledge YAMLs, cross-references     │
│                                                  │
│ Layer 2: MCP Server Startup (Node.js)            │
│   Server starts, 106 tools register, distro      │
│   detection, knowledge base loads, safety gate   │
│                                                  │
│ Layer 3: Tool Execution (Node.js, container)     │
│   All 106 tools invoked and validated against     │
│   ToolResponse schema — read-only and state-     │
│   changing (with confirmed: true/false)          │
│                                                  │
│ Layer 4: Safety Gate (Node.js, unit + e2e)       │
│   Risk classification, threshold checks,         │
│   escalation rules, dry-run bypass, confirmation │
│                                                  │
│ Layer 5: Knowledge Base (Node.js, unit tests)    │
│   YAML parsing, profile resolution, active       │
│   service detection, escalation extraction       │
├──────────────────────────────────────────────────┤
│ Orchestration: run_tests.sh                      │
│   Container lifecycle, auto-detect, flags,       │
│   color-coded output, exit code 0/1              │
└──────────────────────────────────────────────────┘
```

## Test Container

A disposable Fedora 43 container with systemd acts as the test target. The MCP server runs inside the container directly (not via SSH).

### Container Setup

- **Base:** Fedora 43 with systemd (`/sbin/init` entrypoint)
- **Services:** sshd, nginx, crond, firewalld
- **User:** `testadmin` with passwordless sudo
- **Fixtures:** Cron entries, firewall rules, test users, sample log entries
- **Mount:** Plugin directory mounted at `/plugin` (read-only for source, writable dist)
- **Access:** `docker exec` for command execution

### Dockerfile

```dockerfile
FROM fedora:43
ENV container=docker

# systemd setup
RUN dnf -y install systemd && dnf clean all
RUN (cd /lib/systemd/system/sysinit.target.wants/ && \
     for i in *; do [ "$i" = "systemd-tmpfiles-setup.service" ] || rm -f "$i"; done)

# Services for testing
RUN dnf -y install \
    openssh-server nginx cronie firewalld \
    procps-ng iproute net-tools bind-utils \
    nodejs && dnf clean all

# Test user with passwordless sudo
RUN useradd -m testadmin && \
    echo "testadmin ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testadmin

# Enable services
RUN systemctl enable sshd nginx crond firewalld

VOLUME ["/sys/fs/cgroup"]
CMD ["/sbin/init"]
```

### docker-compose.yml

```yaml
services:
  linux-sysadmin-test:
    build: .
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

### setup-fixtures.sh

Runs inside the container after start to create known test state:

```bash
# Cron fixtures
echo "0 * * * * /bin/true # test-hourly" | crontab -u testadmin -

# Firewall fixtures
firewall-cmd --add-port=8080/tcp --permanent
firewall-cmd --reload

# User fixtures
useradd testuser-fixture
groupadd testgroup-fixture

# SSH fixtures
ssh-keygen -t ed25519 -f /home/testadmin/.ssh/id_ed25519 -N "" -q
mkdir -p /home/testadmin/.ssh
chown -R testadmin: /home/testadmin/.ssh

# Log fixtures
logger -t test-fixture "Self-test log entry for search validation"

# Backup target
mkdir -p /var/backups/linux-sysadmin
```

## File Structure

```
plugins/linux-sysadmin-mcp/
├── tests/
│   ├── run_tests.sh                    # Orchestrator
│   ├── test_plugin_structure.py        # Layer 1: pytest
│   ├── container/
│   │   ├── Dockerfile                  # Fedora 43 + systemd
│   │   ├── setup-fixtures.sh           # Test state initialization
│   │   └── docker-compose.yml          # One-command lifecycle
│   ├── e2e/
│   │   ├── test-mcp-startup.mjs        # Layer 2: startup validation
│   │   ├── test-mcp-tools.mjs          # Layer 3: all 106 tools
│   │   └── test-mcp-safety.mjs         # Layer 4: safety e2e
│   ├── unit/
│   │   ├── test-safety-gate.mjs        # Layer 4: pure unit tests
│   │   └── test-knowledge-base.mjs     # Layer 5: YAML + resolution
│   ├── SELF_TEST_PROTOCOL.md           # How to run
│   └── SELF_TEST_RESULTS.md            # Latest results
```

## Layer 1: Structural Validation (~35 tests)

Pytest-based tests that run anywhere (no Node.js, no container, no sudo).

### TestPluginManifest
- `.claude-plugin/plugin.json` exists, valid JSON
- Has required fields: name, version, description
- Name matches "linux-sysadmin-mcp"

### TestMCPConfig
- `.mcp.json` exists, valid JSON
- Points to `dist/server.bundle.cjs`
- Uses `${CLAUDE_PLUGIN_ROOT}` path variable

### TestBundleExists
- `dist/server.bundle.cjs` exists
- File size > 500KB (sanity check — current is 1.2MB)

### TestTypeScriptSources
- `src/server.ts` exists (entry point)
- All 15 tool module directories exist with `index.ts`
- Core infrastructure files present (logger, config/loader, distro/detector, execution/executor, safety/gate, knowledge/loader, tools/registry, tools/context, tools/helpers)
- All 8 type definition files present

### TestKnowledgeProfiles
- `knowledge/` directory has 8 YAML files
- Each YAML parses successfully
- Each has required fields: id, name, schema_version, category, service.unit_names
- Profile id matches filename (sshd.yaml has id: sshd)
- No duplicate IDs across profiles

### TestPackageJson
- `package.json` exists, valid JSON
- Has build script with esbuild bundle step
- Has start script pointing to bundle
- Dependencies include @modelcontextprotocol/sdk, pino, yaml, zod
- Does NOT include ssh2 (removed dead dependency)

### TestCrossReferences
- README.md tool module count matches actual (15)
- README.md knowledge profile count matches actual (8)
- `.gitignore` tracks `dist/server.bundle.cjs`
- `.gitignore` ignores `node_modules/` and tsc output

## Layer 2: MCP Server Startup (14 tests)

Node.js tests that start the server inside the container, capture pino JSON logs from stderr, and validate startup.

### Server Lifecycle (3)
1. Server process starts without error
2. Startup log contains "linux-sysadmin-mcp server running on stdio"
3. Startup completes in < 5 seconds

### Tool Registration (3)
4. Log shows `toolCount: 106`
5. All 15 modules registered
6. No "Duplicate tool registration" warnings

### Distro Detection (4)
7. Detects family as "rhel" (Fedora container)
8. Detects package_manager as "dnf"
9. Detects init_system as "systemd"
10. Detects firewall_backend as "firewalld"

### Knowledge Base (2)
11. Log shows "Knowledge base loaded" with total: 8
12. Active profile count > 0 (sshd/nginx running in container)

### Configuration (2)
13. Log shows firstRun: true on initial startup
14. Config file created at ~/.config/linux-sysadmin/config.yaml

## Layer 3: Tool Execution (~150 tests)

All 106 tools invoked inside the container via MCP stdio protocol. Each tool validated against ToolResponse schema. State-changing tools tested three ways:
1. Response schema conforms to ToolResponse
2. Without `confirmed` → returns `confirmation_required`
3. With `confirmed: true` → executes successfully

### Execution Order
1. Read-only tools first (safe, no side effects)
2. State-changing tools: first test without confirmation (blocked), then with confirmation (executes)
3. Cleanup tools last (user_delete, pkg_remove cleanup fixture state)

### Module Test Cases

| Module | Tools | Read-Only | State-Changing |
|--------|-------|-----------|----------------|
| session | 1 | 1 | 0 |
| packages | 10 | 4 | 6 |
| services | 10 | 3 | 7 |
| performance | 7 | 7 | 0 |
| logs | 4 | 4 | 0 |
| security | 7 | 6 | 1 |
| storage | 8 | 3 | 5 |
| users | 10 | 4 | 6 |
| firewall | 6 | 2 | 4 |
| networking | 8 | 5 | 3 |
| containers | 12 | 4 | 8 |
| cron | 5 | 3 | 2 |
| backup | 5 | 2 | 3 |
| ssh | 6 | 5 | 1 |
| docs | 8 | 5 | 3 |
| **Total** | **107** | **58** | **49** |

### Container Tools Strategy

Container tools (ctr_*) require Docker/Podman inside the container (nested containers). Two options:
- Install podman inside the test container (adds ~200MB)
- Accept `error` response for container tools and validate the error response schema instead

Decision: accept error responses for container tools if no nested runtime available. The error categorization and response schema are still validated.

## Layer 4: Safety Gate (26 tests)

### Unit Tests — test-safety-gate.mjs (18 tests, host only)

**Risk Threshold Classification (6)**
1. read-only tools always pass
2. low-risk tools pass at default threshold (moderate)
3. moderate-risk tools trigger confirmation at moderate threshold
4. high-risk tools trigger confirmation at moderate threshold
5. critical-risk tools trigger confirmation at any threshold
6. moderate-risk tools pass when threshold set to "high"

**Confirmation Bypass (3)**
7. `confirmed: true` bypasses moderate
8. `confirmed: true` bypasses high
9. `confirmed: true` bypasses critical

**Dry-Run Bypass (2)**
10. `dryRun: true` bypasses when `dry_run_bypass_confirmation` enabled
11. `dryRun: true` does NOT bypass when disabled

**Knowledge Profile Escalation (5)**
12. Escalation raises moderate → high on command match
13. Escalation raises moderate → critical on command match
14. Escalation matches on serviceName field
15. Non-matching escalation does not change risk level
16. Multiple escalations — highest wins

**Response Shape (2)**
17. Confirmation response has all required fields
18. Escalation reason included in `preview.escalation_reason`

### E2E Tests — test-mcp-safety.mjs (8 tests, container)

1. `pkg_install` without confirmed → `confirmation_required`
2. `pkg_install` with `confirmed: true` → success
3. `svc_restart` without confirmed → `confirmation_required`
4. `fw_enable` without confirmed → `confirmation_required`
5. `user_delete` without confirmed → `confirmation_required`
6. sshd config edit triggers escalation warning from profile
7. Read-only tool (`perf_overview`) never triggers confirmation
8. Dry-run `pkg_install` bypasses confirmation

## Layer 5: Knowledge Base (23 tests, host only)

### YAML Parsing & Validation (6)
1. All 8 built-in profiles parse without error
2. Each has required fields (id, name, schema_version, category, service.unit_names)
3. Profile id matches filename
4. All unit_names are non-empty strings
5. Malformed YAML is skipped (not crash)
6. Missing required field causes profile to be skipped

### Profile Resolution (5)
7. Matching unit_name → status: "active"
8. No matching unit_name → status: "inactive"
9. Matching on second unit_name (ssh vs sshd) → active
10. Empty activeUnitNames → all inactive
11. Disabled IDs excluded from results

### Dependency Role Resolution (3)
12. Active profile with matching typical_service → role resolved
13. No matching typical_service → unresolved_roles
14. Inactive profile dependencies not resolved

### Escalation Extraction (5)
15. Active profile with `risk_escalation` → escalation extracted
16. `risk_escalation: null` → no escalation
17. Inactive profile → no escalations
18. Escalation has correct trigger, profileId, warning, riskLevel
19. sshd "edit /etc/ssh/sshd_config" → high escalation

### User Profile Override (2)
20. additionalPaths profile with same id overrides built-in
21. Non-existent additionalPaths directory → no crash

### Interface (2)
22. `getProfile("sshd")` returns profile, `getProfile("fake")` → undefined
23. `getActiveProfiles()` returns only active profiles

## Test Runner: run_tests.sh

### Usage
```bash
bash tests/run_tests.sh              # Run all (auto-detect container)
bash tests/run_tests.sh --unit-only  # Layers 1, 4 unit, 5 only
bash tests/run_tests.sh --skip-container  # Skip layers 2, 3, 4 e2e
bash tests/run_tests.sh --container-only  # Only layers 2, 3, 4 e2e
```

### Workflow
1. Check dependencies (python3, pytest, node)
2. Run Layer 1 (pytest, always)
3. Run Layer 4 unit + Layer 5 unit (node, always)
4. Detect container availability
5. If container not running → start it, run setup-fixtures.sh
6. Run Layer 2 (startup tests)
7. Run Layer 3 (tool execution tests)
8. Run Layer 4 e2e (safety tests)
9. Print summary: passed/failed/skipped with color codes
10. Exit 0 if all pass, exit 1 if any fail

### Container Lifecycle
- `docker compose up -d` before e2e tests
- Wait for systemd to finish booting (check `systemctl is-system-running`)
- Run `setup-fixtures.sh` once
- Tests execute via `docker exec`
- Container left running (re-used across runs; `--fresh` flag to recreate)

## Self-Test Protocol Quick Start

```
# Full run (container auto-managed)
cd plugins/linux-sysadmin-mcp
bash tests/run_tests.sh

# Unit tests only (no container, no sudo)
bash tests/run_tests.sh --unit-only

# Container tests only
bash tests/run_tests.sh --container-only
```

## Test Count Summary

| Layer | File | Tests | Requires |
|-------|------|-------|----------|
| 1. Structural | test_plugin_structure.py | ~35 | Python only |
| 2. Startup | test-mcp-startup.mjs | 14 | Container |
| 3. Tool Execution | test-mcp-tools.mjs | ~150 | Container |
| 4. Safety Gate | test-safety-gate.mjs + test-mcp-safety.mjs | 26 | Host + Container |
| 5. Knowledge Base | test-knowledge-base.mjs | 23 | Host only |
| **Total** | | **~248** | |

## Self-Healing Protocol

When a test fails:

1. **Diagnose** — identify which layer and component failed
2. **Fix** — edit source, rebuild bundle (`npm run build`)
3. **Retest** — re-run the specific test layer
4. **Document** — update SELF_TEST_RESULTS.md with findings

## Lessons Learned

(Populated after first test run)
