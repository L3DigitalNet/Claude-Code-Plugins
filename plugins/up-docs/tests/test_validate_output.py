"""Self-tests for tests/validate_output.py."""
from __future__ import annotations

import copy
import sys
from pathlib import Path

import pytest
from pydantic import ValidationError

sys.path.insert(0, str(Path(__file__).parent))
from validate_output import (  # noqa: E402
    NotionReport,
    RepoReport,
    VALIDATORS,
    WikiReport,
    validate_auditor,
    validate_propagator,
)


VALID_REPO = {
    "layer": "repo",
    "rows": [{"n": 1, "target": "README.md", "action": "Updated", "summary": "Added flag"}],
    "totals": {"updated": 1, "created": 0, "unchanged": 0, "failed": 0},
}

VALID_WIKI = {
    "layer": "wiki",
    "rows": [{"n": 1, "target": "OpenBao Page", "action": "Updated", "summary": "Listener note added"}],
    "totals": {"updated": 1, "created": 0, "unchanged": 0, "failed": 0},
}

VALID_NOTION = {
    "layer": "notion",
    "rows": [{"n": 1, "target": "OpenBao", "action": "Updated", "summary": "Listener rebound."}],
    "totals": {"updated": 1, "created": 0, "unchanged": 0, "failed": 0},
}

VALID_AUDITOR = {
    "findings": [
        {
            "id": 1,
            "layer": "wiki",
            "page": "OpenBao",
            "page_id": "abc",
            "stale_line": "BAO_ADDR=127.0.0.1",
            "should_say": "BAO_ADDR=100.90.121.89",
            "confidence": "high",
            "destructive_fix": False,
            "evidence": {
                "command": "ssh gmk 'grep BAO_ADDR /usr/local/bin/backup.sh'",
                "expected_output_signature": "BAO_ADDR=100.90.121.89",
                "source_tool_use_id": "toolu_01abc",
            },
        }
    ],
    "escalation": {"triggered": False, "reasons": []},
    "stats": {
        "total_findings": 1,
        "by_layer": {"repo": 0, "wiki": 1, "notion": 0},
        "high_confidence": 1,
        "unverifiable": 0,
        "destructive_fixes_required": 0,
    },
}


# --- propagator validation -------------------------------------------------

def test_valid_repo_passes():
    obj = validate_propagator(VALID_REPO)
    assert isinstance(obj, RepoReport)


def test_valid_wiki_passes():
    obj = validate_propagator(VALID_WIKI)
    assert isinstance(obj, WikiReport)


def test_valid_notion_passes():
    obj = validate_propagator(VALID_NOTION)
    assert isinstance(obj, NotionReport)


def test_propagator_rejects_unknown_action():
    bad = copy.deepcopy(VALID_REPO)
    bad["rows"][0]["action"] = "Frobnicated"
    with pytest.raises(ValidationError):
        validate_propagator(bad)


def test_propagator_rejects_unknown_layer():
    """CR-008: discriminator catches wrong-layer values structurally."""
    bad = copy.deepcopy(VALID_REPO)
    bad["layer"] = "drift"
    with pytest.raises(ValidationError, match="union_tag_invalid"):
        validate_propagator(bad)


def test_propagator_rejects_extra_top_level_field():
    bad = copy.deepcopy(VALID_REPO)
    bad["spurious"] = "extra"
    with pytest.raises(ValidationError):
        validate_propagator(bad)


def test_propagator_rejects_totals_mismatch():
    bad = copy.deepcopy(VALID_REPO)
    bad["totals"]["updated"] = 5  # but only 1 row
    with pytest.raises(ValidationError, match="totals do not match"):
        validate_propagator(bad)


def test_notion_rejects_ipv4_in_summary():
    """Bug #4-class regression: IPv4 must never leak into Notion."""
    bad = copy.deepcopy(VALID_NOTION)
    bad["rows"][0]["summary"] = "Listener bound to 100.90.121.89"
    with pytest.raises(ValidationError, match="IPv4 leaked"):
        validate_propagator(bad)


def test_notion_allows_ipv6_in_summary():
    """Sanity: an IPv6 in the summary is allowed (we only block IPv4 for Notion)."""
    payload = copy.deepcopy(VALID_NOTION)
    payload["rows"][0]["summary"] = "Listener on [fd00::1]"
    # No IPv4 → must validate
    obj = validate_propagator(payload)
    assert isinstance(obj, NotionReport)


# --- auditor validation ----------------------------------------------------

def test_valid_auditor_passes():
    validate_auditor(VALID_AUDITOR)


def test_auditor_rejects_unknown_confidence():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["confidence"] = "highish"
    with pytest.raises(ValidationError):
        validate_auditor(bad)


def test_auditor_rejects_stats_mismatch():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["stats"]["total_findings"] = 5  # but only 1 finding
    with pytest.raises(ValidationError, match="total_findings"):
        validate_auditor(bad)


def test_auditor_rejects_string_evidence():
    """CR-003 enforcement: free-form string evidence is no longer schema-valid."""
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["evidence"] = "ssh host returned 1.0.0"  # was a string in v1
    with pytest.raises(ValidationError):
        validate_auditor(bad)


def test_auditor_rejects_evidence_missing_signature():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["evidence"] = {
        "command": "ssh host whatever",
        # missing expected_output_signature
    }
    with pytest.raises(ValidationError):
        validate_auditor(bad)


def test_auditor_rejects_high_confidence_with_null_evidence():
    bad = copy.deepcopy(VALID_AUDITOR)
    bad["findings"][0]["evidence"] = None
    with pytest.raises(ValidationError, match="must have a non-null evidence"):
        validate_auditor(bad)


def test_auditor_allows_unverifiable_with_null_evidence():
    """unverifiable findings represent commands that failed; null evidence is fine."""
    payload = copy.deepcopy(VALID_AUDITOR)
    payload["findings"][0]["confidence"] = "unverifiable"
    payload["findings"][0]["evidence"] = None
    payload["stats"]["high_confidence"] = 0
    payload["stats"]["unverifiable"] = 1
    validate_auditor(payload)  # no raise


def test_validators_cover_all_four_agent_names():
    expected = {
        "up-docs-propagate-repo",
        "up-docs-propagate-wiki",
        "up-docs-propagate-notion",
        "up-docs-audit-drift",
    }
    assert set(VALIDATORS) == expected
