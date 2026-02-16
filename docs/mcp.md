---
title: MCP Integration Reference
category: integration
target_platform: linux
audience: ai_agent
keywords: [mcp, model-context-protocol, external-tools, integrations]
---

# MCP Integration Reference

## Overview

**MCP (Model Context Protocol):** Standard for connecting AI to external services
**Provides:** External tools, resources, prompts, sampling **Configuration:**
`manifest.json` `mcpServers` field

**Capabilities:**

- External tools (callable functions)
- Resources (accessible data)
- Prompts (templates)
- Sampling (AI completions)

## Server Types

### Stdio (Standard I/O)

**Transport:** stdin/stdout **Use case:** Local processes, npm packages **Pros:**
Simple, universal **Cons:** One process per connection

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

### SSE (Server-Sent Events)

**Transport:** HTTP streaming **Use case:** Remote services, cloud deployments **Pros:**
Remote hosting, multiple clients **Cons:** Requires HTTP server

```json
{
  "mcpServers": {
    "remote-service": {
      "url": "https://api.example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      }
    }
  }
}
```

### HTTP Streaming

**Transport:** HTTP long-polling **Use case:** Firewall-friendly connections **Pros:**
Standard HTTP, NAT-friendly **Cons:** More complex than stdio

```json
{
  "mcpServers": {
    "api-server": {
      "url": "http://localhost:8080/mcp",
      "transport": "http"
    }
  }
}
```

## Configuration Schema

**Location:** `manifest.json` → `mcpServers` field

### Stdio Server Schema

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "mcpServers": {
    "server-name": {
      "command": "command-to-run",
      "args": ["arg1", "arg2"],
      "env": {
        "VARIABLE": "value"
      }
    }
  }
}
```

### Required fields

For stdio servers:

- **command**: Executable command
- **args**: Command arguments (optional)

For HTTP/SSE servers:

- **url**: Server endpoint

### Optional fields

```json
{
  "env": {
    "API_KEY": "${API_KEY}"
  },
  "timeout": 30000,
  "disabled": false,
  "scope": "user"
}
```

- **env**: Environment variables
- **timeout**: Request timeout in milliseconds
- **disabled**: Skip loading this server
- **scope**: Configuration scope (user/project/local)

## Environment variables

Reference environment variables with `${VAR_NAME}`:

```json
{
  "env": {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}",
    "API_URL": "${CUSTOM_API_URL:-https://api.default.com}"
  }
}
```

**With defaults**: `${VAR:-defaultValue}`

Users must set these in their environment:

```bash
export GITHUB_TOKEN=ghp_xxxxxxxxxxxx
claude
```

## Common MCP servers

### GitHub

```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**Tools**: Create issues, PRs, manage repos, search code **Setup**: Requires GitHub
personal access token

### GitLab

```json
{
  "mcpServers": {
    "gitlab": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-gitlab"],
      "env": {
        "GITLAB_TOKEN": "${GITLAB_TOKEN}",
        "GITLAB_URL": "${GITLAB_URL:-https://gitlab.com}"
      }
    }
  }
}
```

**Tools**: Manage issues, MRs, pipelines **Setup**: Requires GitLab access token

### Slack

```json
{
  "mcpServers": {
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
        "SLACK_TEAM_ID": "${SLACK_TEAM_ID}"
      }
    }
  }
}
```

**Tools**: Send messages, create channels, manage users **Setup**: Requires Slack app
with bot token

### PostgreSQL

```json
{
  "mcpServers": {
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "POSTGRES_CONNECTION_STRING": "${POSTGRES_CONNECTION_STRING}"
      }
    }
  }
}
```

**Tools**: Query database, inspect schema **Setup**: Requires connection string

### Filesystem

```json
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/allowed/path1",
        "/allowed/path2"
      ]
    }
  }
}
```

**Tools**: Read/write files outside workspace **Setup**: Specify allowed paths

## Creating custom MCP servers

### 1. Implement MCP protocol

Choose your language:

**Python** (FastMCP):

```python
from fastmcp import FastMCP

mcp = FastMCP("my-server")

@mcp.tool()
def my_tool(param: str) -> str:
    """Tool description."""
    return f"Result: {param}"

if __name__ == "__main__":
    mcp.run()
```

**TypeScript** (MCP SDK):

```typescript
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';

const server = new Server({
  name: 'my-server',
  version: '1.0.0',
});

server.setRequestHandler('tools/list', async () => ({
  tools: [
    {
      name: 'my_tool',
      description: 'Tool description',
      inputSchema: {
        type: 'object',
        properties: {
          param: { type: 'string' },
        },
      },
    },
  ],
}));

const transport = new StdioServerTransport();
await server.connect(transport);
```

### 2. Package as plugin

Create plugin with MCP server:

```
my-plugin/
├── .claude-plugin/
│   └── manifest.json
├── server/
│   ├── package.json
│   └── index.js
└── README.md
```

**manifest.json**:

```json
{
  "name": "my-plugin",
  "version": "1.0.0",
  "mcpServers": {
    "my-server": {
      "command": "node",
      "args": ["${PLUGIN_DIR}/server/index.js"]
    }
  }
}
```

Use `${PLUGIN_DIR}` to reference plugin directory.

### 3. Document requirements

In README.md, document:

- What the server does
- Required environment variables
- Installation steps
- Usage examples

## Authentication

### API tokens

Most common authentication method:

```json
{
  "env": {
    "API_TOKEN": "${SERVICE_API_TOKEN}"
  }
}
```

Document in README:

````markdown
## Setup

1. Get API token from https://service.com/tokens
2. Set environment variable:
   ```bash
   export SERVICE_API_TOKEN=your_token_here
   ```
````

3. Restart Claude Code

````

### OAuth

For OAuth services, use a helper server:

```json
{
  "mcpServers": {
    "oauth-service": {
      "command": "npx",
      "args": ["-y", "@myorg/oauth-server"],
      "env": {
        "CLIENT_ID": "${OAUTH_CLIENT_ID}",
        "CLIENT_SECRET": "${OAUTH_CLIENT_SECRET}"
      }
    }
  }
}
````

The server handles OAuth flow.

### Multiple credentials

Support multiple accounts:

```json
{
  "mcpServers": {
    "github-personal": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_PERSONAL_TOKEN}"
      }
    },
    "github-work": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_WORK_TOKEN}"
      }
    }
  }
}
```

## Resources

MCP servers can provide resources (data Claude can access):

```python
@mcp.resource("config://settings")
def get_settings() -> str:
    """Current application settings."""
    return json.dumps(load_settings())
```

Claude can read these with:

```
Show me the current settings
```

## Tool discovery

Claude automatically discovers available tools from MCP servers.

### Tool search

If many tools available, Claude searches by name/description:

```python
@mcp.tool()
def create_github_issue(title: str, body: str) -> dict:
    """Create a new GitHub issue.

    Args:
        title: Issue title
        body: Issue description
    """
    # Implementation
```

Good descriptions help Claude find relevant tools.

## Managed configuration

For complex services, provide managed config:

```json
{
  "mcpServers": {
    "complex-service": {
      "command": "npx",
      "args": ["-y", "@myorg/complex-server"],
      "managed": true,
      "config": {
        "endpoint": "https://api.example.com",
        "features": ["feature1", "feature2"],
        "rateLimit": 100
      }
    }
  }
}
```

Pass configuration via command args or stdin.

## Error handling

### Connection failures

If MCP server fails to start:

1. Claude logs error
2. Server marked as unavailable
3. Tools from that server disabled

View errors: `/plugin` → Errors tab

### Timeout handling

Set appropriate timeouts:

```json
{
  "timeout": 60000 // 60 seconds
}
```

For long-running operations, use async patterns.

### Retry logic

MCP servers should implement retries:

```python
import tenacity

@tenacity.retry(
    wait=tenacity.wait_exponential(min=1, max=10),
    stop=tenacity.stop_after_attempt(3)
)
def api_call():
    # Network request
    pass
```

## Performance

### Connection pooling

Reuse connections when possible:

```python
# Initialize once
client = APIClient(token=os.env["API_TOKEN"])

@mcp.tool()
def query_api(param: str):
    return client.query(param)  # Reuses connection
```

### Caching

Cache responses for expensive operations:

```python
from functools import lru_cache

@lru_cache(maxsize=128)
@mcp.tool()
def expensive_lookup(key: str):
    return slow_api_call(key)
```

### Streaming

For large responses, use streaming:

```python
@mcp.tool()
def large_data_query(filter: str):
    """Stream large dataset."""
    for chunk in query_database(filter):
        yield chunk
```

## Debugging

### Test server directly

Run server manually to see errors:

```bash
npx -y @modelcontextprotocol/server-github
```

Interact via stdin/stdout to test.

### Enable debug logging

Set debug environment variable:

```json
{
  "env": {
    "DEBUG": "mcp:*"
  }
}
```

### MCP Inspector

Use MCP inspector tool to test servers:

```bash
npx @modelcontextprotocol/inspector npx -y @modelcontextprotocol/server-github
```

### Check logs

Claude logs MCP activity:

```bash
claude --debug
```

Look for MCP connection and tool call logs.

## Security

### Validate inputs

Always validate tool inputs:

```python
@mcp.tool()
def delete_file(path: str):
    # Validate path is safe
    if ".." in path or path.startswith("/"):
        raise ValueError("Invalid path")

    # Proceed with deletion
```

### Least privilege

Only grant necessary permissions:

```python
# ✅ Good: Read-only access
client = GitHubClient(token, read_only=True)

# ❌ Bad: Full write access
client = GitHubClient(token, scope="admin:*")
```

### Secure credentials

Never hardcode secrets:

```python
# ❌ Bad
token = "ghp_xxxxxxxxxxxx"

# ✅ Good
token = os.environ["GITHUB_TOKEN"]
```

### Audit tool usage

Log tool calls for security monitoring:

```python
@mcp.tool()
def sensitive_operation(param: str):
    logger.info(f"Tool called with: {param}")
    # Implementation
```

## Examples

### Custom API integration

```json
{
  "name": "company-api-plugin",
  "version": "1.0.0",
  "mcpServers": {
    "company-api": {
      "command": "python",
      "args": ["-m", "company_mcp_server"],
      "env": {
        "API_KEY": "${COMPANY_API_KEY}",
        "API_URL": "${COMPANY_API_URL:-https://api.company.com}"
      }
    }
  }
}
```

### Multi-service plugin

```json
{
  "name": "dev-tools",
  "version": "1.0.0",
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    },
    "jira": {
      "command": "npx",
      "args": ["-y", "@myorg/jira-mcp-server"],
      "env": {
        "JIRA_TOKEN": "${JIRA_TOKEN}",
        "JIRA_URL": "${JIRA_URL}"
      }
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}"
      }
    }
  }
}
```

## Best practices

### Clear tool descriptions

Write helpful descriptions:

✅ Good: "Create a new GitHub issue with title and body" ❌ Vague: "Create issue"

### Type safety

Use proper type annotations:

```python
from typing import List, Dict

@mcp.tool()
def search_items(query: str, limit: int = 10) -> List[Dict[str, str]]:
    """Search items matching query."""
    pass
```

### Error messages

Provide actionable error messages:

```python
try:
    api_call()
except AuthError:
    raise Exception(
        "Authentication failed. "
        "Check that GITHUB_TOKEN is set correctly."
    )
```

### Documentation

Document each tool thoroughly:

```python
@mcp.tool()
def complex_operation(
    param1: str,
    param2: int,
    param3: bool = False
) -> dict:
    """Perform a complex operation.

    Args:
        param1: Description of param1
        param2: Description of param2
        param3: Optional flag for special behavior

    Returns:
        Dictionary containing:
        - result: Operation result
        - status: Success/failure status

    Raises:
        ValueError: If param1 is invalid
        APIError: If API request fails
    """
    pass
```

## Next steps

- [Create plugins](./plugins.md) to bundle MCP servers
- [Plugins reference](./plugins-reference.md) for technical details
- [Discover plugins](./discover-plugins.md) to find existing integrations
- [MCP documentation](https://modelcontextprotocol.io) for protocol details
