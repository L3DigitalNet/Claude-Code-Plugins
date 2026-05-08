#!/usr/bin/env bash
# hook-smoke.sh — Task 8 smoke test for plugin hook firing.
# Records to /tmp/up-docs-hook-smoke.log every time it runs.
# Exit 0 always — never blocks any tool call during the smoke test.
set -u
echo "fired $(date -Iseconds) tool=${1:-?}" >> /tmp/up-docs-hook-smoke.log 2>/dev/null || true
exit 0
