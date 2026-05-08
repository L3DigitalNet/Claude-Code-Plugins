"""Self-tests for verify_evidence_grounded.py."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).parent / "verify_evidence_grounded.py"


def run_verify(tmp_path, report: dict, transcript_lines: list[dict]) -> tuple[int, str]:
    rp = tmp_path / "report.json"
    tp = tmp_path / "transcript.jsonl"
    rp.write_text(json.dumps(report))
    tp.write_text("\n".join(json.dumps(rec) for rec in transcript_lines) + "\n")
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), str(rp), str(tp)],
        capture_output=True,
        text=True,
    )
    return proc.returncode, proc.stdout


BASE_REPORT = {
    "findings": [],
    "escalation": {"triggered": False, "reasons": []},
    "stats": {
        "total_findings": 0,
        "by_layer": {"repo": 0, "wiki": 0, "notion": 0},
        "high_confidence": 0,
        "unverifiable": 0,
        "destructive_fixes_required": 0,
    },
}


def make_finding(command: str, signature: str, *, confidence: str = "high",
                 use_id: str | None = None) -> dict:
    ev = {"command": command, "expected_output_signature": signature}
    if use_id:
        ev["source_tool_use_id"] = use_id
    return {
        "id": 1,
        "layer": "wiki",
        "page": "Test",
        "page_id": "x",
        "stale_line": "old",
        "should_say": "new",
        "confidence": confidence,
        "destructive_fix": False,
        "evidence": ev,
    }


def test_empty_report_passes(tmp_path):
    rc, out = run_verify(tmp_path, BASE_REPORT, [])
    assert rc == 0
    assert "grounded" in out


def test_grounded_evidence_passes(tmp_path):
    """Both command and expected_output_signature appear in matching record."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh gmk 'grep BAO_ADDR /etc/foo'",
        "100.90.121.89",
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_use_id": "tu1",
        "command": "ssh gmk 'grep BAO_ADDR /etc/foo'",
        "output": "BAO_ADDR=100.90.121.89\n",
        "is_error": False,
    }]
    rc, _ = run_verify(tmp_path, report, transcript)
    assert rc == 0


def test_command_ran_but_output_contradicts_fails(tmp_path):
    """CR-003 specific: command appears in transcript but output contradicts the
    expected signature. v1 verifier would have falsely passed this."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh hetzner 'cat /home/hermes/version.txt'",
        "1.0.0",  # auditor claims this output
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_use_id": "tu1",
        "command": "ssh hetzner 'cat /home/hermes/version.txt'",
        "output": "0.8.0\n",  # actual output is different
        "is_error": False,
    }]
    rc, out = run_verify(tmp_path, report, transcript)
    assert rc == 1
    parsed = json.loads(out)
    assert parsed["fabrications"][0]["finding_id"] == 1


def test_command_never_ran_fails(tmp_path):
    """Bug #4 original scenario: cat version.txt was never invoked."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh hetzner 'cat /home/hermes/version.txt'",
        "1.0.0",
    )]}
    transcript = [{
        "tool_name": "Bash",
        "tool_use_id": "tu99",
        "command": "pct list",
        "output": "VMID NAME\n113 hermes",
        "is_error": False,
    }]
    rc, out = run_verify(tmp_path, report, transcript)
    assert rc == 1
    parsed = json.loads(out)
    assert parsed["fabrications"][0]["finding_id"] == 1


def test_source_tool_use_id_narrows_search(tmp_path):
    """When source_tool_use_id is set, search is scoped to that single record."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "echo hi",
        "hi",
        use_id="tu_target",
    )]}
    transcript = [
        {"tool_name": "Bash", "tool_use_id": "tu_other",
         "command": "echo hi", "output": "hi\n", "is_error": False},
        # The matching tool_use_id record exists but its command is different
        {"tool_name": "Bash", "tool_use_id": "tu_target",
         "command": "ls /tmp", "output": "junk", "is_error": False},
    ]
    rc, _ = run_verify(tmp_path, report, transcript)
    # tu_target's command doesn't contain 'echo hi' — fabrication
    assert rc == 1


def test_source_tool_use_id_grounded(tmp_path):
    """The tool_use_id-pinned record must itself match command + signature."""
    report = {**BASE_REPORT, "findings": [make_finding(
        "echo hi",
        "hi",
        use_id="tu_target",
    )]}
    transcript = [
        {"tool_name": "Bash", "tool_use_id": "tu_target",
         "command": "echo hi", "output": "hi\n", "is_error": False},
    ]
    rc, _ = run_verify(tmp_path, report, transcript)
    assert rc == 0


def test_unverifiable_finding_skipped_with_null_evidence(tmp_path):
    """Unverifiable findings represent failed commands; null evidence is fine."""
    finding = make_finding("does-not-matter", "does-not-matter", confidence="unverifiable")
    finding["evidence"] = None
    report = {**BASE_REPORT, "findings": [finding]}
    rc, _ = run_verify(tmp_path, report, [])
    assert rc == 0


def test_high_confidence_with_null_evidence_fails(tmp_path):
    finding = make_finding("x", "y")
    finding["evidence"] = None
    report = {**BASE_REPORT, "findings": [finding]}
    rc, out = run_verify(tmp_path, report, [])
    assert rc == 1
    parsed = json.loads(out)
    assert "evidence is null" in parsed["fabrications"][0]["reason"]


def test_malformed_transcript_lines_skipped(tmp_path):
    rp = tmp_path / "report.json"
    tp = tmp_path / "transcript.jsonl"
    report = {**BASE_REPORT, "findings": [make_finding(
        "ssh gmk 'echo hi'",
        "hi",
    )]}
    rp.write_text(json.dumps(report))
    tp.write_text(
        "not-valid-json\n"
        + json.dumps({"tool_name": "Bash", "tool_use_id": "tu1",
                      "command": "ssh gmk 'echo hi'", "output": "hi\n",
                      "is_error": False}) + "\n"
    )
    proc = subprocess.run(
        [sys.executable, str(SCRIPT), str(rp), str(tp)],
        capture_output=True, text=True,
    )
    assert proc.returncode == 0
