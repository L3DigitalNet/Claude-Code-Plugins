#!/usr/bin/env bash
# Claude Sync — Snapshot parser and diff engine
# Finds a snapshot at the sync path, extracts it, reads the manifest,
# diffs contents against local ~/.claude/, and identifies install requirements.
# Returns structured JSON to stdout.
#
# Usage: parse-snapshot.sh <sync_path> [--exclude <entries>]
#   sync_path:    directory containing the snapshot archive
#   --exclude:    newline-separated paths to exclude (optional)

set -uo pipefail

die() { jq -n --arg e "$1" '{"error":$e}'; exit 1; }

# --- Parse arguments ---------------------------------------------------------
SYNC_PATH="" ; EXCLUDES_RAW=""
while [ $# -gt 0 ]; do
    case "$1" in
        --exclude) [ $# -ge 2 ] || die "--exclude requires a value"; EXCLUDES_RAW="$2"; shift 2 ;;
        *)         [ -z "$SYNC_PATH" ] && SYNC_PATH="$1"; shift ;;
    esac
done
[ -n "$SYNC_PATH" ] || die "sync_path is required"

command -v jq  >/dev/null 2>&1 || die "jq is required but not installed"
command -v tar >/dev/null 2>&1 || die "tar is required but not installed"
[ -d "$SYNC_PATH" ] || die "sync path not found: $SYNC_PATH"

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

# --- Find snapshot -----------------------------------------------------------
snapshot=""
latest_mtime=0
for f in "$SYNC_PATH"/claude-sync-*-*.tar.gz; do
    [ -f "$f" ] || continue
    [[ "$(basename "$f")" == claude-sync-backup-* ]] && continue
    fmtime=$(stat -c '%Y' "$f" 2>/dev/null || echo 0)
    if [ "$fmtime" -gt "$latest_mtime" ]; then
        latest_mtime=$fmtime
        snapshot=$f
    fi
done

if [ -z "$snapshot" ]; then
    jq -n --arg sp "$SYNC_PATH" '{"error":"no_snapshot","sync_path":$sp}'
    exit 0
fi

# --- Temp file tracking (single cleanup function) ---------------------------
declare -a _TMPFILES=()
cleanup() { rm -rf "${_TMPFILES[@]}" 2>/dev/null; }
trap cleanup EXIT

mktmp_file() { local f; f=$(mktemp); _TMPFILES+=("$f"); echo "$f"; }
mktmp_dir()  { local d; d=$(mktemp -d); _TMPFILES+=("$d"); echo "$d"; }

# --- Extract to temp dir -----------------------------------------------------
TMP=$(mktmp_dir)
tar xzf "$snapshot" -C "$TMP" 2>/dev/null || die "failed to extract snapshot"

[ -f "$TMP/manifest.json" ] || die "snapshot missing manifest.json"

# --- Read manifest -----------------------------------------------------------
manifest=$(cat "$TMP/manifest.json")
snap_host=$(echo "$manifest"  | jq -r '.hostname')
snap_ts=$(echo "$manifest"    | jq -r '.exported_at')
snap_sv=$(echo "$manifest"    | jq -r '.schema_version')
snap_cjm=$(echo "$manifest"  | jq -r '.claude_json_mtime // ""')
categories=$(echo "$manifest" | jq '.categories')
snap_size=$(LC_ALL=C du -h "$snapshot" | cut -f1)

# --- Diff snapshot files against local ~/.claude/ ----------------------------
add_file=$(mktmp_file); upd_file=$(mktmp_file); unch_file=$(mktmp_file)

if [ -d "$TMP/claude" ]; then
    while IFS= read -r snap_file; do
        rel="${snap_file#$TMP/claude/}"
        local_file="$HOME/.claude/$rel"

        is_excluded "$local_file" && continue

        if [ ! -e "$local_file" ]; then
            jq -n --arg p "$rel" '{"path":$p,"type":"file"}' >> "$add_file"
        else
            snap_mt=$(stat -c '%Y' "$snap_file" 2>/dev/null || echo 0)
            local_mt=$(stat -c '%Y' "$local_file" 2>/dev/null || echo 0)
            if [ "$snap_mt" -gt "$local_mt" ]; then
                days=$(( (snap_mt - local_mt) / 86400 ))
                if [ "$days" -gt 0 ]; then
                    desc="${days} days newer"
                else
                    hours=$(( (snap_mt - local_mt) / 3600 ))
                    if [ "$hours" -gt 0 ]; then desc="${hours} hours newer"
                    else desc="newer"; fi
                fi
                jq -n --arg p "$rel" --arg d "$desc" \
                    '{"path":$p,"type":"file","age_diff":$d}' >> "$upd_file"
            else
                jq -n --arg p "$rel" '{"path":$p,"type":"file"}' >> "$unch_file"
            fi
        fi
    done < <(find "$TMP/claude" -type f 2>/dev/null | sort)
fi

additions=$(jq -s '.' "$add_file" 2>/dev/null || echo '[]')
updates=$(jq -s '.' "$upd_file" 2>/dev/null || echo '[]')
unchanged=$(jq -s '.' "$unch_file" 2>/dev/null || echo '[]')

# --- MCP comparison ----------------------------------------------------------
mcp_action="none"; mcp_reason="no MCP data"
if [ -f "$TMP/mcp-servers.json" ] && [ -n "$snap_cjm" ]; then
    if [ -f "$HOME/.claude.json" ]; then
        local_epoch=$(stat -c '%Y' "$HOME/.claude.json" 2>/dev/null || echo 0)
        snap_epoch=$(date -u -d "$snap_cjm" +%s 2>/dev/null || echo 0)
        if [ "$snap_epoch" -gt "$local_epoch" ]; then
            days=$(( (snap_epoch - local_epoch) / 86400 ))
            mcp_action="replace"
            mcp_reason="snapshot is ${days} days newer"
        else
            mcp_action="keep_local"
            mcp_reason="local is newer or same"
        fi
    else
        mcp_action="replace"
        mcp_reason="no local .claude.json exists"
    fi
fi

# --- Identify new MCP servers ------------------------------------------------
install_file=$(mktmp_file); manual_file=$(mktmp_file)

if [ -f "$TMP/mcp-servers.json" ]; then
    # Get local server names
    local_servers=""
    if [ -f "$HOME/.claude.json" ]; then
        local_servers=$(jq -r '.mcpServers // {} | keys[]' "$HOME/.claude.json" 2>/dev/null || true)
    fi

    while IFS= read -r sname; do
        # Check if present locally
        if echo "$local_servers" | grep -Fqx "$sname" 2>/dev/null; then
            continue
        fi
        install_data=$(jq --arg n "$sname" '.servers[$n].install + {"name":$n}' "$TMP/mcp-servers.json")
        method=$(echo "$install_data" | jq -r '.method')
        if [ "$method" = "manual" ]; then
            echo "$install_data" >> "$manual_file"
        else
            echo "$install_data" >> "$install_file"
        fi
    done < <(jq -r '.servers | keys[]' "$TMP/mcp-servers.json" 2>/dev/null)
fi

installs_required=$(jq -s '.' "$install_file" 2>/dev/null || echo '[]')
manual_installs=$(jq -s '.' "$manual_file" 2>/dev/null || echo '[]')

# --- Identify local-only files -----------------------------------------------
local_only_file=$(mktmp_file)

if [ -d "$HOME/.claude" ]; then
    while IFS= read -r local_file; do
        rel="${local_file#$HOME/.claude/}"

        # Skip always-excluded
        case "$rel" in
            projects|projects/*) continue ;;
            .credentials.json)   continue ;;
            statsig|statsig/*)   continue ;;
        esac

        is_excluded "$local_file" && continue

        # Check if in snapshot
        if [ ! -e "$TMP/claude/$rel" ]; then
            jq -n --arg p "$rel" '{"path":$p,"type":"file"}' >> "$local_only_file"
        fi
    done < <(find "$HOME/.claude" -type f \
        ! -path "$HOME/.claude/projects/*" \
        ! -path "$HOME/.claude/.credentials.json" \
        ! -path "$HOME/.claude/statsig/*" \
        2>/dev/null | sort)
fi

local_only=$(jq -s '.' "$local_only_file" 2>/dev/null || echo '[]')

# --- Output JSON -------------------------------------------------------------
jq -n \
    --arg host "$snap_host" \
    --arg ts "$snap_ts" \
    --arg sv "$snap_sv" \
    --arg size "$snap_size" \
    --arg cjm "$snap_cjm" \
    --arg path "$snapshot" \
    --argjson cats "$categories" \
    --argjson add "$additions" \
    --argjson upd "$updates" \
    --argjson unch "$unchanged" \
    --arg mact "$mcp_action" \
    --arg mrsn "$mcp_reason" \
    --argjson inst "$installs_required" \
    --argjson man "$manual_installs" \
    --argjson lo "$local_only" \
    '{snapshot:{hostname:$host, exported_at:$ts, schema_version:$sv,
                archive_size:$size, claude_json_mtime:$cjm, archive_path:$path},
      categories:$cats,
      diff:{additions:$add, updates:$upd, unchanged:$unch, local_only:$lo},
      mcp:{action:$mact, reason:$mrsn,
           installs_required:$inst, manual_installs:$man}}'
