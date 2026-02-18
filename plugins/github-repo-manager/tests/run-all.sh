#!/usr/bin/env bash
# ─────────────────────────────────────────────────
# run-all.sh — Main self-test runner for gh-manager
#
# Usage:
#   ./tests/run-all.sh              # Run all tiers
#   ./tests/run-all.sh a            # Tier A only (infrastructure)
#   ./tests/run-all.sh b            # Tier B only (read-only)
#   ./tests/run-all.sh c            # Tier C only (mutations)
#   ./tests/run-all.sh ab           # Tiers A + B
#
# Environment:
#   GITHUB_PAT    — Required for Tiers B and C
#   TEST_REPO     — Target repo (default: L3DigitalNet/testing)
#   GH_MANAGER    — Path to gh-manager binary (default: gh-manager)
# ─────────────────────────────────────────────────

# Intentionally omit -e (errexit): tier scripts may fail and we capture their exit codes
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors
if [[ -t 1 ]]; then
  BOLD='\033[1m'; CYAN='\033[0;36m'; GREEN='\033[0;32m'
  RED='\033[0;31m'; YELLOW='\033[0;33m'; RESET='\033[0m'
else
  BOLD=''; CYAN=''; GREEN=''; RED=''; YELLOW=''; RESET=''
fi

# Determine which tiers to run
TIERS="${1:-abc}"
TIERS=$(echo "$TIERS" | tr '[:upper:]' '[:lower:]')

echo -e "${BOLD}╔═══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║   gh-manager Self-Test Runner v1.0    ║${RESET}"
echo -e "${BOLD}╚═══════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Test repo:  ${CYAN}${TEST_REPO:-L3DigitalNet/testing}${RESET}"
echo -e "  gh-manager: ${CYAN}${GH_MANAGER:-gh-manager}${RESET}"
echo -e "  PAT:        ${CYAN}${GITHUB_PAT:+set (${#GITHUB_PAT} chars)}${GITHUB_PAT:-${RED}NOT SET${RESET}}${RESET}"
echo -e "  Tiers:      ${CYAN}${TIERS}${RESET}"
echo ""

TOTAL_EXIT=0

# ── Tier A ──────────────────────────────────────

if [[ "$TIERS" == *"a"* ]]; then
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  bash "$SCRIPT_DIR/run-tier-a.sh" || TOTAL_EXIT=1
  echo ""
fi

# ── Tier B ──────────────────────────────────────

if [[ "$TIERS" == *"b"* ]]; then
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  if [[ -z "${GITHUB_PAT:-}" ]]; then
    echo -e "${RED}Skipping Tier B: GITHUB_PAT is not set${RESET}"
  else
    bash "$SCRIPT_DIR/run-tier-b.sh" || TOTAL_EXIT=1
  fi
  echo ""
fi

# ── Tier C ──────────────────────────────────────

if [[ "$TIERS" == *"c"* ]]; then
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  if [[ -z "${GITHUB_PAT:-}" ]]; then
    echo -e "${RED}Skipping Tier C: GITHUB_PAT is not set${RESET}"
  else
    bash "$SCRIPT_DIR/run-tier-c.sh" || TOTAL_EXIT=1
  fi
  echo ""
fi

# ── Final ───────────────────────────────────────

if [[ $TOTAL_EXIT -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All requested tiers passed.${RESET}"
else
  echo -e "${RED}${BOLD}One or more tiers had failures.${RESET}"
fi

exit $TOTAL_EXIT
