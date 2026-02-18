#!/usr/bin/env bash
# ==============================================================================
# setup-test-ha.sh — Automated Home Assistant Test Environment for MCP Server
# ==============================================================================
#
# Usage:
#   ./setup-test-ha.sh setup     Full setup: workspace, container, onboarding, LLAT, MCP config
#   ./setup-test-ha.sh teardown  Stop container, optionally remove data
#   ./setup-test-ha.sh status    Check if HA is running and responding
#   ./setup-test-ha.sh reset     Teardown + remove all data + setup from scratch
#
# Requirements:
#   - podman or docker (podman preferred — handles IPv6 better)
#   - curl, jq
#   - python3 with aiohttp (auto-installed if missing)
#
# Environment variables (all optional):
#   HA_TEST_WORKSPACE    Workspace directory (default: ~/ha-plugin-test-workspace)
#   HA_TEST_PORT         Port to expose HA on (default: 8123)
#   HA_TEST_TIMEOUT      Startup wait timeout in seconds (default: 180)
#   HA_TEST_USERNAME     Onboarding username (default: test)
#   HA_TEST_PASSWORD     Onboarding password (default: test1234)
#   HA_TEST_IMAGE        Container image (default: ghcr.io/home-assistant/home-assistant:stable)
#
set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

WORKSPACE="${HA_TEST_WORKSPACE:-$HOME/ha-plugin-test-workspace}"
PORT="${HA_TEST_PORT:-8123}"
TIMEOUT="${HA_TEST_TIMEOUT:-180}"
USERNAME="${HA_TEST_USERNAME:-test}"
PASSWORD="${HA_TEST_PASSWORD:-test1234}"
HA_IMAGE="${HA_TEST_IMAGE:-ghcr.io/home-assistant/home-assistant:stable}"
CONTAINER_NAME="ha-plugin-test"
HA_URL="http://localhost:${PORT}"
MCP_CONFIG_DIR="$HOME/.config/ha-dev-mcp"
MCP_CONFIG_FILE="$MCP_CONFIG_DIR/config.json"
TOKENS_FILE="$WORKSPACE/.ha-tokens.json"
CLIENT_ID="http://localhost:${PORT}/"

# ==============================================================================
# Color output helpers
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

pass()    { echo -e "  ${GREEN}[PASS]${NC} $*"; }
fail()    { echo -e "  ${RED}[FAIL]${NC} $*"; }
warn()    { echo -e "  ${YELLOW}[WARN]${NC} $*"; }
info()    { echo -e "  ${BLUE}[INFO]${NC} $*"; }
step()    { echo -e "\n${BOLD}${CYAN}==> $*${NC}"; }
substep() { echo -e "  ${BOLD}$*${NC}"; }

# ==============================================================================
# Container runtime detection
# ==============================================================================

CONTAINER_CMD=""
COMPOSE_CMD=""

detect_container_runtime() {
    step "Detecting container runtime"

    # Try podman first (better IPv6 handling)
    if command -v podman &>/dev/null; then
        CONTAINER_CMD="podman"
        # podman-compose or podman compose (v4+)
        if podman compose version &>/dev/null 2>&1; then
            COMPOSE_CMD="podman compose"
        elif command -v podman-compose &>/dev/null; then
            COMPOSE_CMD="podman-compose"
        else
            # Fall through to try docker
            :
        fi
    fi

    # If podman compose not available, try docker
    if [[ -z "$COMPOSE_CMD" ]]; then
        if command -v docker &>/dev/null; then
            CONTAINER_CMD="docker"
            if docker compose version &>/dev/null 2>&1; then
                COMPOSE_CMD="docker compose"
            elif command -v docker-compose &>/dev/null; then
                COMPOSE_CMD="docker-compose"
            fi
        fi
    fi

    if [[ -z "$CONTAINER_CMD" ]]; then
        fail "No container runtime found. Install podman or docker."
        exit 1
    fi

    if [[ -z "$COMPOSE_CMD" ]]; then
        fail "No compose command found. Install podman-compose or docker-compose."
        exit 1
    fi

    pass "Using ${CONTAINER_CMD} (compose: ${COMPOSE_CMD})"
}

# ==============================================================================
# Prerequisite checks
# ==============================================================================

check_prerequisites() {
    step "Checking prerequisites"
    local missing=0

    for cmd in curl jq python3; do
        if command -v "$cmd" &>/dev/null; then
            pass "$cmd found: $(command -v "$cmd")"
        else
            fail "$cmd not found — please install it"
            missing=1
        fi
    done

    if (( missing )); then
        exit 1
    fi

    # Check aiohttp availability
    if python3 -c "import aiohttp" &>/dev/null 2>&1; then
        pass "python3 aiohttp module available"
    else
        warn "python3 aiohttp module not found — will attempt to install"
    fi
}

# ==============================================================================
# Ensure aiohttp is installed
# ==============================================================================

ensure_aiohttp() {
    if python3 -c "import aiohttp" &>/dev/null 2>&1; then
        return 0
    fi

    substep "Installing aiohttp for Python WebSocket support..."

    # Try pip, pipx, or uv
    if command -v uv &>/dev/null; then
        uv pip install --system aiohttp 2>/dev/null || uv pip install aiohttp 2>/dev/null
    elif command -v pip3 &>/dev/null; then
        pip3 install --user aiohttp 2>/dev/null || pip3 install aiohttp 2>/dev/null
    elif command -v pip &>/dev/null; then
        pip install --user aiohttp 2>/dev/null || pip install aiohttp 2>/dev/null
    else
        fail "Cannot install aiohttp: no pip/uv found. Install manually: pip install aiohttp"
        exit 1
    fi

    if python3 -c "import aiohttp" &>/dev/null 2>&1; then
        pass "aiohttp installed successfully"
    else
        fail "Failed to install aiohttp. Install manually: pip install aiohttp"
        exit 1
    fi
}

# ==============================================================================
# Workspace setup
# ==============================================================================

create_workspace() {
    step "Setting up workspace at ${WORKSPACE}"

    if [[ -d "$WORKSPACE" ]]; then
        pass "Workspace directory already exists"
    else
        mkdir -p "$WORKSPACE"
        pass "Created workspace directory"
    fi

    mkdir -p "$WORKSPACE/ha-config"
}

create_docker_compose() {
    local compose_file="$WORKSPACE/docker-compose.yml"

    if [[ -f "$compose_file" ]]; then
        pass "docker-compose.yml already exists"
        return 0
    fi

    substep "Creating docker-compose.yml..."
    cat > "$compose_file" <<YAML
services:
  homeassistant:
    container_name: ${CONTAINER_NAME}
    image: ${HA_IMAGE}
    volumes:
      - ./ha-config:/config
    ports:
      - "${PORT}:8123"
    restart: unless-stopped
YAML
    pass "Created docker-compose.yml"
}

create_ha_config() {
    local config_file="$WORKSPACE/ha-config/configuration.yaml"

    if [[ -f "$config_file" ]]; then
        pass "configuration.yaml already exists"
        return 0
    fi

    substep "Creating Home Assistant configuration.yaml..."
    cat > "$config_file" <<YAML
homeassistant:
  name: HA Dev Plugin Test
  unit_system: metric
  time_zone: America/New_York

# Enable demo integration for test entities
demo:

# Enable API access
api:

# Enable default config (frontend, system health, etc.)
default_config:

# Logging
logger:
  default: info
  logs:
    homeassistant.components.demo: debug
YAML
    pass "Created configuration.yaml"
}

# ==============================================================================
# Container management
# ==============================================================================

is_container_running() {
    $CONTAINER_CMD inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true
}

is_container_exists() {
    $CONTAINER_CMD inspect "$CONTAINER_NAME" &>/dev/null 2>&1
}

start_container() {
    step "Starting Home Assistant container"

    if is_container_running; then
        pass "Container '$CONTAINER_NAME' is already running"
        return 0
    fi

    substep "Pulling image and starting container..."
    info "This may take a few minutes on first run (downloading ~1GB image)"

    # Attempt to start with compose
    local pull_output
    if ! pull_output=$($COMPOSE_CMD -f "$WORKSPACE/docker-compose.yml" up -d 2>&1); then
        # Check for IPv6 pull failure (common with docker)
        if echo "$pull_output" | grep -qi "ipv6\|network.*unreachable\|dial tcp6"; then
            fail "Container image pull failed — likely an IPv6 connectivity issue"
            if [[ "$CONTAINER_CMD" == "docker" ]]; then
                warn "Docker often has IPv6 pull issues. Try installing podman instead:"
                warn "  sudo dnf install podman podman-compose   # Fedora/RHEL"
                warn "  sudo apt install podman podman-compose   # Debian/Ubuntu"
            fi
            echo "$pull_output" >&2
            exit 1
        fi
        fail "Failed to start container"
        echo "$pull_output" >&2
        exit 1
    fi

    pass "Container started"
}

stop_container() {
    step "Stopping Home Assistant container"

    if ! is_container_exists; then
        info "Container '$CONTAINER_NAME' does not exist — nothing to stop"
        return 0
    fi

    $COMPOSE_CMD -f "$WORKSPACE/docker-compose.yml" down 2>/dev/null || true
    pass "Container stopped"
}

# ==============================================================================
# Wait for HA to be ready
# ==============================================================================

wait_for_ha() {
    step "Waiting for Home Assistant to be ready (timeout: ${TIMEOUT}s)"

    local elapsed=0
    local interval=3

    while (( elapsed < TIMEOUT )); do
        # Check if HA API responds
        local http_code
        http_code=$(curl -s -o /dev/null -w '%{http_code}' "${HA_URL}/api/" 2>/dev/null || echo "000")

        if [[ "$http_code" == "401" || "$http_code" == "200" ]]; then
            pass "Home Assistant is responding (HTTP ${http_code}) after ${elapsed}s"
            return 0
        fi

        # Show progress
        printf "  Waiting... %3ds / %ds (HTTP %s)\r" "$elapsed" "$TIMEOUT" "$http_code"
        sleep "$interval"
        elapsed=$(( elapsed + interval ))
    done

    echo  # Clear the progress line
    fail "Home Assistant did not respond within ${TIMEOUT}s"
    fail "Check logs: ${CONTAINER_CMD} logs ${CONTAINER_NAME}"
    exit 1
}

# ==============================================================================
# Onboarding check
# ==============================================================================

is_onboarding_done() {
    # If onboarding is done, /api/onboarding returns an empty list []
    # If not done, it returns a list of remaining steps
    local response
    response=$(curl -s "${HA_URL}/api/onboarding" 2>/dev/null || echo "error")

    if [[ "$response" == "error" ]]; then
        return 1
    fi

    # If the response is an empty array, onboarding is complete
    local count
    count=$(echo "$response" | jq 'length' 2>/dev/null || echo "-1")

    if [[ "$count" == "0" ]]; then
        return 0  # Onboarding complete
    else
        return 1  # Onboarding still needed
    fi
}

# ==============================================================================
# Onboarding
# ==============================================================================

complete_onboarding() {
    step "Completing Home Assistant onboarding"

    # Check if already onboarded
    if is_onboarding_done; then
        pass "Onboarding already completed"

        # Check if we have saved tokens
        if [[ -f "$TOKENS_FILE" ]]; then
            pass "Tokens file exists at ${TOKENS_FILE}"
            return 0
        else
            warn "Onboarding was completed in a previous session but tokens file is missing"
            warn "You may need to reset: $0 reset"
            # We can still proceed if an LLAT was already created
            return 0
        fi
    fi

    # -------------------------------------------------------------------------
    # Step 1: Create user account
    # -------------------------------------------------------------------------
    substep "Step 1/5: Creating user account (${USERNAME})..."

    local user_response
    user_response=$(curl -s -X POST "${HA_URL}/api/onboarding/users" \
        -H "Content-Type: application/json" \
        -d "{
            \"client_id\": \"${CLIENT_ID}\",
            \"name\": \"Test User\",
            \"username\": \"${USERNAME}\",
            \"password\": \"${PASSWORD}\",
            \"language\": \"en\"
        }" 2>/dev/null)

    local auth_code
    auth_code=$(echo "$user_response" | jq -r '.auth_code // empty' 2>/dev/null)

    if [[ -z "$auth_code" ]]; then
        fail "Failed to create user account"
        fail "Response: ${user_response}"
        exit 1
    fi
    pass "User account created, auth_code received"

    # -------------------------------------------------------------------------
    # Step 2: Exchange auth code for tokens
    # -------------------------------------------------------------------------
    substep "Step 2/5: Exchanging auth code for access tokens..."

    local token_response
    token_response=$(curl -s -X POST "${HA_URL}/auth/token" \
        -d "grant_type=authorization_code" \
        -d "code=${auth_code}" \
        -d "client_id=${CLIENT_ID}" 2>/dev/null)

    local access_token refresh_token
    access_token=$(echo "$token_response" | jq -r '.access_token // empty' 2>/dev/null)
    refresh_token=$(echo "$token_response" | jq -r '.refresh_token // empty' 2>/dev/null)

    if [[ -z "$access_token" ]]; then
        fail "Failed to exchange auth code for tokens"
        fail "Response: ${token_response}"
        exit 1
    fi

    # Save tokens to workspace
    cat > "$TOKENS_FILE" <<JSON
{
    "access_token": "${access_token}",
    "refresh_token": "${refresh_token}",
    "token_type": "Bearer"
}
JSON
    chmod 600 "$TOKENS_FILE"
    pass "Access tokens obtained and saved to ${TOKENS_FILE}"

    # -------------------------------------------------------------------------
    # Step 3: Core config onboarding
    # -------------------------------------------------------------------------
    substep "Step 3/5: Completing core configuration..."

    local core_response
    core_response=$(curl -s -X POST "${HA_URL}/api/onboarding/core_config" \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null)

    # Check for error
    if echo "$core_response" | jq -e '.message' &>/dev/null 2>&1; then
        local errmsg
        errmsg=$(echo "$core_response" | jq -r '.message')
        if [[ "$errmsg" != "null" ]]; then
            warn "Core config response: ${errmsg} (may be OK if already done)"
        fi
    fi
    pass "Core configuration step completed"

    # -------------------------------------------------------------------------
    # Step 4: Analytics onboarding
    # -------------------------------------------------------------------------
    substep "Step 4/5: Completing analytics setup..."

    local analytics_response
    analytics_response=$(curl -s -X POST "${HA_URL}/api/onboarding/analytics" \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d '{}' 2>/dev/null)

    if echo "$analytics_response" | jq -e '.message' &>/dev/null 2>&1; then
        local errmsg
        errmsg=$(echo "$analytics_response" | jq -r '.message')
        if [[ "$errmsg" != "null" ]]; then
            warn "Analytics response: ${errmsg} (may be OK if already done)"
        fi
    fi
    pass "Analytics setup step completed"

    # -------------------------------------------------------------------------
    # Step 5: Integration onboarding (requires JSON body with client_id)
    # -------------------------------------------------------------------------
    substep "Step 5/5: Completing integration discovery..."

    local integration_response
    integration_response=$(curl -s -X POST "${HA_URL}/api/onboarding/integration" \
        -H "Authorization: Bearer ${access_token}" \
        -H "Content-Type: application/json" \
        -d "{
            \"client_id\": \"${CLIENT_ID}\",
            \"redirect_uri\": \"${HA_URL}/\"
        }" 2>/dev/null)

    if echo "$integration_response" | jq -e '.message' &>/dev/null 2>&1; then
        local errmsg
        errmsg=$(echo "$integration_response" | jq -r '.message')
        if [[ "$errmsg" != "null" ]]; then
            warn "Integration response: ${errmsg} (may be OK if already done)"
        fi
    fi
    pass "Integration discovery step completed"

    pass "Onboarding complete!"
}

# ==============================================================================
# Create Long-Lived Access Token (LLAT) via WebSocket
# ==============================================================================

create_llat() {
    step "Creating Long-Lived Access Token (LLAT)"

    # Check if we already have an LLAT stored
    if [[ -f "$MCP_CONFIG_FILE" ]]; then
        local existing_token
        existing_token=$(jq -r '.homeAssistant.token // empty' "$MCP_CONFIG_FILE" 2>/dev/null)
        if [[ -n "$existing_token" && "$existing_token" != "null" ]]; then
            # Verify the token still works
            local verify_code
            verify_code=$(curl -s -o /dev/null -w '%{http_code}' \
                "${HA_URL}/api/config" \
                -H "Authorization: Bearer ${existing_token}" 2>/dev/null || echo "000")

            if [[ "$verify_code" == "200" ]]; then
                pass "Existing LLAT is still valid (verified against /api/config)"
                return 0
            else
                warn "Existing LLAT is invalid (HTTP ${verify_code}), creating new one"
            fi
        fi
    fi

    # Ensure we have the access token from onboarding
    if [[ ! -f "$TOKENS_FILE" ]]; then
        fail "No tokens file found at ${TOKENS_FILE}"
        fail "Run onboarding first or reset: $0 reset"
        exit 1
    fi

    local access_token
    access_token=$(jq -r '.access_token' "$TOKENS_FILE" 2>/dev/null)

    if [[ -z "$access_token" || "$access_token" == "null" ]]; then
        fail "No access token found in ${TOKENS_FILE}"
        exit 1
    fi

    # Ensure aiohttp is available
    ensure_aiohttp

    substep "Creating LLAT via WebSocket API..."

    # Use inline Python script to create LLAT via WebSocket
    local llat
    llat=$(python3 <<PYTHON
import asyncio
import aiohttp
import json
import sys

async def create_llat():
    access_token = "${access_token}"
    ws_url = "ws://localhost:${PORT}/api/websocket"

    try:
        async with aiohttp.ClientSession() as session:
            async with session.ws_connect(ws_url) as ws:
                # Step 1: Receive auth_required message
                msg = await asyncio.wait_for(ws.receive_json(), timeout=10)
                if msg.get("type") != "auth_required":
                    print(f"ERROR: Expected auth_required, got {msg.get('type')}", file=sys.stderr)
                    sys.exit(1)

                # Step 2: Send authentication
                await ws.send_json({
                    "type": "auth",
                    "access_token": access_token
                })

                # Step 3: Receive auth_ok
                msg = await asyncio.wait_for(ws.receive_json(), timeout=10)
                if msg.get("type") != "auth_ok":
                    print(f"ERROR: Authentication failed: {msg}", file=sys.stderr)
                    sys.exit(1)

                # Step 4: Request LLAT
                await ws.send_json({
                    "type": "auth/long_lived_access_token",
                    "client_name": "ha-dev-mcp-test",
                    "lifespan": 365,
                    "id": 1
                })

                # Step 5: Receive LLAT response
                msg = await asyncio.wait_for(ws.receive_json(), timeout=10)
                if msg.get("success"):
                    print(msg["result"])
                else:
                    print(f"ERROR: LLAT creation failed: {msg}", file=sys.stderr)
                    sys.exit(1)

    except aiohttp.ClientError as e:
        print(f"ERROR: WebSocket connection failed: {e}", file=sys.stderr)
        sys.exit(1)
    except asyncio.TimeoutError:
        print("ERROR: WebSocket operation timed out", file=sys.stderr)
        sys.exit(1)

asyncio.run(create_llat())
PYTHON
    )

    if [[ -z "$llat" || "$llat" == ERROR* ]]; then
        fail "Failed to create LLAT"
        fail "${llat}"
        exit 1
    fi

    # Store LLAT in tokens file for reference
    local tmp_tokens
    tmp_tokens=$(jq --arg llat "$llat" '. + {"llat": $llat}' "$TOKENS_FILE")
    echo "$tmp_tokens" > "$TOKENS_FILE"
    chmod 600 "$TOKENS_FILE"

    pass "LLAT created successfully"
    info "Token (first 20 chars): ${llat:0:20}..."

    # Export for use by write_mcp_config
    LLAT="$llat"
}

# ==============================================================================
# Write MCP server configuration
# ==============================================================================

write_mcp_config() {
    step "Writing MCP server configuration"

    # Get the LLAT — either just created or from tokens file
    if [[ -z "${LLAT:-}" ]]; then
        if [[ -f "$TOKENS_FILE" ]]; then
            LLAT=$(jq -r '.llat // empty' "$TOKENS_FILE" 2>/dev/null)
        fi
        if [[ -z "${LLAT:-}" ]]; then
            # Try the existing MCP config
            if [[ -f "$MCP_CONFIG_FILE" ]]; then
                LLAT=$(jq -r '.homeAssistant.token // empty' "$MCP_CONFIG_FILE" 2>/dev/null)
            fi
        fi
    fi

    if [[ -z "${LLAT:-}" || "${LLAT}" == "null" ]]; then
        fail "No LLAT available to write config"
        exit 1
    fi

    mkdir -p "$MCP_CONFIG_DIR"

    cat > "$MCP_CONFIG_FILE" <<JSON
{
  "homeAssistant": {
    "url": "${HA_URL}",
    "token": "${LLAT}",
    "verifySsl": false
  },
  "safety": {
    "allowServiceCalls": true,
    "blockedServices": [
      "homeassistant.restart",
      "homeassistant.stop",
      "homeassistant.reload_all"
    ],
    "requireDryRun": false
  },
  "cache": {
    "docsTtlHours": 24,
    "statesTtlSeconds": 30
  },
  "features": {
    "enableDocsTools": true,
    "enableHaTools": true,
    "enableValidationTools": true
  }
}
JSON
    chmod 600 "$MCP_CONFIG_FILE"
    pass "MCP config written to ${MCP_CONFIG_FILE}"
}

# ==============================================================================
# Health check
# ==============================================================================

health_check() {
    step "Running health check"

    # Get the LLAT for auth
    local token=""
    if [[ -f "$MCP_CONFIG_FILE" ]]; then
        token=$(jq -r '.homeAssistant.token // empty' "$MCP_CONFIG_FILE" 2>/dev/null)
    fi
    if [[ -z "$token" && -f "$TOKENS_FILE" ]]; then
        token=$(jq -r '.llat // .access_token // empty' "$TOKENS_FILE" 2>/dev/null)
    fi

    if [[ -z "$token" ]]; then
        warn "No token available for authenticated health check"
        # Do unauthenticated check only
        local http_code
        http_code=$(curl -s -o /dev/null -w '%{http_code}' "${HA_URL}/api/" 2>/dev/null || echo "000")
        if [[ "$http_code" == "401" || "$http_code" == "200" ]]; then
            pass "HA API is responding (HTTP ${http_code}, unauthenticated)"
        else
            fail "HA API is not responding (HTTP ${http_code})"
            return 1
        fi
        return 0
    fi

    # Authenticated health check: /api/config
    local config_response
    config_response=$(curl -s "${HA_URL}/api/config" \
        -H "Authorization: Bearer ${token}" 2>/dev/null)

    local version location components
    version=$(echo "$config_response" | jq -r '.version // empty' 2>/dev/null)
    location=$(echo "$config_response" | jq -r '.location_name // empty' 2>/dev/null)
    components=$(echo "$config_response" | jq -r '.components | length // 0' 2>/dev/null)

    if [[ -n "$version" && "$version" != "null" ]]; then
        pass "HA API responding with valid config"
        info "  Version:    ${version}"
        info "  Location:   ${location}"
        info "  Components: ${components}"
    else
        fail "HA API returned invalid config response"
        fail "Response: ${config_response:0:200}"
        return 1
    fi

    # Check for demo entities
    local states_response entity_count
    states_response=$(curl -s "${HA_URL}/api/states" \
        -H "Authorization: Bearer ${token}" 2>/dev/null)
    entity_count=$(echo "$states_response" | jq 'length' 2>/dev/null || echo "0")

    if (( entity_count > 0 )); then
        pass "Entity states accessible (${entity_count} entities)"
    else
        warn "No entities found — demo integration may not have loaded yet"
    fi

    # Check for demo-specific entities
    local demo_light
    demo_light=$(echo "$states_response" | jq -r '.[] | select(.entity_id == "light.bed_light") | .entity_id' 2>/dev/null)
    if [[ "$demo_light" == "light.bed_light" ]]; then
        pass "Demo entities loaded (light.bed_light found)"
    else
        warn "Demo entity light.bed_light not found — may need more time to load"
    fi

    pass "Health check passed"
}

# ==============================================================================
# Status command
# ==============================================================================

cmd_status() {
    step "Home Assistant Test Environment Status"

    # Workspace
    substep "Workspace: ${WORKSPACE}"
    if [[ -d "$WORKSPACE" ]]; then
        pass "Workspace directory exists"
    else
        fail "Workspace directory does not exist"
    fi

    # Container runtime
    detect_container_runtime

    # Container
    substep "Container: ${CONTAINER_NAME}"
    if is_container_running; then
        pass "Container is running"
        local container_uptime
        container_uptime=$($CONTAINER_CMD inspect -f '{{.State.StartedAt}}' "$CONTAINER_NAME" 2>/dev/null || echo "unknown")
        info "  Started: ${container_uptime}"
    elif is_container_exists; then
        warn "Container exists but is not running"
    else
        fail "Container does not exist"
    fi

    # HA responsiveness
    substep "Home Assistant API"
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' "${HA_URL}/api/" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" || "$http_code" == "401" ]]; then
        pass "API responding (HTTP ${http_code})"
    else
        fail "API not responding (HTTP ${http_code})"
    fi

    # Onboarding
    substep "Onboarding"
    if is_onboarding_done; then
        pass "Onboarding complete"
    else
        warn "Onboarding not complete (or HA not responding)"
    fi

    # Tokens
    substep "Authentication"
    if [[ -f "$TOKENS_FILE" ]]; then
        pass "Tokens file exists"
        local has_llat
        has_llat=$(jq -r '.llat // empty' "$TOKENS_FILE" 2>/dev/null)
        if [[ -n "$has_llat" ]]; then
            pass "LLAT present in tokens file"
        else
            warn "No LLAT in tokens file"
        fi
    else
        warn "Tokens file not found"
    fi

    # MCP config
    substep "MCP Configuration"
    if [[ -f "$MCP_CONFIG_FILE" ]]; then
        pass "MCP config exists at ${MCP_CONFIG_FILE}"
        local token
        token=$(jq -r '.homeAssistant.token // empty' "$MCP_CONFIG_FILE" 2>/dev/null)
        if [[ -n "$token" ]]; then
            pass "Token configured (${#token} chars)"

            # Verify token
            local verify_code
            verify_code=$(curl -s -o /dev/null -w '%{http_code}' \
                "${HA_URL}/api/config" \
                -H "Authorization: Bearer ${token}" 2>/dev/null || echo "000")
            if [[ "$verify_code" == "200" ]]; then
                pass "Token is valid (HTTP 200)"
            else
                fail "Token is invalid (HTTP ${verify_code})"
            fi
        else
            fail "No token in MCP config"
        fi
    else
        warn "MCP config not found at ${MCP_CONFIG_FILE}"
    fi

    echo ""
}

# ==============================================================================
# Setup command
# ==============================================================================

cmd_setup() {
    echo -e "\n${BOLD}Home Assistant Test Environment Setup${NC}"
    echo "======================================"

    detect_container_runtime
    check_prerequisites
    create_workspace
    create_docker_compose
    create_ha_config
    start_container
    wait_for_ha
    complete_onboarding

    # Give HA a moment to fully initialize after onboarding
    # (some components load asynchronously)
    if ! is_onboarding_done 2>/dev/null; then
        info "Waiting a few seconds for post-onboarding initialization..."
        sleep 5
    fi

    create_llat
    write_mcp_config
    health_check

    step "Setup Complete!"
    echo ""
    info "Workspace:    ${WORKSPACE}"
    info "HA URL:       ${HA_URL}"
    info "MCP Config:   ${MCP_CONFIG_FILE}"
    info "Tokens:       ${TOKENS_FILE}"
    echo ""
    info "Test with:"
    info "  curl -s ${HA_URL}/api/config -H 'Authorization: Bearer \$(jq -r .homeAssistant.token ${MCP_CONFIG_FILE})' | jq .version"
    echo ""
}

# ==============================================================================
# Teardown command
# ==============================================================================

cmd_teardown() {
    echo -e "\n${BOLD}Home Assistant Test Environment Teardown${NC}"
    echo "========================================="

    detect_container_runtime
    stop_container

    echo ""
    read -r -p "  Remove workspace data (${WORKSPACE}/ha-config)? [y/N] " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        step "Removing HA config data"
        rm -rf "$WORKSPACE/ha-config"
        rm -f "$TOKENS_FILE"
        pass "HA config data removed"
    else
        info "Workspace data preserved at ${WORKSPACE}/ha-config"
    fi

    echo ""
    read -r -p "  Remove MCP config (${MCP_CONFIG_FILE})? [y/N] " confirm
    if [[ "${confirm,,}" == "y" ]]; then
        rm -f "$MCP_CONFIG_FILE"
        pass "MCP config removed"
    else
        info "MCP config preserved at ${MCP_CONFIG_FILE}"
    fi

    step "Teardown complete"
}

# ==============================================================================
# Reset command
# ==============================================================================

cmd_reset() {
    echo -e "\n${BOLD}Home Assistant Test Environment Reset${NC}"
    echo "======================================"
    warn "This will destroy ALL test data and rebuild from scratch"
    echo ""
    read -r -p "  Continue? [y/N] " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        info "Reset cancelled"
        exit 0
    fi

    detect_container_runtime

    # Force stop and remove container
    step "Stopping and removing container"
    $COMPOSE_CMD -f "$WORKSPACE/docker-compose.yml" down -v 2>/dev/null || true
    $CONTAINER_CMD rm -f "$CONTAINER_NAME" 2>/dev/null || true
    pass "Container removed"

    # Remove all workspace data
    step "Removing workspace data"
    rm -rf "$WORKSPACE/ha-config"
    rm -f "$TOKENS_FILE"
    rm -f "$WORKSPACE/docker-compose.yml"
    pass "Workspace data removed"

    # Remove MCP config
    step "Removing MCP config"
    rm -f "$MCP_CONFIG_FILE"
    pass "MCP config removed"

    # Now run full setup
    cmd_setup
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    local cmd="${1:-help}"

    case "$cmd" in
        setup)
            cmd_setup
            ;;
        teardown)
            cmd_teardown
            ;;
        status)
            cmd_status
            ;;
        reset)
            cmd_reset
            ;;
        help|--help|-h)
            echo "Usage: $0 {setup|teardown|status|reset}"
            echo ""
            echo "Commands:"
            echo "  setup     Full setup: workspace, container, onboarding, LLAT, MCP config"
            echo "  teardown  Stop container, optionally remove data"
            echo "  status    Check if HA is running and responding"
            echo "  reset     Destroy everything and rebuild from scratch"
            echo ""
            echo "Environment variables:"
            echo "  HA_TEST_WORKSPACE   Workspace dir    (default: ~/ha-plugin-test-workspace)"
            echo "  HA_TEST_PORT        HA port          (default: 8123)"
            echo "  HA_TEST_TIMEOUT     Startup timeout  (default: 180s)"
            echo "  HA_TEST_USERNAME    Onboard user     (default: test)"
            echo "  HA_TEST_PASSWORD    Onboard pass     (default: test1234)"
            echo "  HA_TEST_IMAGE       Container image  (default: ghcr.io/home-assistant/home-assistant:stable)"
            ;;
        *)
            fail "Unknown command: $cmd"
            echo "Usage: $0 {setup|teardown|status|reset}"
            exit 1
            ;;
    esac
}

main "$@"
