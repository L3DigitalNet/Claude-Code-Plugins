#!/usr/bin/env bash
# coverage-sweep.sh — Pre-Phase-5 coverage check for design-draft.
#
# Checks constraints, risks, and governance requirements against
# document sections and open questions.
#
# Usage: echo '<combined-json>' | coverage-sweep.sh
# Input: JSON on stdin with context, sections, open_questions.
# Output: JSON with coverage status per category and ready_for_phase_5.
# Exit:   0 always.

set -euo pipefail
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null) \
  || { echo '{"error":"python3 not found"}' >&2; exit 1; }

# Capture stdin before the heredoc consumes it — piped JSON would otherwise
# be lost because the heredoc replaces stdin for the python process.
INPUT_JSON=$(cat)
export INPUT_JSON

$PYTHON << 'PYEOF'
import json, re, sys, os

STOP_WORDS = {
    "a", "an", "the", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "do", "does", "did", "will", "would", "shall",
    "should", "may", "might", "must", "can", "could", "of", "in", "to",
    "for", "with", "on", "at", "from", "by", "as", "or", "and", "but",
    "not", "no", "if", "that", "this", "it", "its", "all", "any", "each",
}

def extract_keywords(text):
    """Extract significant words from text, excluding stop words."""
    words = re.findall(r'\b\w{3,}\b', text.lower())
    return [w for w in words if w not in STOP_WORDS]

def match_item(item, sections, open_questions):
    """Match an item against sections and open questions."""
    item_lower = item.lower()
    keywords = extract_keywords(item)

    # Check open questions first
    for oq in open_questions:
        if item_lower in oq.get("text", "").lower():
            return "open_question", oq.get("associated_section"), "exact"

    # Check sections
    best_match = None
    best_confidence = "none"

    for section in sections:
        content = section.get("content_summary", "").lower()
        section_name = section.get("name", "")

        # Exact match
        if item_lower in content:
            return "covered", section_name, "exact"

        # Partial match: 2+ keywords
        if keywords:
            matched = sum(1 for kw in keywords if kw in content)
            if matched >= 2 and matched >= len(keywords) * 0.4:
                if best_confidence != "partial" or not best_match:
                    best_match = section_name
                    best_confidence = "partial"

    if best_match:
        return "covered", best_match, best_confidence

    return "uncovered", None, "none"

try:
    data = json.loads(os.environ.get("INPUT_JSON", ""))
except (json.JSONDecodeError, ValueError) as e:
    print(json.dumps({"error": f"Invalid JSON input: {e}"}), file=sys.stderr)
    sys.exit(1)

context = data.get("context", {})
sections = data.get("sections", [])
open_questions = data.get("open_questions", [])

blocking_items = []
result = {}

for category in ("constraints", "risks", "governance"):
    items = context.get(category, [])
    cat_result = {
        "total": len(items),
        "covered": 0,
        "open_question": 0,
        "uncovered": 0,
        "items": [],
    }

    for item_text in items:
        status, section, confidence = match_item(item_text, sections, open_questions)

        cat_result["items"].append({
            "item": item_text,
            "status": status,
            "section": section,
            "confidence": confidence,
        })

        if status == "covered":
            cat_result["covered"] += 1
        elif status == "open_question":
            cat_result["open_question"] += 1
        else:
            cat_result["uncovered"] += 1
            blocking_items.append(f"{item_text} ({category}, uncovered)")

    result[category] = cat_result

result["ready_for_phase_5"] = len(blocking_items) == 0
result["blocking_items"] = blocking_items

print(json.dumps(result, indent=2))
PYEOF
