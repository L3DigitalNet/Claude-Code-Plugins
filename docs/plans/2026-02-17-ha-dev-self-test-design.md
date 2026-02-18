# HA Dev Plugin Self-Test with Docker HA Instance

**Date:** 2026-02-17
**Status:** Approved

## Goal

Run the full self-test protocol for the home-assistant-dev plugin, specifically filling the MCP Server Tests gap (Category 5) that was N/A in the previous run.

## Architecture

### Phase 1: Docker HA Setup

- Location: `~/ha-plugin-test-workspace/`
- `docker-compose.yml` with `homeassistant/home-assistant:stable`
- Config directory: `~/ha-plugin-test-workspace/ha-config/`
- `configuration.yaml` with `demo:` platform enabled (~30 entities)
- Port 8123 on localhost
- Complete onboarding via REST API to obtain long-lived access token
- Configure MCP server via `~/.config/ha-dev-mcp/config.json`

### Phase 2: MCP Server Tests

Build the TypeScript MCP server, then test:
1. HA Connection — version, location, components
2. Entity Query — list sensor entities from demo platform
3. Service Discovery — light domain services
4. Dry Run — `light.turn_on` without execution

### Phase 3: Results

- Update `~/ha-plugin-test-workspace/SELF_TEST_RESULTS.md`
- Document issues found and fixes applied

## Key Decisions

- **Docker Compose + demo platform** chosen over HA Core pip install (reproducible, easy teardown) and mock WebSocket (doesn't test real behavior)
- Demo integration provides test entities without hardware
- MCP server connects via long-lived access token + WebSocket API
