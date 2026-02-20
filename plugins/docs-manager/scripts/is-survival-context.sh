#!/usr/bin/env bash
# Single shared implementation of the P5 survival-context classification rule.
# Called by template inference, hook scripts, and document creation — they
# never encode this rule independently.
#
# Classification: survival = (doc-type in {sysadmin,dev,personal}) AND (audience in {human,both})
# audience:ai overrides doc-type (the P5 exception)
#
# Usage:
#   is-survival-context.sh <file-path>
#   is-survival-context.sh --doc-type TYPE --audience AUDIENCE
# Output: "true" or "false" — always exits 0
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

classify() {
    local doc_type="$1" audience="$2"

    # Default audience to human if not set
    [[ -z "$audience" ]] && audience="human"

    # P5 exception: ai audience is never survival-context
    [[ "$audience" == "ai" ]] && { echo "false"; return 0; }

    # Audience must be human or both
    case "$audience" in
        human|both) ;;
        *) echo "false"; return 0 ;;
    esac

    # Doc-type must be sysadmin, dev, or personal
    case "$doc_type" in
        sysadmin|dev|personal) echo "true" ;;
        *) echo "false" ;;
    esac
}

main() {
    local doc_type="" audience="" filepath=""

    # Parse args
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --doc-type) doc_type="$2"; shift 2 ;;
            --audience) audience="$2"; shift 2 ;;
            *)
                # Positional arg = file path
                filepath="$1"; shift ;;
        esac
    done

    # If file path provided, extract from frontmatter
    if [[ -n "$filepath" ]]; then
        if [[ ! -f "$filepath" ]]; then
            echo "false"
            return 0
        fi
        doc_type=$(bash "$SCRIPTS_DIR/frontmatter-read.sh" "$filepath" doc-type 2>/dev/null || echo "")
        audience=$(bash "$SCRIPTS_DIR/frontmatter-read.sh" "$filepath" audience 2>/dev/null || echo "")

        # No frontmatter or no doc-type = not survival
        if [[ -z "$doc_type" ]]; then
            echo "false"
            return 0
        fi
    fi

    classify "$doc_type" "$audience"
}

main "$@"
exit 0
