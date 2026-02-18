#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# test-watch.sh - File watcher for iterative HA Dev Plugin development
#
# Watches plugin source files and automatically rebuilds/retests the relevant
# component when changes are detected. Supports inotifywait (preferred) with
# a polling fallback using find -newer.
# =============================================================================

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
WITH_HA=false
NO_CLEAR=false
POLL_INTERVAL=2

# Consecutive failure tracking: associative array keyed by component name
declare -A FAIL_COUNT

# Background PIDs to clean up
declare -a BG_PIDS=()

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
${BOLD}test-watch.sh${RESET} - File watcher for HA Dev Plugin development

${BOLD}USAGE${RESET}
    $(basename "$0") [OPTIONS]

${BOLD}OPTIONS${RESET}
    --with-ha       After MCP server changes, also run e2e tests against a
                    running Home Assistant instance on port 8123.
    --no-clear      Do not clear the screen between test runs.
    --interval N    Set the polling interval in seconds (default: 2).
                    Only applies to the polling fallback; inotifywait reacts
                    immediately to filesystem events.
    --help          Show this help message and exit.

${BOLD}WATCH TARGETS${RESET} (relative to plugin root)
    mcp-server/src/**/*.ts   -> tsc build + npm test
    scripts/*.py             -> pytest tests/scripts/
    skills/*/SKILL.md        -> pytest structural validation (skills)
    agents/*.md              -> pytest structural validation (agents)

${BOLD}REQUIREMENTS${RESET}
    - inotify-tools (inotifywait) for instant file-change detection
      Falls back to polling with find -newer if unavailable.
    - Node.js / npm (for MCP server builds)
    - Python 3 / pytest (for script and structural tests)

${BOLD}EXAMPLES${RESET}
    ./scripts/test-watch.sh
    ./scripts/test-watch.sh --with-ha --no-clear
    ./scripts/test-watch.sh --interval 5
EOF
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --with-ha)
            WITH_HA=true
            shift
            ;;
        --no-clear)
            NO_CLEAR=true
            shift
            ;;
        --interval)
            if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}Error: --interval requires a positive integer.${RESET}" >&2
                exit 1
            fi
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${RESET}" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
    echo -e "${DIM}[$(timestamp)]${RESET} $*"
}

log_rebuild() {
    echo -e "${YELLOW}[$(timestamp)] REBUILDING${RESET} $*"
}

log_pass() {
    echo -e "${GREEN}[$(timestamp)] PASS${RESET} $*"
}

log_fail() {
    echo -e "${RED}[$(timestamp)] FAIL${RESET} $*"
}

clear_screen() {
    if [[ "$NO_CLEAR" == false ]]; then
        clear
    fi
}

# Track consecutive failures and warn when threshold is reached.
# Usage: track_failure <component>
track_failure() {
    local component="$1"
    FAIL_COUNT["$component"]=$(( ${FAIL_COUNT["$component"]:-0} + 1 ))
    local count="${FAIL_COUNT["$component"]}"
    if (( count >= 3 )); then
        echo ""
        echo -e "${RED}${BOLD}  !! ${component} has failed ${count} consecutive times.${RESET}"
        echo -e "${RED}  !! Review the error output above carefully before continuing.${RESET}"
        echo ""
    fi
}

# Reset failure counter on success.
# Usage: track_success <component>
track_success() {
    local component="$1"
    FAIL_COUNT["$component"]=0
}

# Run a command, colour the result, and track pass/fail.
# Usage: run_and_track <component_label> <command...>
run_and_track() {
    local label="$1"
    shift
    log_rebuild "$label"
    echo -e "${DIM}  > $*${RESET}"
    echo ""
    if "$@"; then
        echo ""
        log_pass "$label"
        track_success "$label"
    else
        echo ""
        log_fail "$label"
        track_failure "$label"
    fi
}

ha_is_responding() {
    curl -s --max-time 2 -o /dev/null -w '%{http_code}' http://localhost:8123/ 2>/dev/null | grep -qE '^(200|401|403)$'
}

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
print_banner() {
    local mode="$1"
    echo -e "${BOLD}${CYAN}"
    echo "  =============================================="
    echo "   HA Dev Plugin - Test Watcher"
    echo "  =============================================="
    echo -e "${RESET}"
    echo -e "  ${BOLD}Plugin root :${RESET} ${PLUGIN_ROOT}"
    echo -e "  ${BOLD}Watch mode  :${RESET} ${mode}"
    echo -e "  ${BOLD}HA e2e      :${RESET} ${WITH_HA}"
    if [[ "$mode" == "polling" ]]; then
        echo -e "  ${BOLD}Poll interval:${RESET} ${POLL_INTERVAL}s"
    fi
    echo ""
    echo -e "  ${BOLD}Watching:${RESET}"
    echo -e "    ${CYAN}mcp-server/src/**/*.ts${RESET}  -> tsc + npm test"
    echo -e "    ${CYAN}scripts/*.py${RESET}             -> pytest tests/scripts/"
    echo -e "    ${CYAN}skills/*/SKILL.md${RESET}        -> pytest structural (skills)"
    echo -e "    ${CYAN}agents/*.md${RESET}              -> pytest structural (agents)"
    if [[ "$WITH_HA" == true ]]; then
        echo -e "    ${CYAN}(+e2e)${RESET}                   -> node tests/e2e/test-mcp-rest.mjs"
    fi
    echo ""
    echo -e "  Press ${BOLD}Ctrl+C${RESET} to stop."
    echo -e "${DIM}  ----------------------------------------------${RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
# Graceful shutdown
# ---------------------------------------------------------------------------
cleanup() {
    echo ""
    log_info "Shutting down..."
    for pid in "${BG_PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            wait "$pid" 2>/dev/null || true
        fi
    done
    log_info "Goodbye."
    exit 0
}

trap cleanup SIGINT SIGTERM

# ---------------------------------------------------------------------------
# Component test runners
# ---------------------------------------------------------------------------
run_mcp_server_tests() {
    clear_screen
    print_banner "${WATCH_MODE:-unknown}"
    run_and_track "mcp-server (tsc + test)" bash -c "cd '${PLUGIN_ROOT}/mcp-server' && npx tsc && npm test"

    if [[ "$WITH_HA" == true ]]; then
        if ha_is_responding; then
            local e2e_script="${PLUGIN_ROOT}/tests/e2e/test-mcp-rest.mjs"
            if [[ -f "$e2e_script" ]]; then
                run_and_track "mcp-server (e2e)" node "$e2e_script"
            else
                log_info "e2e script not found at ${e2e_script}, skipping."
            fi
        else
            log_info "Home Assistant not responding on port 8123, skipping e2e."
        fi
    fi
}

run_scripts_tests() {
    clear_screen
    print_banner "${WATCH_MODE:-unknown}"
    run_and_track "scripts (pytest)" python3 -m pytest "${PLUGIN_ROOT}/tests/scripts/" -v --tb=short
}

run_skills_tests() {
    clear_screen
    print_banner "${WATCH_MODE:-unknown}"
    run_and_track "skills (structural)" python3 -m pytest "${PLUGIN_ROOT}/tests/test_plugin_structure.py" -v --tb=short -k skill
}

run_agents_tests() {
    clear_screen
    print_banner "${WATCH_MODE:-unknown}"
    run_and_track "agents (structural)" python3 -m pytest "${PLUGIN_ROOT}/tests/test_plugin_structure.py" -v --tb=short -k agent
}

# ---------------------------------------------------------------------------
# inotifywait-based watcher
# ---------------------------------------------------------------------------
watch_inotify() {
    WATCH_MODE="inotifywait"
    print_banner "$WATCH_MODE"
    log_info "Starting inotifywait watcher..."

    # Build the list of directories to watch. Some may not exist yet; filter
    # them so inotifywait does not error out.
    local watch_dirs=()
    local candidate_dirs=(
        "${PLUGIN_ROOT}/mcp-server/src"
        "${PLUGIN_ROOT}/scripts"
        "${PLUGIN_ROOT}/skills"
        "${PLUGIN_ROOT}/agents"
    )
    for d in "${candidate_dirs[@]}"; do
        if [[ -d "$d" ]]; then
            watch_dirs+=("$d")
        else
            log_info "Directory does not exist (will not watch): ${d}"
        fi
    done

    if [[ ${#watch_dirs[@]} -eq 0 ]]; then
        echo -e "${RED}No watch directories found. Nothing to do.${RESET}" >&2
        exit 1
    fi

    # inotifywait streams events; we read them line by line.
    inotifywait -mrq -e modify,create,delete --format '%w%f' "${watch_dirs[@]}" | while read -r changed_file; do
        # Determine which component was affected.
        case "$changed_file" in
            "${PLUGIN_ROOT}/mcp-server/src/"*.ts)
                run_mcp_server_tests
                ;;
            "${PLUGIN_ROOT}/scripts/"*.py)
                run_scripts_tests
                ;;
            "${PLUGIN_ROOT}/skills/"*/SKILL.md)
                run_skills_tests
                ;;
            "${PLUGIN_ROOT}/agents/"*.md)
                run_agents_tests
                ;;
            *)
                # Ignore changes to files that do not match our patterns.
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Polling-based watcher (fallback)
# ---------------------------------------------------------------------------
watch_poll() {
    WATCH_MODE="polling"
    print_banner "$WATCH_MODE"
    log_info "Starting polling watcher (interval: ${POLL_INTERVAL}s)..."

    # Create a temporary reference file to compare mtimes against.
    local ref_file
    ref_file="$(mktemp)"
    # Ensure cleanup removes the temp file.
    trap 'rm -f "$ref_file"; cleanup' SIGINT SIGTERM

    # Touch the reference file to "now" so we only detect future changes.
    touch "$ref_file"

    while true; do
        sleep "$POLL_INTERVAL"

        local triggered=""

        # Check mcp-server TypeScript sources.
        if [[ -d "${PLUGIN_ROOT}/mcp-server/src" ]]; then
            if find "${PLUGIN_ROOT}/mcp-server/src" -name '*.ts' -newer "$ref_file" -print -quit 2>/dev/null | grep -q .; then
                triggered="mcp"
            fi
        fi

        # Check Python scripts.
        if [[ -z "$triggered" && -d "${PLUGIN_ROOT}/scripts" ]]; then
            if find "${PLUGIN_ROOT}/scripts" -maxdepth 1 -name '*.py' -newer "$ref_file" -print -quit 2>/dev/null | grep -q .; then
                triggered="scripts"
            fi
        fi

        # Check SKILL.md files.
        if [[ -z "$triggered" && -d "${PLUGIN_ROOT}/skills" ]]; then
            if find "${PLUGIN_ROOT}/skills" -name 'SKILL.md' -newer "$ref_file" -print -quit 2>/dev/null | grep -q .; then
                triggered="skills"
            fi
        fi

        # Check agent markdown files.
        if [[ -z "$triggered" && -d "${PLUGIN_ROOT}/agents" ]]; then
            if find "${PLUGIN_ROOT}/agents" -maxdepth 1 -name '*.md' -newer "$ref_file" -print -quit 2>/dev/null | grep -q .; then
                triggered="agents"
            fi
        fi

        # If nothing changed, continue polling.
        if [[ -z "$triggered" ]]; then
            continue
        fi

        # Update reference file timestamp before running tests so that
        # changes during the test run are picked up on the next cycle.
        touch "$ref_file"

        case "$triggered" in
            mcp)     run_mcp_server_tests ;;
            scripts) run_scripts_tests ;;
            skills)  run_skills_tests ;;
            agents)  run_agents_tests ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    # Ensure we are in the plugin root so relative paths work predictably.
    cd "$PLUGIN_ROOT"

    if command -v inotifywait &>/dev/null; then
        watch_inotify
    else
        log_info "${YELLOW}inotifywait not found.${RESET} Install inotify-tools for instant detection."
        log_info "Falling back to polling mode."
        echo ""
        watch_poll
    fi
}

main
