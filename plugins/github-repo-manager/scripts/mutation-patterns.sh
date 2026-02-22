#!/usr/bin/env bash
# mutation-patterns.sh — single source of truth for gh-manager write subcommands
#
# Sourced by gh-manager-guard.sh (PreToolUse) and gh-manager-monitor.sh (PostToolUse).
# Both scripts match the same set of operations so the pre-execution audit trail and
# the post-execution audit trail stay aligned with zero drift.
#
# To add a new mutation command: add a pattern here. Both guard and monitor pick it up
# automatically — no other files need touching.
#
# Usage: source "${BASH_SOURCE%/*}/mutation-patterns.sh"
# Then call: is_mutation_command "$COMMAND" && echo "is mutation"

# Each pattern matches one logical group of gh-manager write subcommands.
_MUTATION_PATTERNS=(
    "prs merge|prs close|prs label|prs comment|prs create|prs request-review"
    "issues close|issues label|issues comment|issues assign"
    "files put|files delete|branches create|branches delete"
    "releases draft|releases publish"
    "discussions comment|discussions close"
    "notifications mark-read|wiki push|wiki init"
    "repo labels create|repo labels update|config repo-write|config portfolio-write"
)

# Returns 0 if the command string contains a mutation subcommand, 1 otherwise.
# Skips dry-run commands automatically.
is_mutation_command() {
    local cmd="$1"

    # Dry-run calls never mutate
    echo "$cmd" | grep -q -- "--dry-run" && return 1

    for pattern in "${_MUTATION_PATTERNS[@]}"; do
        echo "$cmd" | grep -qE "$pattern" && return 0
    done
    return 1
}
