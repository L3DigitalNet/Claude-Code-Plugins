#!/usr/bin/env bash
# tests/test-parse-snapshot.sh — Unit and integration tests for parse-snapshot.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)/scripts"
PARSE_SNAPSHOT="$SCRIPT_DIR/parse-snapshot.sh"
source "$(dirname "$0")/helpers.bash"

TMPDIR_TEST=$(mktemp -d)
REAL_HOME="$HOME"
trap 'HOME="$REAL_HOME"; rm -rf "$TMPDIR_TEST"' EXIT

TEST_HOME="$TMPDIR_TEST/home"
SYNC_PATH="$TMPDIR_TEST/sync"
mkdir -p "$TEST_HOME/.claude" "$SYNC_PATH"
export HOME="$TEST_HOME"

echo "=== parse-snapshot.sh ==="

# ---- Test 1: no snapshot found ----
echo "— no snapshot found"
out=$(bash "$PARSE_SNAPSHOT" "$SYNC_PATH")
assert_json_eq "$out" ".error" "no_snapshot" "error is no_snapshot"

# ---- Helper: build a test snapshot archive ----
build_snapshot() {
    local staging="$TMPDIR_TEST/staging-$$"
    rm -rf "$staging"
    mkdir -p "$staging/claude"

    # Settings file — newer than local
    echo '{"enabledPlugins":{}}' > "$staging/claude/settings.json"
    touch -t 202604070000 "$staging/claude/settings.json"

    # A file that will be older than local
    echo '{}' > "$staging/claude/settings.local.json"
    touch -t 202604010000 "$staging/claude/settings.local.json"

    # A file that won't exist locally (addition)
    echo '{"new": true}' > "$staging/claude/new-config.json"
    touch -t 202604070000 "$staging/claude/new-config.json"

    # CLAUDE.md
    echo "# Instructions" > "$staging/claude/CLAUDE.md"
    touch -t 202604070000 "$staging/claude/CLAUDE.md"

    # MCP servers
    cat > "$staging/mcp-servers.json" << 'JSON'
{
    "servers": {
        "existing-server": {
            "command": "npx",
            "args": ["-y", "existing-pkg"],
            "install": {"method": "npm", "package": "existing-pkg", "version": "", "notes": ""}
        },
        "new-server": {
            "command": "npx",
            "args": ["-y", "new-pkg"],
            "install": {"method": "npm", "package": "new-pkg", "version": "", "notes": ""}
        },
        "manual-server": {
            "command": "custom-cmd",
            "args": [],
            "install": {"method": "manual", "package": "", "version": "", "notes": "Run: custom-cmd"}
        }
    }
}
JSON

    # Manifest
    cat > "$staging/manifest.json" << 'JSON'
{
    "schema_version": "1.0.0",
    "hostname": "source-machine",
    "exported_at": "2026-04-07T12:00:00Z",
    "claude_json_mtime": "2026-04-07T10:00:00Z",
    "categories": {
        "settings": {"count": 3, "files": ["settings.json", "settings.local.json", "new-config.json"]},
        "mcp_servers": {"count": 3, "servers": ["existing-server", "new-server", "manual-server"]},
        "claude_md": {"count": 1, "files": ["CLAUDE.md"]},
        "plugins": {"count": 0, "names": []}
    },
    "repositories": []
}
JSON

    tar czf "$SYNC_PATH/claude-sync-source-machine-20260407.tar.gz" -C "$staging" .
    rm -rf "$staging"
}

# ---- Set up local environment ----
# Local settings.json — OLDER than snapshot (should be "update")
echo '{"old": true}' > "$TEST_HOME/.claude/settings.json"
touch -t 202604030000 "$TEST_HOME/.claude/settings.json"

# Local settings.local.json — NEWER than snapshot (should be "unchanged")
echo '{"local": true}' > "$TEST_HOME/.claude/settings.local.json"
touch -t 202604050000 "$TEST_HOME/.claude/settings.local.json"

# Local CLAUDE.md
echo "# Local instructions" > "$TEST_HOME/.claude/CLAUDE.md"
touch -t 202604030000 "$TEST_HOME/.claude/CLAUDE.md"

# Local-only file (not in snapshot)
echo "local only" > "$TEST_HOME/.claude/machine-specific.json"
touch -t 202604030000 "$TEST_HOME/.claude/machine-specific.json"

# Items that should NOT appear in local-only (always-excluded)
mkdir -p "$TEST_HOME/.claude/projects"
echo "session" > "$TEST_HOME/.claude/projects/data.json"
echo "creds" > "$TEST_HOME/.claude/.credentials.json"
mkdir -p "$TEST_HOME/.claude/statsig"
echo "stats" > "$TEST_HOME/.claude/statsig/cache.json"

# Local .claude.json with one existing server — mtime OLDER than snapshot
cat > "$TEST_HOME/.claude.json" << 'JSON'
{
    "mcpServers": {
        "existing-server": {"command": "npx", "args": ["-y", "existing-pkg"]}
    }
}
JSON
touch -t 202604010000 "$TEST_HOME/.claude.json"

build_snapshot

# ---- Test 2: snapshot metadata ----
echo "— snapshot metadata"
out=$(bash "$PARSE_SNAPSHOT" "$SYNC_PATH")
assert_json_eq "$out" ".snapshot.hostname" "source-machine" "hostname from manifest"
assert_json_eq "$out" ".snapshot.schema_version" "1.0.0" "schema version"
assert_json_eq "$out" ".snapshot.exported_at" "2026-04-07T12:00:00Z" "export timestamp"

# ---- Test 3: file addition (in snapshot, not local) ----
echo "— file addition"
additions=$(echo "$out" | jq '[.diff.additions[] | .path]')
assert_contains "$additions" "new-config.json" "new-config.json is an addition"

# ---- Test 4: file update (snapshot newer) ----
echo "— file update (snapshot newer)"
updates=$(echo "$out" | jq '[.diff.updates[] | .path]')
assert_contains "$updates" "settings.json" "settings.json is an update"
age_diff=$(echo "$out" | jq -r '[.diff.updates[] | select(.path=="settings.json")] | .[0].age_diff')
assert_contains "$age_diff" "newer" "age_diff says newer"

# ---- Test 5: file unchanged (local newer) ----
echo "— file unchanged (local newer)"
unchanged=$(echo "$out" | jq '[.diff.unchanged[] | .path]')
assert_contains "$unchanged" "settings.local.json" "settings.local.json is unchanged"

# ---- Test 6: local-only file detected ----
echo "— local-only file detection"
local_only=$(echo "$out" | jq '[.diff.local_only[] | .path]')
assert_contains "$local_only" "machine-specific.json" "machine-specific.json is local-only"

# ---- Test 7: always-excluded items NOT in local-only ----
echo "— always-excluded not in local-only"
local_only_str=$(echo "$out" | jq -r '[.diff.local_only[] | .path] | join(" ")')
assert_not_contains "$local_only_str" "projects/" "projects/ not in local-only"
assert_not_contains "$local_only_str" ".credentials.json" ".credentials.json not in local-only"
assert_not_contains "$local_only_str" "statsig/" "statsig/ not in local-only"

# ---- Test 8: MCP block — snapshot newer → replace ----
echo "— MCP: snapshot newer → replace"
assert_json_eq "$out" ".mcp.action" "replace" "action is replace"
assert_contains "$(echo "$out" | jq -r '.mcp.reason')" "newer" "reason mentions newer"

# ---- Test 9: MCP — new servers identified ----
echo "— MCP: new servers in installs_required"
install_names=$(echo "$out" | jq -r '[.mcp.installs_required[] | .name] | join(" ")')
assert_contains "$install_names" "new-server" "new-server needs install"
assert_not_contains "$install_names" "existing-server" "existing-server already present"

# ---- Test 10: MCP — manual server in manual_installs ----
echo "— MCP: manual servers"
manual_names=$(echo "$out" | jq -r '[.mcp.manual_installs[] | .name] | join(" ")')
assert_contains "$manual_names" "manual-server" "manual-server flagged"

# ---- Test 11: MCP block — local newer → keep_local ----
echo "— MCP: local newer → keep_local"
# Make local .claude.json newer
touch -t 202604080000 "$TEST_HOME/.claude.json"
out2=$(bash "$PARSE_SNAPSHOT" "$SYNC_PATH")
assert_json_eq "$out2" ".mcp.action" "keep_local" "action is keep_local when local is newer"

# ---- Test 12: --exclude without value → error ----
echo "— --exclude without value"
err_out=$(bash "$PARSE_SNAPSHOT" "$SYNC_PATH" --exclude 2>&1 || true)
assert_contains "$err_out" "error" "--exclude without value produces error"

report_results
