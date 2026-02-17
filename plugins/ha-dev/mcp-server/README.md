# Home Assistant Development MCP Server

An MCP (Model Context Protocol) server that connects Claude to Home Assistant instances for enhanced integration development.

## Features

### 🏠 Home Assistant Tools
| Tool | Description |
|------|-------------|
| `ha_connect` | Connect to a Home Assistant instance |
| `ha_get_states` | Query entity states with filtering |
| `ha_get_services` | List available services |
| `ha_call_service` | Call services (with safety controls) |
| `ha_get_devices` | Query device registry |
| `ha_get_logs` | Fetch and analyze logs |

### 📚 Documentation Tools
| Tool | Description |
|------|-------------|
| `docs_search` | Full-text search HA developer docs |
| `docs_fetch` | Fetch specific documentation pages |
| `docs_examples` | Get code examples for common patterns |

### ✅ Validation Tools
| Tool | Description |
|------|-------------|
| `validate_manifest` | Validate manifest.json for Core/HACS |
| `validate_strings` | Sync strings.json with config_flow.py |
| `check_patterns` | Detect 20+ anti-patterns and deprecations |

## Installation

```bash
npm install -g @anthropic/ha-dev-mcp-server
```

Or run directly with npx:
```bash
npx @anthropic/ha-dev-mcp-server
```

## Configuration

### Claude Desktop

Add to your Claude Desktop configuration:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
**Linux**: `~/.config/claude/claude_desktop_config.json`

```json
{
  "mcpServers": {
    "ha-dev": {
      "command": "npx",
      "args": ["-y", "@anthropic/ha-dev-mcp-server"],
      "env": {
        "HA_DEV_MCP_URL": "http://192.168.1.100:8123",
        "HA_DEV_MCP_TOKEN": "your-long-lived-access-token"
      }
    }
  }
}
```

### Getting a Home Assistant Token

1. Go to your Home Assistant instance
2. Click your profile (bottom left)
3. Scroll to "Long-Lived Access Tokens"
4. Click "Create Token"
5. Give it a name (e.g., "Claude MCP")
6. Copy the token (it won't be shown again)

### Configuration File (Optional)

For more control, create `~/.config/ha-dev-mcp/config.json`:

```json
{
  "homeAssistant": {
    "url": "http://192.168.1.100:8123",
    "token": "your-token-here",
    "verifySsl": true
  },
  "safety": {
    "allowServiceCalls": false,
    "blockedServices": [
      "homeassistant.restart",
      "homeassistant.stop"
    ],
    "requireDryRun": true
  },
  "features": {
    "enableDocsTools": true,
    "enableHaTools": true,
    "enableValidationTools": true
  }
}
```

## Usage Examples

### Connect and Query States

```
Connect to my Home Assistant at http://192.168.1.100:8123
```

```
Show me all sensor entities
```

```
What's the state of light.living_room?
```

### Query Devices and Services

```
List all devices from the hue integration
```

```
What services are available for the light domain?
```

### Validate Integration Code

```
Validate the manifest.json in /path/to/my_integration
```

```
Check /path/to/my_integration for anti-patterns
```

### Search Documentation

```
Search the HA docs for DataUpdateCoordinator
```

```
Show me a full example of a config flow
```

## Safety Features

### Service Call Protection

The server includes multiple layers of protection for service calls:

1. **Disabled by Default**: `allowServiceCalls: false`
2. **Dry-Run Mode**: Validates without executing (default)
3. **Blocklist**: Dangerous services are always blocked
4. **Safe Domains**: Helper entities (input_*, counter, timer) bypass dry-run

#### Always Blocked Services
- `homeassistant.stop`
- `hassio.host_shutdown`
- `hassio.host_reboot`

#### Blocked by Default
- `homeassistant.restart`
- `homeassistant.reload_all`
- `recorder.purge`

### To Enable Service Calls

Set in config file:
```json
{
  "safety": {
    "allowServiceCalls": true,
    "requireDryRun": false
  }
}
```

Or via environment:
```bash
HA_DEV_MCP_ALLOW_SERVICE_CALLS=true
```

### Token Security

- Tokens stored in memory only during runtime
- Never logged or included in error messages
- Config file should have restricted permissions: `chmod 600 config.json`

## Development

```bash
# Clone and install
git clone https://github.com/anthropic/ha-dev-mcp-server
cd mcp-server
npm install

# Build
npm run build

# Run locally
npm run dev

# Run tests
npm test

# Lint
npm run lint
```

## Architecture

```
src/
├── index.ts          # MCP server entry point
├── config.ts         # Configuration loading
├── ha-client.ts      # Home Assistant WebSocket client
├── safety.ts         # Service call safety checker
├── docs-index.ts     # Documentation search index
├── types.ts          # TypeScript interfaces
└── tools/
    ├── ha-connect.ts
    ├── ha-states.ts
    ├── ha-services.ts
    ├── ha-call-service.ts
    ├── ha-devices.ts
    ├── ha-logs.ts
    ├── docs-search.ts
    ├── docs-fetch.ts
    ├── docs-examples.ts
    ├── validate-manifest.ts
    ├── validate-strings.ts
    └── check-patterns.ts
```

## Requirements

- Node.js 18 or later
- Home Assistant 2024.1.0 or later (for full compatibility)

## Troubleshooting

### Connection Failed

1. Check the URL is correct (include port 8123)
2. Verify the token is valid and not expired
3. Ensure Home Assistant is accessible from your machine
4. Check if SSL verification is causing issues (`verifySsl: false`)

### Service Call Blocked

1. Check if service calls are enabled in config
2. Verify the service isn't in the blocklist
3. Try with `dry_run: true` first to validate

### Tool Not Available

1. Check if the feature is enabled in config
2. For HA tools, ensure you're connected first

## License

MIT
