# MCP Server Integration Plan

## Home Assistant Development MCP Server

A Model Context Protocol (MCP) server that connects Claude to Home Assistant instances and developer resources for enhanced integration development.

---

## Executive Summary

### Purpose
Enable Claude to interact with live Home Assistant instances during integration development, providing real-time validation, testing, and context.

### Key Benefits
1. **Live Validation** — Test integrations against running HA instances
2. **Real-time Context** — Query current entity states, services, device registry
3. **Dynamic Docs** — Fetch latest HA developer documentation
4. **Service Testing** — Safely test service calls in development mode
5. **Log Analysis** — Parse and analyze HA logs for debugging

### Implementation Complexity
- **Estimated Effort**: 3-5 days
- **Dependencies**: Node.js 18+, MCP SDK, Home Assistant WebSocket API
- **Risk Level**: Medium (requires user's HA instance access)

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Claude Desktop/Web                       │
└─────────────────────────┬───────────────────────────────────┘
                          │ MCP Protocol
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                  ha-dev-mcp-server                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ HA Tools    │  │ Docs Tools  │  │ Validation Tools    │  │
│  │             │  │             │  │                     │  │
│  │ • states    │  │ • search    │  │ • check_manifest    │  │
│  │ • services  │  │ • fetch     │  │ • check_strings     │  │
│  │ • devices   │  │ • examples  │  │ • check_patterns    │  │
│  │ • logs      │  │             │  │ • run_hassfest      │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
└─────────┼────────────────┼───────────────────┼──────────────┘
          │                │                   │
          ▼                ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Home Assistant  │ │ HA Dev Docs     │ │ Local Files     │
│ WebSocket API   │ │ (cached)        │ │ (integration)   │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| MCP Server | TypeScript + MCP SDK | Official SDK, type safety |
| HA Connection | WebSocket API | Real-time, bidirectional |
| Caching | In-memory + file | Fast lookups, offline support |
| Config | JSON/YAML | User-friendly |

---

## Tool Specifications

### Category 1: Home Assistant Connection

#### Tool: `ha_connect`
Establish connection to Home Assistant instance.

```typescript
interface HaConnectInput {
  url: string;           // e.g., "http://192.168.1.100:8123"
  token: string;         // Long-lived access token
  verify_ssl?: boolean;  // Default: true
}

interface HaConnectOutput {
  connected: boolean;
  version: string;       // e.g., "2025.2.0"
  location: string;      // Instance name
  components: string[];  // Loaded integrations
}
```

**Security**: Token stored in memory only, never logged.

#### Tool: `ha_get_states`
Query entity states from connected instance.

```typescript
interface HaGetStatesInput {
  domain?: string;       // Filter by domain (e.g., "sensor")
  entity_id?: string;    // Specific entity
  area?: string;         // Filter by area
}

interface HaGetStatesOutput {
  entities: Array<{
    entity_id: string;
    state: string;
    attributes: Record<string, any>;
    last_changed: string;
  }>;
  count: number;
}
```

#### Tool: `ha_get_services`
List available services.

```typescript
interface HaGetServicesInput {
  domain?: string;       // Filter by domain
}

interface HaGetServicesOutput {
  services: Array<{
    domain: string;
    service: string;
    name: string;
    description: string;
    fields: Record<string, ServiceField>;
  }>;
}
```

#### Tool: `ha_call_service`
Call a service (with safety restrictions).

```typescript
interface HaCallServiceInput {
  domain: string;
  service: string;
  data?: Record<string, any>;
  target?: {
    entity_id?: string | string[];
    device_id?: string | string[];
    area_id?: string | string[];
  };
  dry_run?: boolean;     // Default: true - just validate, don't execute
}

interface HaCallServiceOutput {
  success: boolean;
  dry_run: boolean;
  result?: any;
  error?: string;
}
```

**Safety**: 
- `dry_run: true` by default
- Blocked services: `homeassistant.restart`, `*.reload`, destructive actions
- Requires explicit confirmation for state-changing calls

#### Tool: `ha_get_devices`
Query device registry.

```typescript
interface HaGetDevicesInput {
  manufacturer?: string;
  model?: string;
  integration?: string;
}

interface HaGetDevicesOutput {
  devices: Array<{
    id: string;
    name: string;
    manufacturer: string;
    model: string;
    sw_version: string;
    via_device_id: string | null;
    area_id: string | null;
    config_entries: string[];
  }>;
}
```

#### Tool: `ha_get_logs`
Fetch and analyze Home Assistant logs.

```typescript
interface HaGetLogsInput {
  domain?: string;       // Filter by integration domain
  level?: "DEBUG" | "INFO" | "WARNING" | "ERROR";
  lines?: number;        // Last N lines (default: 100)
  since?: string;        // ISO timestamp
}

interface HaGetLogsOutput {
  entries: Array<{
    timestamp: string;
    level: string;
    source: string;
    message: string;
  }>;
  summary: {
    errors: number;
    warnings: number;
  };
}
```

### Category 2: Documentation Tools

#### Tool: `docs_search`
Search Home Assistant developer documentation.

```typescript
interface DocsSearchInput {
  query: string;
  section?: "core" | "frontend" | "architecture" | "api";
  limit?: number;        // Default: 5
}

interface DocsSearchOutput {
  results: Array<{
    title: string;
    url: string;
    snippet: string;
    relevance: number;
  }>;
}
```

**Implementation**: Pre-indexed documentation with full-text search.

#### Tool: `docs_fetch`
Fetch specific documentation page.

```typescript
interface DocsFetchInput {
  path: string;          // e.g., "core/integration-quality-scale"
}

interface DocsFetchOutput {
  title: string;
  content: string;       // Markdown
  last_updated: string;
  related: string[];     // Related page paths
}
```

#### Tool: `docs_examples`
Get code examples for specific patterns.

```typescript
interface DocsExamplesInput {
  pattern: "coordinator" | "config_flow" | "entity" | "service" | "sensor" | "switch" | "binary_sensor" | "light" | "climate";
  style?: "minimal" | "full";
}

interface DocsExamplesOutput {
  pattern: string;
  description: string;
  code: string;
  files: Array<{
    path: string;
    content: string;
  }>;
}
```

### Category 3: Validation Tools

#### Tool: `validate_manifest`
Validate manifest.json against HA requirements.

```typescript
interface ValidateManifestInput {
  path: string;          // Path to manifest.json
  mode?: "core" | "hacs"; // Default: "hacs"
}

interface ValidateManifestOutput {
  valid: boolean;
  errors: Array<{
    field: string;
    message: string;
  }>;
  warnings: Array<{
    field: string;
    message: string;
  }>;
}
```

#### Tool: `validate_strings`
Validate strings.json and sync with config_flow.py.

```typescript
interface ValidateStringsInput {
  path: string;          // Path to strings.json
}

interface ValidateStringsOutput {
  valid: boolean;
  missing_steps: string[];
  orphaned_steps: string[];
  missing_errors: string[];
  missing_data_descriptions: string[];
}
```

#### Tool: `check_patterns`
Check code for anti-patterns.

```typescript
interface CheckPatternsInput {
  path: string;          // File or directory path
}

interface CheckPatternsOutput {
  issues: Array<{
    file: string;
    line: number;
    pattern: string;
    message: string;
    severity: "error" | "warning";
    fix?: string;
  }>;
  summary: {
    errors: number;
    warnings: number;
  };
}
```

#### Tool: `run_hassfest`
Run hassfest validation (requires Docker).

```typescript
interface RunHassfestInput {
  path: string;          // Integration directory
}

interface RunHassfestOutput {
  success: boolean;
  output: string;
  errors: string[];
}
```

### Category 4: Development Utilities

#### Tool: `scaffold_integration`
Generate integration boilerplate.

```typescript
interface ScaffoldIntegrationInput {
  domain: string;
  name: string;
  platforms: string[];
  features: {
    coordinator: boolean;
    options_flow: boolean;
    reauth: boolean;
    diagnostics: boolean;
  };
  output_path: string;
}

interface ScaffoldIntegrationOutput {
  success: boolean;
  files_created: string[];
  next_steps: string[];
}
```

#### Tool: `compare_with_core`
Compare custom integration with core equivalent.

```typescript
interface CompareWithCoreInput {
  domain: string;        // Core integration to compare
  custom_path: string;   // Path to custom integration
}

interface CompareWithCoreOutput {
  differences: Array<{
    aspect: string;
    core: string;
    custom: string;
    recommendation: string;
  }>;
  missing_features: string[];
  extra_features: string[];
}
```

---

## Configuration

### Server Configuration File

Location: `~/.config/ha-dev-mcp/config.json`

```json
{
  "home_assistant": {
    "url": "http://192.168.1.100:8123",
    "token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "verify_ssl": true
  },
  "safety": {
    "allow_service_calls": false,
    "blocked_services": [
      "homeassistant.restart",
      "homeassistant.stop",
      "*.reload"
    ],
    "require_dry_run": true
  },
  "cache": {
    "docs_ttl_hours": 24,
    "states_ttl_seconds": 30
  },
  "features": {
    "enable_docs_tools": true,
    "enable_ha_tools": true,
    "enable_validation_tools": true
  }
}
```

### Environment Variables

```bash
# Alternative to config file
HA_DEV_MCP_URL=http://192.168.1.100:8123
HA_DEV_MCP_TOKEN=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
HA_DEV_MCP_VERIFY_SSL=true
```

---

## Implementation Phases

### Phase 1: Core Infrastructure (Day 1)

**Deliverables:**
- [ ] MCP server skeleton with TypeScript
- [ ] Configuration loading (file + env)
- [ ] Home Assistant WebSocket connection
- [ ] Basic error handling and logging

**Files:**
```
mcp-server/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts           # Entry point
│   ├── config.ts          # Configuration loading
│   ├── ha-client.ts       # HA WebSocket client
│   └── types.ts           # TypeScript interfaces
```

### Phase 2: HA Tools (Day 2)

**Deliverables:**
- [ ] `ha_connect` tool
- [ ] `ha_get_states` tool
- [ ] `ha_get_services` tool
- [ ] `ha_get_devices` tool

**Files:**
```
src/tools/
├── ha-connect.ts
├── ha-states.ts
├── ha-services.ts
└── ha-devices.ts
```

### Phase 3: Safety & Service Calls (Day 3)

**Deliverables:**
- [ ] Service call safety layer
- [ ] Blocked service list
- [ ] Dry-run implementation
- [ ] `ha_call_service` tool
- [ ] `ha_get_logs` tool

**Files:**
```
src/
├── safety.ts              # Safety checks
└── tools/
    ├── ha-call-service.ts
    └── ha-logs.ts
```

### Phase 4: Documentation Tools (Day 4)

**Deliverables:**
- [ ] Documentation indexing script
- [ ] `docs_search` tool
- [ ] `docs_fetch` tool
- [ ] `docs_examples` tool
- [ ] Caching layer

**Files:**
```
src/
├── docs-index.ts          # Doc indexing
├── cache.ts               # Caching layer
└── tools/
    ├── docs-search.ts
    ├── docs-fetch.ts
    └── docs-examples.ts
```

### Phase 5: Validation Tools (Day 5)

**Deliverables:**
- [ ] `validate_manifest` tool
- [ ] `validate_strings` tool
- [ ] `check_patterns` tool
- [ ] `run_hassfest` tool (Docker integration)

**Files:**
```
src/tools/
├── validate-manifest.ts
├── validate-strings.ts
├── check-patterns.ts
└── run-hassfest.ts
```

### Phase 6: Polish & Documentation (Day 6)

**Deliverables:**
- [ ] README with setup instructions
- [ ] Claude Desktop configuration guide
- [ ] Error messages and user feedback
- [ ] npm package preparation

---

## Security Considerations

### Token Handling
- Long-lived access tokens stored in config file with restricted permissions (600)
- Tokens never logged or included in error messages
- Memory-only storage during runtime

### Service Call Safety
1. **Blocked by Default**: `allow_service_calls: false`
2. **Blocklist**: Dangerous services cannot be called even if enabled
3. **Dry-Run**: Default mode validates without executing
4. **Confirmation**: State-changing calls require explicit flag

### Network Security
- SSL verification enabled by default
- No sensitive data in tool outputs
- Rate limiting to prevent API abuse

### Data Privacy
- Entity states may contain PII (names, locations)
- Logs may contain sensitive information
- Option to redact sensitive attributes

---

## Testing Strategy

### Unit Tests
- Tool input validation
- Safety layer checks
- Configuration parsing

### Integration Tests
- Mock HA WebSocket server
- End-to-end tool flows
- Error handling scenarios

### Manual Testing
- Claude Desktop integration
- Real HA instance testing
- Edge cases (offline, auth failure)

---

## Distribution

### npm Package
```bash
npm install -g @anthropic/ha-dev-mcp-server
```

### Claude Desktop Configuration
```json
{
  "mcpServers": {
    "ha-dev": {
      "command": "npx",
      "args": ["-y", "@anthropic/ha-dev-mcp-server"],
      "env": {
        "HA_DEV_MCP_URL": "http://192.168.1.100:8123",
        "HA_DEV_MCP_TOKEN": "your-token-here"
      }
    }
  }
}
```

### Docker (Alternative)
```bash
docker run -e HA_DEV_MCP_URL=... -e HA_DEV_MCP_TOKEN=... ha-dev-mcp-server
```

---

## Success Metrics

### Functionality
- [ ] All 15 tools implemented and working
- [ ] Connects to HA 2024.x and 2025.x instances
- [ ] Sub-second response time for cached operations

### Safety
- [ ] No destructive actions possible by default
- [ ] Clear warnings for state-changing operations
- [ ] Token never exposed in logs or outputs

### Usability
- [ ] Setup in under 5 minutes
- [ ] Clear error messages
- [ ] Comprehensive documentation

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| HA API changes | Tools break | Version detection, graceful degradation |
| Token compromise | Security breach | Memory-only storage, permission checks |
| Network issues | Poor UX | Caching, offline mode for docs |
| Docker requirement | Limited adoption | hassfest optional, clear error |

---

## Future Enhancements

### v1.1
- Automation analysis and suggestions
- Blueprint generation
- Integration dependency graphing

### v1.2
- Multi-instance support
- HA Cloud integration
- Performance profiling tools

### v2.0
- Visual debugging (entity graphs)
- Real-time log streaming
- Integration test runner
