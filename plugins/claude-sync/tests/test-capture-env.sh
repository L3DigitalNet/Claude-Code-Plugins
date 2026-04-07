#!/usr/bin/env bash
# tests/test-capture-env.sh — Unit and integration tests for capture-env.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts"
CAPTURE_ENV="$SCRIPT_DIR/capture-env.sh"
source "$(dirname "$0")/helpers.bash"

TMPDIR_TEST=$(mktemp -d)
REAL_HOME="$HOME"
trap 'HOME="$REAL_HOME"; rm -rf "$TMPDIR_TEST"' EXIT

TEST_HOME="$TMPDIR_TEST/home"
SYNC_PATH="$TMPDIR_TEST/sync"
REPOS_ROOT="$TMPDIR_TEST/projects"
mkdir -p "$TEST_HOME" "$SYNC_PATH" "$REPOS_ROOT"

# Set up fake environment
setup_fake_home "$TEST_HOME"
setup_fake_claude_json "$TEST_HOME"
export HOME="$TEST_HOME"

echo "=== capture-env.sh ==="

# ---- Run capture ----
out=$(bash "$CAPTURE_ENV" "$SYNC_PATH" "test-host" "$REPOS_ROOT")
archive_path=$(echo "$out" | jq -r '.archive_path')

# Extract archive for inspection
EXTRACTED="$TMPDIR_TEST/extracted"
mkdir -p "$EXTRACTED"
tar xzf "$archive_path" -C "$EXTRACTED"

# ---- Test 1: projects/ excluded ----
echo "— always-excluded: projects/"
assert_eq "$([ -d "$EXTRACTED/claude/projects" ] && echo "exists" || echo "absent")" \
    "absent" "projects/ not in archive"

# ---- Test 2: .credentials.json excluded ----
echo "— always-excluded: .credentials.json"
assert_eq "$([ -f "$EXTRACTED/claude/.credentials.json" ] && echo "exists" || echo "absent")" \
    "absent" ".credentials.json not in archive"

# ---- Test 3: statsig/ excluded ----
echo "— always-excluded: statsig/"
assert_eq "$([ -d "$EXTRACTED/claude/statsig" ] && echo "exists" || echo "absent")" \
    "absent" "statsig/ not in archive"

# ---- Test 4: CLAUDE.md config block stripped ----
echo "— config block stripped from CLAUDE.md"
claude_md_content=$(cat "$EXTRACTED/claude/CLAUDE.md")
assert_not_contains "$claude_md_content" "claude-sync-config-start" "start marker stripped"
assert_not_contains "$claude_md_content" "Sync path" "config values stripped"
assert_contains "$claude_md_content" "Global Instructions" "non-config content preserved"
assert_contains "$claude_md_content" "More instructions below" "content after block preserved"

# ---- Test 5: MCP install inference — npx → npm ----
echo "— MCP inference: npx → npm"
mcp=$(cat "$EXTRACTED/mcp-servers.json")
method=$(echo "$mcp" | jq -r '.servers["github-mcp"].install.method')
pkg=$(echo "$mcp" | jq -r '.servers["github-mcp"].install.package')
assert_eq "$method" "npm" "npx inferred as npm"
assert_eq "$pkg" "@modelcontextprotocol/server-github" "npm package extracted"

# ---- Test 6: MCP install inference — uvx → pip ----
echo "— MCP inference: uvx → pip"
method=$(echo "$mcp" | jq -r '.servers["python-tool"].install.method')
assert_eq "$method" "pip" "uvx inferred as pip"

# ---- Test 7: MCP install inference — absolute path → binary ----
echo "— MCP inference: absolute path → binary"
method=$(echo "$mcp" | jq -r '.servers["local-server"].install.method')
assert_eq "$method" "binary" "absolute path inferred as binary"

# ---- Test 8: MCP install inference — other → manual ----
echo "— MCP inference: other → manual"
method=$(echo "$mcp" | jq -r '.servers["custom-thing"].install.method')
notes=$(echo "$mcp" | jq -r '.servers["custom-thing"].install.notes')
assert_eq "$method" "manual" "unknown command inferred as manual"
assert_contains "$notes" "some-launcher" "raw command in notes"

# ---- Test 9: archive structure ----
echo "— archive structure"
assert_eq "$([ -f "$EXTRACTED/manifest.json" ] && echo "yes" || echo "no")" "yes" "manifest.json at root"
assert_eq "$([ -d "$EXTRACTED/claude" ] && echo "yes" || echo "no")" "yes" "claude/ directory"
assert_eq "$([ -f "$EXTRACTED/mcp-servers.json" ] && echo "yes" || echo "no")" "yes" "mcp-servers.json at root"

# ---- Test 10: manifest content ----
echo "— manifest content"
manifest=$(cat "$EXTRACTED/manifest.json")
assert_json_eq "$manifest" ".schema_version" "1.0.0" "schema_version correct"
assert_json_eq "$manifest" ".hostname" "test-host" "hostname correct"
mcp_count=$(echo "$manifest" | jq '.categories.mcp_servers.count')
assert_eq "$mcp_count" "4" "manifest reports 4 MCP servers"

# ---- Test 11: --backup flag naming ----
echo "— backup naming"
backup_out=$(bash "$CAPTURE_ENV" "$SYNC_PATH" "test-host" "$REPOS_ROOT" --backup)
backup_path=$(echo "$backup_out" | jq -r '.archive_path')
backup_name=$(basename "$backup_path")
assert_contains "$backup_name" "claude-sync-backup-" "backup filename prefix correct"
is_backup=$(echo "$backup_out" | jq '.is_backup')
assert_eq "$is_backup" "true" "is_backup flag set"

# ---- Test 12: previous snapshot rotated to backup ----
echo "— previous snapshot rotation"
# Create a fake "previous" snapshot
touch "$SYNC_PATH/claude-sync-test-host-20260401.tar.gz"
out2=$(bash "$CAPTURE_ENV" "$SYNC_PATH" "test-host" "$REPOS_ROOT")
prev=$(echo "$out2" | jq -r '.previous_snapshot')
prev_bak=$(echo "$out2" | jq -r '.backup_moved_to')
assert_eq "$([ -n "$prev" ] && echo "found" || echo "empty")" "found" "previous snapshot detected"
assert_contains "$prev_bak" "claude-sync-backup-" "previous moved to backup"
# Verify the old file was moved
assert_eq "$([ -f "$SYNC_PATH/claude-sync-test-host-20260401.tar.gz" ] && echo "exists" || echo "moved")" \
    "moved" "old snapshot removed from original location"

# ---- Test 13: only mcpServers extracted (security) ----
echo "— security: only mcpServers key extracted"
assert_not_contains "$mcp" "oauthTokens" "oauthTokens not in mcp-servers.json"
assert_not_contains "$mcp" "permissions" "permissions not in mcp-servers.json"
assert_not_contains "$mcp" "project_trust" "project_trust not in mcp-servers.json"

# ---- Test 14: user exclude list ----
echo "— user exclude list"
echo "extra-file" > "$TEST_HOME/.claude/local-only.txt"
out3=$(bash "$CAPTURE_ENV" "$SYNC_PATH" "test-host" "$REPOS_ROOT" \
    --exclude "$TEST_HOME/.claude/local-only.txt")
archive3=$(echo "$out3" | jq -r '.archive_path')
EXT3="$TMPDIR_TEST/ext3"
mkdir -p "$EXT3"
tar xzf "$archive3" -C "$EXT3"
assert_eq "$([ -f "$EXT3/claude/local-only.txt" ] && echo "exists" || echo "absent")" \
    "absent" "user-excluded file not in archive"

# ---- Test 15: settings files captured ----
echo "— settings files captured"
assert_eq "$([ -f "$EXTRACTED/claude/settings.json" ] && echo "yes" || echo "no")" \
    "yes" "settings.json in archive"

report_results
