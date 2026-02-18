# Home Assistant Development Plugin for Claude Code

## Design Document v2.0

**Document Version:** 2.0  
**Plugin Version:** 2.0.0  
**Last Updated:** February 2026  
**Status:** Complete

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Project Goals](#2-project-goals)
3. [Architecture Overview](#3-architecture-overview)
4. [Component Specifications](#4-component-specifications)
5. [Skills System](#5-skills-system)
6. [MCP Server](#6-mcp-server)
7. [Validation Scripts](#7-validation-scripts)
8. [Example Integrations](#8-example-integrations)
9. [Testing Infrastructure](#9-testing-infrastructure)
10. [Design Decisions](#10-design-decisions)
11. [Quality Assurance](#11-quality-assurance)
12. [Installation & Usage](#12-installation--usage)
13. [Future Roadmap](#13-future-roadmap)
14. [Appendices](#14-appendices)

---

## 1. Executive Summary

### 1.1 Purpose

The Home Assistant Development Plugin is a comprehensive Claude Code plugin that provides AI-assisted development capabilities for Home Assistant custom integrations. It encapsulates expert knowledge of Home Assistant's architecture, APIs, best practices, and the official Integration Quality Scale (IQS).

### 1.2 Problem Statement

Developing Home Assistant integrations is complex:
- Steep learning curve with evolving APIs
- 52 quality rules across 4 tiers (IQS)
- Deprecated patterns change with each HA release
- HACS compliance requirements
- Testing infrastructure complexity
- Documentation requirements

Developers need contextual guidance, automated validation, and reference implementations.

### 1.3 Solution

A Claude Code plugin providing:
- **19 specialized skills** covering all development aspects
- **3 workflow agents** for end-to-end tasks
- **5 validation scripts** with real-time feedback
- **3 example integrations** at Bronze, Silver, Gold tiers
- **MCP server** for live Home Assistant connectivity
- **Comprehensive test infrastructure** for self-validation

### 1.4 Key Metrics

| Metric | Value |
|--------|-------|
| Total Files | 116 |
| Skills | 19 |
| IQS Coverage | 100% (52/52 rules) |
| Example Tiers | Bronze, Silver, Gold |
| MCP Tools | 12 |
| Test Cases | 42 |

---

## 2. Project Goals

### 2.1 Primary Goals

1. **Accelerate Development**: Reduce time to create quality integrations from weeks to hours
2. **Ensure Quality**: Guide developers to meet IQS requirements from the start
3. **Stay Current**: Reflect Home Assistant 2024-2026 best practices
4. **Enable Self-Service**: Developers can scaffold, validate, and troubleshoot independently

### 2.2 Success Criteria

| Criterion | Target | Measurement |
|-----------|--------|-------------|
| IQS Rule Coverage | 100% | All 52 rules documented with examples |
| Pattern Detection | 20+ | Anti-patterns caught by validators |
| Example Quality | Gold tier | At least one Gold-tier reference |
| Test Coverage | 90%+ | Automated tests for core components |
| Documentation | Complete | Every component documented |

### 2.3 Non-Goals

- Runtime Home Assistant modifications (read-only MCP)
- GUI/visual tools (CLI and text-based only)
- Multi-language support (English only)
- Legacy HA versions (<2024.1)

---

## 3. Architecture Overview

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Claude Code                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    Plugin Interface                          ││
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    ││
│  │  │  Skills  │  │  Agents  │  │ Commands │  │  Hooks   │    ││
│  │  │   (19)   │  │   (3)    │  │   (2)    │  │   (3)    │    ││
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    ││
│  │       │             │             │             │           ││
│  │       └─────────────┴─────────────┴─────────────┘           ││
│  │                           │                                  ││
│  │  ┌────────────────────────┴────────────────────────┐        ││
│  │  │              Validation Layer                    │        ││
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │        ││
│  │  │  │  manifest   │ │   strings   │ │  patterns  │ │        ││
│  │  │  │  validator  │ │  validator  │ │  checker   │ │        ││
│  │  │  └─────────────┘ └─────────────┘ └────────────┘ │        ││
│  │  └─────────────────────────────────────────────────┘        ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                   │
│  ┌───────────────────────────┴───────────────────────────────┐  │
│  │                      MCP Server                            │  │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐      │  │
│  │  │HA Tools │  │Doc Tools│  │Validate │  │ Safety  │      │  │
│  │  │  (6)    │  │   (3)   │  │ Tools(3)│  │ Layer   │      │  │
│  │  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘      │  │
│  │       └────────────┴────────────┴────────────┘            │  │
│  │                         │                                  │  │
│  └─────────────────────────┼──────────────────────────────────┘  │
└─────────────────────────────┼─────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Home Assistant │
                    │   (WebSocket)   │
                    └─────────────────┘
```

### 3.2 Directory Structure

```
ha-dev-plugin-v2/
├── .claude-plugin/
│   └── plugin.json              # Plugin manifest
├── .github/
│   └── workflows/
│       └── test.yml             # CI/CD pipeline
├── skills/                      # 19 skill definitions
│   ├── ha-architecture/
│   │   └── SKILL.md
│   ├── ha-integration-scaffold/
│   │   └── SKILL.md
│   ├── ha-config-flow/
│   │   ├── SKILL.md
│   │   └── reference/
│   │       └── discovery-methods.md
│   ├── ha-coordinator/
│   │   └── SKILL.md
│   ├── ha-entity-platforms/
│   │   ├── SKILL.md
│   │   └── reference/
│   │       └── device-classes.md
│   ├── ha-service-actions/
│   │   └── SKILL.md
│   ├── ha-async-patterns/
│   │   └── SKILL.md
│   ├── ha-testing/
│   │   └── SKILL.md
│   ├── ha-debugging/
│   │   └── SKILL.md
│   ├── ha-yaml-automations/
│   │   └── SKILL.md
│   ├── ha-quality-review/
│   │   ├── SKILL.md
│   │   └── reference/
│   │       └── quality-scale-checklist.md
│   ├── ha-hacs/
│   │   └── SKILL.md
│   ├── ha-diagnostics/
│   │   └── SKILL.md
│   ├── ha-migration/
│   │   └── SKILL.md
│   ├── ha-documentation/
│   │   └── SKILL.md
│   ├── ha-repairs/
│   │   └── SKILL.md
│   ├── ha-device-triggers/
│   │   └── SKILL.md
│   ├── ha-websocket-api/
│   │   └── SKILL.md
│   └── ha-recorder/
│       └── SKILL.md
├── agents/                      # 3 workflow agents
│   ├── ha-integration-dev.md
│   ├── ha-integration-reviewer.md
│   └── ha-integration-debugger.md
├── commands/                    # 2 slash commands
│   ├── scaffold-integration.md
│   └── generate-integration.md
├── hooks/
│   └── hooks.json               # File-change hooks
├── scripts/                     # 5 validation scripts
│   ├── validate-manifest.py
│   ├── validate-strings.py
│   ├── check-patterns.py
│   ├── lint-integration.sh
│   └── generate-docs.py
├── templates/                   # Project templates
│   ├── testing/
│   │   ├── conftest.py.template
│   │   ├── test_config_flow.py.template
│   │   ├── test_init.py.template
│   │   ├── pytest.ini.template
│   │   └── requirements-test.txt.template
│   ├── ci/
│   │   ├── github-actions.yml.template
│   │   ├── pre-commit-config.yaml.template
│   │   └── ruff.toml.template
│   └── docs/
│       ├── README.md.template
│       └── info.md.template
├── examples/                    # 3 reference integrations
│   ├── minimal-sensor/          # Bronze tier
│   ├── push-integration/        # Silver tier
│   └── polling-hub/             # Gold tier
├── mcp-server/                  # TypeScript MCP server
│   ├── src/
│   │   ├── index.ts
│   │   ├── config.ts
│   │   ├── ha-client.ts
│   │   ├── safety.ts
│   │   ├── docs-index.ts
│   │   ├── types.ts
│   │   └── tools/
│   │       ├── ha-connect.ts
│   │       ├── ha-states.ts
│   │       ├── ha-services.ts
│   │       ├── ha-call-service.ts
│   │       ├── ha-devices.ts
│   │       ├── ha-logs.ts
│   │       ├── docs-search.ts
│   │       ├── docs-fetch.ts
│   │       ├── docs-examples.ts
│   │       ├── validate-manifest.ts
│   │       ├── validate-strings.ts
│   │       └── check-patterns.ts
│   ├── __tests__/
│   │   └── safety.test.ts
│   ├── package.json
│   ├── tsconfig.json
│   └── README.md
├── tests/                       # Test infrastructure
│   ├── conftest.py
│   ├── pytest.ini
│   ├── requirements.txt
│   ├── run_tests.sh
│   ├── scripts/
│   │   ├── test_validate_manifest.py
│   │   └── test_check_patterns.py
│   ├── validation/
│   │   └── test_iqs_accuracy.py
│   ├── integration/
│   │   └── test_scripts_against_examples.sh
│   ├── e2e/
│   │   └── E2E_CHECKLIST.md
│   └── fixtures/
│       └── manifests/
├── docs/                        # Design documents
│   ├── DESIGN_DOCUMENT.md       # This document
│   ├── TESTING_STRATEGY.md
│   ├── SELF_TEST_PROTOCOL.md
│   └── MCP_SERVER_PLAN.md
├── README.md
├── CHANGELOG.md
└── LICENSE
```

### 3.3 Data Flow

```
User Query
    │
    ▼
┌─────────────────┐
│ Claude Code     │
│ Context Window  │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────────────────────┐
│              Skill Matching                      │
│  (description field triggers skill loading)      │
└────────┬────────────────────────────────────────┘
         │
         ├──────────────────┬──────────────────┐
         ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Skill SKILL │    │   Agent     │    │   Command   │
│    .md      │    │  Workflow   │    │  Execution  │
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │                  │                  │
       └──────────────────┴──────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │   Code Generation     │
              │   or Information      │
              └───────────┬───────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Hooks     │  │  Validation │  │    MCP      │
│ (on save)   │  │   Scripts   │  │   Server    │
└─────────────┘  └─────────────┘  └──────┬──────┘
                                         │
                                         ▼
                                ┌─────────────────┐
                                │ Home Assistant  │
                                │   Instance      │
                                └─────────────────┘
```

---

## 4. Component Specifications

### 4.1 Plugin Manifest

**File:** `.claude-plugin/plugin.json`

```json
{
  "name": "home-assistant-dev",
  "version": "2.0.0",
  "description": "Comprehensive Home Assistant integration development toolkit...",
  "author": "Anthropic",
  "skills": "skills/",
  "agents": "agents/",
  "commands": "commands/",
  "hooks": "hooks/hooks.json"
}
```

### 4.2 Hooks Configuration

**File:** `hooks/hooks.json`

| Hook | Trigger | Files | Action |
|------|---------|-------|--------|
| validate-manifest | PostToolUse | `**/manifest.json` | Run manifest validator |
| validate-strings | PostToolUse | `**/strings.json`, `**/config_flow.py` | Sync check |
| check-patterns | PostToolUse | `**/custom_components/**/*.py` | Anti-pattern detection |

---

## 5. Skills System

### 5.1 Skill Architecture

Each skill follows Claude Code's Agent Skills format:

```markdown
---
name: ha-skill-name
description: Trigger description for context matching
disable-model-invocation: true
---

# Skill Title

## Content sections with patterns, examples, and guidance
```

### 5.2 Skill Inventory

#### Core Development Skills

| Skill | Purpose | Key Content |
|-------|---------|-------------|
| `ha-architecture` | HA internals understanding | Event bus, state machine, entity lifecycle |
| `ha-integration-scaffold` | Create new integrations | File structure, manifest, modern patterns |
| `ha-coordinator` | Data management | DataUpdateCoordinator, error handling, runtime_data |
| `ha-entity-platforms` | Entity implementation | Sensor, switch, light, etc. with device classes |
| `ha-async-patterns` | Async Python in HA | aiohttp, executors, avoiding blocking |

#### Configuration Skills

| Skill | Purpose | Key Content |
|-------|---------|-------------|
| `ha-config-flow` | User configuration | Config flows, options, reauth, reconfigure, discovery |
| `ha-service-actions` | Custom services | Registration, validation, entity targeting |
| `ha-yaml-automations` | YAML automation | Triggers, conditions, actions, blueprints |

#### Quality & Compliance Skills

| Skill | Purpose | Key Content |
|-------|---------|-------------|
| `ha-quality-review` | IQS compliance | All 52 rules with examples |
| `ha-hacs` | HACS submission | hacs.json, brands, repository structure |
| `ha-testing` | Test implementation | pytest patterns, MockConfigEntry |
| `ha-diagnostics` | Diagnostics support | Data collection, redaction |

#### Advanced Skills

| Skill | Purpose | Key Content |
|-------|---------|-------------|
| `ha-repairs` | Repair issues | Issue registry, fix flows |
| `ha-device-triggers` | Device automation | Trigger schemas, handlers |
| `ha-websocket-api` | Custom WS commands | Command registration, subscriptions |
| `ha-recorder` | Statistics/history | Long-term statistics, state classes |
| `ha-migration` | Version updates | Deprecation fixes, pattern updates |
| `ha-debugging` | Troubleshooting | Logging, common issues |
| `ha-documentation` | Doc generation | README templates, HACS info.md |

### 5.3 Skill Triggering

Skills are triggered by keyword matching in the `description` field:

```yaml
# Example: ha-config-flow triggers on these patterns
description: Config flows, options flows, reauth, reconfigure, 
  discovery (zeroconf, ssdp, dhcp, usb, bluetooth), 
  user input validation, multi-step flows
```

### 5.4 Progressive Disclosure

Large skills use `reference/` subdirectories:

```
skills/ha-entity-platforms/
├── SKILL.md                    # Main skill (concise)
└── reference/
    └── device-classes.md       # Detailed reference
```

---

## 6. MCP Server

### 6.1 Overview

The MCP (Model Context Protocol) server provides live connectivity to Home Assistant instances, enabling:
- Real-time entity state queries
- Service discovery and validation
- Documentation search
- Code validation

### 6.2 Tool Inventory

#### Home Assistant Tools

| Tool | Purpose | Safety Level |
|------|---------|--------------|
| `ha_connect` | Establish connection | Safe |
| `ha_get_states` | Query entity states | Safe (read-only) |
| `ha_get_services` | List available services | Safe (read-only) |
| `ha_call_service` | Execute service calls | Restricted (safety layer) |
| `ha_get_devices` | Query device registry | Safe (read-only) |
| `ha_get_logs` | Fetch HA logs | Safe (read-only) |

#### Documentation Tools

| Tool | Purpose |
|------|---------|
| `docs_search` | Full-text search of HA developer docs |
| `docs_fetch` | Retrieve specific documentation pages |
| `docs_examples` | Get code templates for patterns |

#### Validation Tools

| Tool | Purpose |
|------|---------|
| `validate_manifest` | Validate manifest.json |
| `validate_strings` | Check strings.json sync |
| `check_patterns` | Detect anti-patterns |

### 6.3 Safety Architecture

```
┌─────────────────────────────────────────────────┐
│                 Service Call                     │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│              Always Blocked?                     │
│  homeassistant.stop                             │
│  hassio.host_shutdown                           │
│  hassio.host_reboot                             │
└──────────────┬───────────────┬──────────────────┘
               │ Yes           │ No
               ▼               ▼
        ┌──────────┐   ┌─────────────────────┐
        │  BLOCK   │   │  Configurable       │
        └──────────┘   │  Blocklist?         │
                       └──────────┬──────────┘
                                  │
                       ┌──────────┴──────────┐
                       │ Yes                 │ No
                       ▼                     ▼
                ┌──────────┐         ┌─────────────────┐
                │  BLOCK   │         │  Safe Domain?   │
                └──────────┘         │  input_*, etc.  │
                                     └────────┬────────┘
                                              │
                                   ┌──────────┴──────────┐
                                   │ Yes                 │ No
                                   ▼                     ▼
                            ┌──────────┐         ┌─────────────────┐
                            │  ALLOW   │         │  Dry Run        │
                            └──────────┘         │  Required?      │
                                                 └────────┬────────┘
                                                          │
                                               ┌──────────┴──────────┐
                                               │ Yes && !dry_run     │ Otherwise
                                               ▼                     ▼
                                        ┌──────────┐          ┌──────────┐
                                        │  BLOCK   │          │  ALLOW   │
                                        └──────────┘          └──────────┘
```

### 6.4 Configuration

```typescript
interface MCPConfig {
  homeAssistant: {
    url: string;           // HA WebSocket URL
    token: string;         // Long-lived access token
  };
  safety: {
    allowServiceCalls: boolean;    // Default: false
    requireDryRun: boolean;        // Default: true
    blockedServices: string[];     // Additional blocks
    safeDomains: string[];         // Bypass dry-run
  };
  cache: {
    statesTtlSeconds: number;      // Default: 30
    docsTtlHours: number;          // Default: 24
  };
}
```

---

## 7. Validation Scripts

### 7.1 validate-manifest.py

**Purpose:** Validate manifest.json for Core and HACS compliance

**Checks:**
- Required fields (domain, name, codeowners, etc.)
- HACS-specific fields (version, issue_tracker)
- Field formats (semver, URLs, domain pattern)
- integration_type validity
- iot_class validity
- config_flow.py existence when config_flow: true

**Output:**
```
Validating: custom_components/my_integration/manifest.json
Mode: Custom Integration (HACS)

[ERROR] version: Invalid semver format '1.0'
[WARNING] codeowners: Empty codeowners list

❌ 1 error(s), 1 warning(s)
```

### 7.2 validate-strings.py

**Purpose:** Ensure strings.json and config_flow.py are synchronized

**Checks:**
- All config flow steps have string entries
- No orphaned string entries
- data_description presence (IQS requirement)
- Options flow string coverage

### 7.3 check-patterns.py

**Purpose:** Detect deprecated and anti-patterns

**Patterns Detected (23 total):**

| Category | Pattern | Severity |
|----------|---------|----------|
| Storage | `hass.data[DOMAIN]` | Warning |
| Storage | `hass.data.setdefault` | Warning |
| Imports | Old ServiceInfo locations | Warning |
| Blocking | `requests.get/post` | Error |
| Blocking | `time.sleep` | Error |
| Blocking | `urllib.request.urlopen` | Error |
| Typing | `List[]`, `Dict[]`, `Optional[]`, `Union[]` | Warning |
| Async | `@asyncio.coroutine` | Warning |
| Async | `yield from` | Warning |
| Coordinator | Missing generic type | Warning |
| OptionsFlow | `__init__` with config_entry | Warning |

### 7.4 lint-integration.sh

**Purpose:** Run all linters on an integration

**Tools:**
- ruff (lint + format check)
- mypy (type checking)
- validate-manifest.py
- validate-strings.py
- check-patterns.py

### 7.5 generate-docs.py

**Purpose:** Generate README.md and info.md from code

**Analysis:**
- Reads manifest.json for metadata
- Extracts PLATFORMS from __init__.py
- Parses config flow for features (reauth, reconfigure, options)
- Extracts entity translations from strings.json

---

## 8. Example Integrations

### 8.1 Tier Definitions

| Tier | Requirements | Example |
|------|--------------|---------|
| **Bronze** | Basic IQS compliance, config flow, unique IDs | minimal-sensor |
| **Silver** | + Reauth, error handling, unload | push-integration |
| **Gold** | + Diagnostics, reconfigure, full tests | polling-hub |

### 8.2 minimal-sensor (Bronze)

**Purpose:** Simplest possible integration for learning

**Files:**
```
custom_components/minimal_sensor/
├── __init__.py      # Simple setup, no coordinator
├── config_flow.py   # User step only
├── sensor.py        # Direct polling with async_update
├── manifest.json
└── strings.json
```

**Key Characteristics:**
- No DataUpdateCoordinator (deliberate simplicity)
- No options flow
- No reauth
- Simulated data

### 8.3 push-integration (Silver)

**Purpose:** Demonstrate push-based (event-driven) updates

**Files:**
```
custom_components/push_example/
├── __init__.py
├── config_flow.py
├── coordinator.py   # PushCoordinator with WebSocket
├── sensor.py        # Dispatcher-based updates
├── const.py
├── manifest.json
└── strings.json
```

**Key Characteristics:**
- `iot_class: local_push`
- PushCoordinator (not DataUpdateCoordinator)
- `async_dispatcher_connect` pattern
- Reconnection handling

### 8.4 polling-hub (Gold)

**Purpose:** Complete reference implementation

**Files:**
```
custom_components/example_hub/
├── __init__.py
├── config_flow.py   # User, reauth, reconfigure, options flows
├── coordinator.py   # Full DataUpdateCoordinator
├── entity.py        # Base entity class
├── sensor.py
├── diagnostics.py   # With redaction
├── const.py
├── manifest.json
├── strings.json
└── tests/
    ├── conftest.py
    └── test_config_flow.py
```

**Key Characteristics:**
- DataUpdateCoordinator with generic type
- `entry.runtime_data` pattern
- Complete config flows (user, reauth, reconfigure, options)
- Diagnostics with sensitive data redaction
- pytest tests

---

## 9. Testing Infrastructure

### 9.1 Test Categories

```
tests/
├── scripts/           # Unit tests for validators
├── validation/        # Documentation accuracy tests
├── integration/       # Cross-component tests
├── e2e/              # Manual workflow tests
└── fixtures/         # Test data
```

### 9.2 Test Matrix

| Component | Test Type | Tool | Tests |
|-----------|-----------|------|-------|
| validate-manifest.py | Unit | pytest | 9 |
| check-patterns.py | Unit | pytest | 10 |
| IQS documentation | Validation | pytest | 14 |
| Scripts vs examples | Integration | bash | 9 |
| MCP safety.ts | Unit | Jest | 12 |
| **Total** | | | **54** |

### 9.3 CI/CD Pipeline

**File:** `.github/workflows/test.yml`

**Jobs:**
1. `python-unit-tests` - pytest on scripts/validation
2. `typescript-tests` - Jest + typecheck + build
3. `integration-tests` - Scripts against examples
4. `validate-examples` - Matrix test all 3 examples
5. `lint` - Ruff on Python code
6. `skill-validation` - Frontmatter and consistency

### 9.4 Self-Testing Protocol

The plugin includes a protocol for Claude Code to test itself:

1. Install plugin via symlink (edits immediately active)
2. Run skill trigger tests (verify activation)
3. Run code generation tests (verify output quality)
4. Run validator tests (verify issue detection)
5. Fix any issues found
6. Retest

See `docs/SELF_TEST_PROTOCOL.md` for complete protocol.

---

## 10. Design Decisions

### 10.1 Why Skills Over Single Document?

**Decision:** 19 separate skills instead of one monolithic document

**Rationale:**
- Context window efficiency (load only relevant content)
- Focused triggers (better matching)
- Maintainability (update independently)
- Progressive disclosure (reference files for details)

### 10.2 Why runtime_data Over hass.data?

**Decision:** All examples use `entry.runtime_data`

**Rationale:**
- Modern pattern (HA 2024.8+)
- Type safety with generics
- Automatic cleanup on unload
- No manual dictionary management

### 10.3 Why TypeScript for MCP Server?

**Decision:** TypeScript instead of Python

**Rationale:**
- Official MCP SDK is TypeScript-first
- Better async patterns for WebSocket
- Type safety for tool interfaces
- Consistent with Claude Code ecosystem

### 10.4 Why Safety Layer for Service Calls?

**Decision:** Multi-level safety with dry-run default

**Rationale:**
- Prevent accidental system damage
- Always block destructive operations
- Allow safe domains (input_* helpers)
- Require explicit dry-run bypass

### 10.5 Why Three Example Tiers?

**Decision:** Bronze, Silver, Gold examples

**Rationale:**
- Learning progression
- Copy-paste starting points
- Demonstrate IQS compliance
- Different architecture patterns (polling vs push)

---

## 11. Quality Assurance

### 11.1 IQS Coverage Verification

All 52 IQS rules are documented in `ha-quality-review`:

| Tier | Rules | Coverage |
|------|-------|----------|
| Bronze | 18 | 18/18 ✓ |
| Silver | 10 | 10/10 ✓ |
| Gold | 21 | 21/21 ✓ |
| Platinum | 3 | 3/3 ✓ |

### 11.2 Deprecation Tracking

Tracked deprecations with versions:

| Pattern | Deprecated | Removed | Replacement |
|---------|------------|---------|-------------|
| ServiceInfo imports | 2025.1 | 2026.2 | helpers.service_info.* |
| OptionsFlow.__init__ | 2025.12 | TBD | self.config_entry property |
| hass.data[DOMAIN] | 2024.8 | TBD | entry.runtime_data |
| _async_setup | 2024.8 | N/A | Coordinator method |

### 11.3 Cross-Reference Integrity

Automated tests verify:
- All skill references exist
- README skill count matches directories
- Example manifests pass validators
- Code examples parse as valid Python

---

## 12. Installation & Usage

### 12.1 Installation

```bash
# Option 1: Direct installation
cp -r ha-dev-plugin-v2 ~/.claude/plugins/home-assistant-dev

# Option 2: Symlink (recommended for development)
ln -s /path/to/ha-dev-plugin-v2 ~/.claude/plugins/home-assistant-dev

# Option 3: Claude Code CLI (future)
claude plugins install home-assistant-dev
```

### 12.2 MCP Server Setup

```bash
# Install globally
cd mcp-server
npm install -g .

# Configure in Claude Desktop
# ~/.config/claude/claude_desktop_config.json
{
  "mcpServers": {
    "ha-dev": {
      "command": "ha-dev-mcp-server",
      "env": {
        "HA_DEV_MCP_URL": "ws://homeassistant.local:8123/api/websocket",
        "HA_DEV_MCP_TOKEN": "your-long-lived-access-token"
      }
    }
  }
}
```

### 12.3 Usage Examples

**Scaffold Integration:**
```
User: Create a new integration for my Acme thermostat
Claude: [Uses ha-integration-scaffold skill to generate files]
```

**Quality Review:**
```
User: Review my integration for IQS compliance
Claude: [Uses ha-quality-review skill, runs validators]
```

**Live HA Queries:**
```
User: What sensors are available in my Home Assistant?
Claude: [Uses MCP ha_get_states tool to query live HA]
```

---

## 13. Future Roadmap

### 13.1 Version 2.1 (Planned)

- [ ] Bluetooth device trigger skill
- [ ] Thread/Matter integration patterns
- [ ] Voice assistant integration skill
- [ ] Calendar entity patterns

### 13.2 Version 2.2 (Planned)

- [ ] GUI for MCP server configuration
- [ ] Integration template generator (interactive)
- [ ] HACS submission assistant
- [ ] Changelog generator

### 13.3 Version 3.0 (Future)

- [ ] Multi-integration project support
- [ ] Dependency analysis tools
- [ ] Performance profiling integration
- [ ] Automated PR generation for Core

---

## 14. Appendices

### 14.1 Glossary

| Term | Definition |
|------|------------|
| **IQS** | Integration Quality Scale - HA's official quality standard |
| **HACS** | Home Assistant Community Store |
| **MCP** | Model Context Protocol - Claude's tool interface |
| **Config Entry** | HA's configuration storage for integrations |
| **Coordinator** | DataUpdateCoordinator - centralized data fetching |
| **runtime_data** | Type-safe storage on config entries |

### 14.2 External References

- [HA Developer Documentation](https://developers.home-assistant.io/)
- [Integration Quality Scale](https://developers.home-assistant.io/docs/core/integration-quality-scale/)
- [HACS Documentation](https://hacs.xyz/)
- [MCP Specification](https://modelcontextprotocol.io/)
- [Claude Code Documentation](https://docs.anthropic.com/claude-code)

### 14.3 Changelog Summary

**v2.0.0** (Current)
- 19 skills (up from 11)
- MCP server with 12 tools
- 3 example integrations
- Complete test infrastructure
- 100% IQS coverage

**v1.0.0** (Initial)
- 11 skills
- 3 agents
- 1 command
- Basic structure

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0 | Feb 2026 | Claude | Complete rewrite for v2.0 |
| 1.0 | Feb 2026 | Claude | Initial design |
