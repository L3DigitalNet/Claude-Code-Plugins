#!/usr/bin/env bash
# Claude Sync — Environment capture
# Captures ~/.claude/ (with exclusions), extracts MCP configs from ~/.claude.json,
# builds manifest, and writes a .tar.gz archive to the sync path.
# Returns structured JSON to stdout.
#
# Usage: capture-env.sh <sync_path> <hostname> <repos_root> [--backup] [--exclude <entries>]
#   sync_path:    directory where the archive is written
#   hostname:     machine hostname
#   repos_root:   root directory to scan for git repos (for manifest)
#   --backup:     create backup archive instead of live snapshot
#   --exclude:    newline-separated paths to exclude (optional)

set -uo pipefail

die() { jq -n --arg e "$1" '{"error":$e}'; exit 1; }

# --- Parse arguments ---------------------------------------------------------
SYNC_PATH="" ; HOSTNAME="" ; REPOS_ROOT="" ; BACKUP=false ; EXCLUDES_RAW=""
while [ $# -gt 0 ]; do
    case "$1" in
        --backup)    BACKUP=true; shift ;;
        --exclude)   [ $# -ge 2 ] || die "--exclude requires a value"; EXCLUDES_RAW="$2"; shift 2 ;;
        *)
            if   [ -z "$SYNC_PATH" ];  then SYNC_PATH="$1"
            elif [ -z "$HOSTNAME" ];   then HOSTNAME="$1"
            elif [ -z "$REPOS_ROOT" ]; then REPOS_ROOT="$1"
            fi
            shift ;;
    esac
done
[ -n "$SYNC_PATH" ]  || die "sync_path is required"
[ -n "$HOSTNAME" ]   || die "hostname is required"
[ -n "$REPOS_ROOT" ] || die "repos_root is required"

command -v jq  >/dev/null 2>&1 || die "jq is required but not installed"
command -v tar >/dev/null 2>&1 || die "tar is required but not installed"
[ -d "$SYNC_PATH" ] || die "sync path not found: $SYNC_PATH"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATESTAMP=$(date -u +"%Y%m%d")
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

# --- Exclude list ------------------------------------------------------------
declare -a EXCLUDES=()
if [ -n "$EXCLUDES_RAW" ]; then
    while IFS= read -r entry; do
        entry="${entry/#\~/$HOME}"
        [ -n "$entry" ] && EXCLUDES+=("$entry")
    done <<< "$EXCLUDES_RAW"
fi

is_excluded() {
    local p="$1"
    for e in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
        [[ "$p" == "$e" || "$p" == "$e"/* ]] && return 0
    done
    return 1
}

# --- Helper: ISO mtime (GNU coreutils stat/date required) -------------------
mtime_iso() {
    local epoch
    epoch=$(stat -c '%Y' "$1" 2>/dev/null) || return 1
    date -u -d "@$epoch" +"%Y-%m-%dT%H:%M:%SZ"
}

# --- 1. Copy ~/.claude/ tree ------------------------------------------------
if [ -d "$HOME/.claude" ]; then
    cp -a "$HOME/.claude" "$STAGING/claude" || die "failed to copy ~/.claude/ to staging"
else
    mkdir -p "$STAGING/claude"
fi

# Remove always-excluded items
rm -rf "$STAGING/claude/projects" \
       "$STAGING/claude/.credentials.json" \
       "$STAGING/claude/statsig"

# Remove user-excluded items within ~/.claude/
for e in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    if [[ "$e" == "$HOME/.claude/"* ]]; then
        rel="${e#$HOME/.claude/}"
        rm -rf "$STAGING/claude/$rel"
    fi
done

# --- 2. Strip Claude Sync config block from CLAUDE.md -----------------------
if [ -f "$STAGING/claude/CLAUDE.md" ]; then
    sed '/<!-- claude-sync-config-start -->/,/<!-- claude-sync-config-end -->/d' \
        "$STAGING/claude/CLAUDE.md" > "$STAGING/claude/CLAUDE.md.tmp"
    mv "$STAGING/claude/CLAUDE.md.tmp" "$STAGING/claude/CLAUDE.md"
fi

# --- 3. Extract MCP servers from ~/.claude.json -----------------------------
mcp_count=0; mcp_names="[]"
claude_json_mtime=""

if [ -f "$HOME/.claude.json" ]; then
    claude_json_mtime=$(mtime_iso "$HOME/.claude.json" || echo "")

    # Extract mcpServers and add install blocks
    if jq -e '.mcpServers' "$HOME/.claude.json" >/dev/null 2>&1; then
        jq '{
            servers: (
                (.mcpServers // {}) | to_entries | map({
                    key: .key,
                    value: (.value + {
                        install: (
                            if .value.command == "npx" then {
                                method: "npm",
                                package: ((.value.args // []) | map(select(. != "-y" and . != "--yes")) | .[0] // ""),
                                version: "",
                                notes: ""
                            }
                            elif (.value.command == "uvx" or .value.command == "pip" or .value.command == "pip3") then {
                                method: "pip",
                                package: ((.value.args // [])[0] // ""),
                                version: "",
                                notes: ""
                            }
                            elif (.value.command | test("^/")) then {
                                method: "binary",
                                package: .value.command,
                                version: "",
                                notes: ("Pre-built binary at " + .value.command)
                            }
                            else {
                                method: "manual",
                                package: "",
                                version: "",
                                notes: ("Run: " + .value.command + " " + ((.value.args // []) | join(" ")))
                            }
                            end
                        )
                    })
                }) | from_entries
            )
        }' "$HOME/.claude.json" > "$STAGING/mcp-servers.json"

        mcp_count=$(jq '.servers | length' "$STAGING/mcp-servers.json")
        mcp_names=$(jq '[.servers | keys[]]' "$STAGING/mcp-servers.json")
    else
        echo '{"servers":{}}' > "$STAGING/mcp-servers.json"
    fi
else
    echo '{"servers":{}}' > "$STAGING/mcp-servers.json"
fi

# --- 4. Classify captured files for reporting --------------------------------
# Settings: root-level files in claude/ (excluding CLAUDE.md)
settings_files=$(find "$STAGING/claude" -maxdepth 1 -type f ! -name "CLAUDE.md" 2>/dev/null \
    | xargs -I{} basename {} | jq -R . | jq -s '.' || echo '[]')
settings_count=$(echo "$settings_files" | jq 'length')

# CLAUDE.md
claude_md_count=0; claude_md_files='[]'
if [ -f "$STAGING/claude/CLAUDE.md" ]; then
    claude_md_count=1; claude_md_files='["CLAUDE.md"]'
fi

# Plugins
plugin_names='[]'; plugin_count=0
if [ -d "$STAGING/claude/plugins" ]; then
    plugin_names=$(find "$STAGING/claude/plugins" -maxdepth 3 -name "plugin.json" \
        -exec dirname {} \; 2>/dev/null | xargs -I{} basename {} | jq -R . | jq -s '.' || echo '[]')
    plugin_count=$(echo "$plugin_names" | jq 'length')
fi

# --- 5. Scan repos for manifest (export mode only) --------------------------
repos_json='[]'
if [ "$BACKUP" != true ] && [ -d "$REPOS_ROOT" ]; then
    repos_file=$(mktemp)
    trap 'rm -rf "$STAGING" "$repos_file"' EXIT
    while IFS= read -r git_dir; do
        repo=$(dirname "$git_dir")
        is_excluded "$repo" && continue
        remote=$(git -C "$repo" remote get-url origin 2>/dev/null || true)
        [ -z "$remote" ] && continue
        jq -n --arg n "$(basename "$repo")" --arg p "$repo" --arg r "$remote" \
            '{"name":$n,"path":$p,"remote":$r}' >> "$repos_file"
    done < <(find "$REPOS_ROOT" -name .git -type d 2>/dev/null | sort)
    repos_json=$(jq -s '.' "$repos_file" 2>/dev/null || echo '[]')
    rm -f "$repos_file"
fi

# --- 6. Build manifest.json -------------------------------------------------
jq -n \
    --arg sv "1.0.0" \
    --arg host "$HOSTNAME" \
    --arg ts "$TIMESTAMP" \
    --arg cjm "$claude_json_mtime" \
    --argjson sc "$settings_count" --argjson sf "$settings_files" \
    --argjson mc "$mcp_count" --argjson mn "$mcp_names" \
    --argjson cc "$claude_md_count" --argjson cf "$claude_md_files" \
    --argjson pc "$plugin_count" --argjson pn "$plugin_names" \
    --argjson repos "$repos_json" \
    '{schema_version:$sv, hostname:$host, exported_at:$ts,
      claude_json_mtime:$cjm,
      categories:{
        settings:{count:$sc, files:$sf},
        mcp_servers:{count:$mc, servers:$mn},
        claude_md:{count:$cc, files:$cf},
        plugins:{count:$pc, names:$pn}
      },
      repositories:$repos}' > "$STAGING/manifest.json"

# --- 7. Create archive ------------------------------------------------------
if [ "$BACKUP" = true ]; then
    archive_name="claude-sync-backup-${HOSTNAME}-${DATESTAMP}.tar.gz"
else
    archive_name="claude-sync-${HOSTNAME}-${DATESTAMP}.tar.gz"
fi
archive_path="${SYNC_PATH}/${archive_name}"

tar czf "$archive_path" -C "$STAGING" . 2>/dev/null || die "failed to write archive: $archive_path"
archive_size=$(LC_ALL=C du -h "$archive_path" | cut -f1)

# --- 8. Handle previous snapshot (export mode only) --------------------------
prev_snapshot=""; prev_backup=""
if [ "$BACKUP" != true ]; then
    for f in "$SYNC_PATH"/claude-sync-"${HOSTNAME}"-*.tar.gz; do
        [ -f "$f" ] || continue
        [ "$f" = "$archive_path" ] && continue
        [[ "$(basename "$f")" == claude-sync-backup-* ]] && continue
        prev_snapshot="$f"
        break
    done
    if [ -n "$prev_snapshot" ]; then
        prev_date=$(basename "$prev_snapshot" | grep -oE '[0-9]{8}' || echo "$DATESTAMP")
        prev_backup="${SYNC_PATH}/claude-sync-backup-${HOSTNAME}-${prev_date}.tar.gz"
        mv "$prev_snapshot" "$prev_backup"
    fi
fi

# --- 9. Output JSON ----------------------------------------------------------
jq -n \
    --arg host "$HOSTNAME" \
    --arg ts "$TIMESTAMP" \
    --arg ap "$archive_path" \
    --arg as "$archive_size" \
    --arg cjm "$claude_json_mtime" \
    --argjson sc "$settings_count" --argjson sf "$settings_files" \
    --argjson mc "$mcp_count" --argjson mn "$mcp_names" \
    --argjson cc "$claude_md_count" --argjson cf "$claude_md_files" \
    --argjson pc "$plugin_count" --argjson pn "$plugin_names" \
    --arg prev "${prev_snapshot:-}" \
    --arg prev_bak "${prev_backup:-}" \
    --argjson backup "$BACKUP" \
    '{hostname:$host, timestamp:$ts, archive_path:$ap, archive_size:$as,
      claude_json_mtime:$cjm,
      categories:{
        settings:{count:$sc, files:$sf},
        mcp_servers:{count:$mc, servers:$mn},
        claude_md:{count:$cc, files:$cf},
        plugins:{count:$pc, names:$pn}
      },
      previous_snapshot:$prev, backup_moved_to:$prev_bak,
      is_backup:$backup}'
