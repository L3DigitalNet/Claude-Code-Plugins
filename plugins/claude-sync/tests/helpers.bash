#!/usr/bin/env bash
# Shared test helpers for claude-sync tests
# Sourced by each test-*.sh file

PASS=0; FAIL=0

assert_eq() {
    local actual="$1" expected="$2" label="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  ✓ $label"; PASS=$((PASS + 1))
    else
        echo "  ✗ $label"; echo "    got:  '$actual'"; echo "    want: '$expected'"; FAIL=$((FAIL + 1))
    fi
}

assert_contains() {
    local actual="$1" pattern="$2" label="$3"
    if [[ "$actual" == *"$pattern"* ]]; then
        echo "  ✓ $label"; PASS=$((PASS + 1))
    else
        echo "  ✗ $label (expected '$pattern' in output)"; FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local actual="$1" pattern="$2" label="$3"
    if [[ "$actual" != *"$pattern"* ]]; then
        echo "  ✓ $label"; PASS=$((PASS + 1))
    else
        echo "  ✗ $label (unexpected '$pattern' found)"; FAIL=$((FAIL + 1))
    fi
}

assert_json_eq() {
    local json="$1" path="$2" expected="$3" label="$4"
    local actual
    actual=$(echo "$json" | jq -r "$path" 2>/dev/null)
    assert_eq "$actual" "$expected" "$label"
}

assert_json_count() {
    local json="$1" path="$2" expected="$3" label="$4"
    local actual
    actual=$(echo "$json" | jq "$path | length" 2>/dev/null)
    assert_eq "$actual" "$expected" "$label"
}

report_results() {
    echo ""
    echo "Results: $PASS passed, $FAIL failed"
    [[ $FAIL -eq 0 ]]
}

# Create a git repo. Pass has_remote=true to add a bare repo as origin.
create_mock_repo() {
    local path="$1" has_remote="${2:-true}"
    mkdir -p "$path"
    git -C "$path" init -q -b main
    git -C "$path" config user.email "test@test.com"
    git -C "$path" config user.name "Test"
    echo "initial" > "$path/file.txt"
    git -C "$path" add file.txt
    git -C "$path" commit -q -m "initial commit"

    if [ "$has_remote" = true ]; then
        local bare="${path}.bare"
        git clone --bare -q "$path" "$bare" 2>/dev/null
        git -C "$path" remote add origin "$bare"
        git -C "$path" push -q -u origin main 2>/dev/null || true
    fi
}

# Populate a fake HOME with the ~/.claude/ structure expected by the scripts
setup_fake_home() {
    local home="$1"
    mkdir -p "$home/.claude/plugins/test-plugin/.claude-plugin"
    mkdir -p "$home/.claude/commands"
    mkdir -p "$home/.claude/projects"
    mkdir -p "$home/.claude/statsig"

    echo '{"enabledPlugins":{}}' > "$home/.claude/settings.json"
    echo '{}' > "$home/.claude/settings.local.json"
    echo "secret-token-123" > "$home/.claude/.credentials.json"
    echo "analytics-data" > "$home/.claude/statsig/cache.json"
    echo "session-data" > "$home/.claude/projects/session.json"
    echo '{"name":"test-plugin","version":"1.0.0"}' \
        > "$home/.claude/plugins/test-plugin/.claude-plugin/plugin.json"
    echo "# My Command" > "$home/.claude/commands/my-command.md"

    cat > "$home/.claude/CLAUDE.md" << 'CLAUDEMD'
# Global Instructions

Some instructions here.

<!-- claude-sync-config-start -->
## Claude Sync Configuration

**Sync path:** /mnt/nas/claude-sync
**Secret store path:** /mnt/nas/secrets
**Repos root path:** /home/test/projects

### Exclude list
<!-- claude-sync-config-end -->

More instructions below.
CLAUDEMD
}

# Populate a fake ~/.claude.json with mcpServers covering all 4 install methods
setup_fake_claude_json() {
    local home="$1"
    cat > "$home/.claude.json" << 'JSON'
{
    "mcpServers": {
        "github-mcp": {
            "command": "npx",
            "args": ["-y", "@modelcontextprotocol/server-github"],
            "env": {"GITHUB_TOKEN": "secret"}
        },
        "python-tool": {
            "command": "uvx",
            "args": ["my-python-tool"]
        },
        "local-server": {
            "command": "/usr/local/bin/my-server",
            "args": ["--port", "3000"]
        },
        "custom-thing": {
            "command": "some-launcher",
            "args": ["--config", "/path"]
        }
    },
    "oauthTokens": {"should": "not be captured"},
    "permissions": {"project_trust": true}
}
JSON
}
