"""Verify every `evidence` field in an auditor report is grounded in the
captured PostToolUse transcript.

CR-003 contract:
    Each Finding has Evidence = {command, expected_output_signature, source_tool_use_id?}.
    A finding is "grounded" if there exists a transcript record where:
      - record["tool_input"]["command"] contains evidence.command (or evidence.command
        contains record["tool_input"]["command"] — match in either direction to allow
        for prefix/suffix differences in shell quoting), AND
      - record["tool_response"]["output"] contains evidence.expected_output_signature
        as a literal substring.
    If evidence.source_tool_use_id is set, the search is restricted to the record
    with that tool_use_id (single record).

    Findings with confidence='unverifiable' are skipped (their evidence is nullable).

Usage:
    python3 verify_evidence_grounded.py <auditor-report.json> <transcript.jsonl>

Exit:
    0 = every non-unverifiable finding is grounded
    1 = at least one fabrication detected (details printed to stdout as JSON)
    2 = bad arguments or malformed input
"""
from __future__ import annotations

import json
import sys
from typing import Any


def load_transcript(path: str) -> list[dict]:
    """Read a JSONL file produced by capture-transcript.sh, skipping malformed lines."""
    records: list[dict] = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError:
                continue  # skip malformed lines, fail open
    return records


def find_grounding(evidence: dict, transcript: list[dict]) -> dict | None:
    """Return the matching transcript record, or None if no match."""
    cmd = evidence.get("command", "") or ""
    sig = evidence.get("expected_output_signature", "") or ""
    use_id = evidence.get("source_tool_use_id")

    if not cmd or not sig:
        return None

    candidates = transcript
    if use_id:
        candidates = [r for r in transcript if r.get("tool_use_id") == use_id]

    for rec in candidates:
        rec_cmd = rec.get("command", "")
        if not (cmd in rec_cmd or rec_cmd in cmd):
            continue
        rec_out = rec.get("output", "")
        if sig in rec_out:
            return rec
    return None


def verify(report_path: str, transcript_path: str) -> int:
    with open(report_path) as f:
        report = json.load(f)
    transcript = load_transcript(transcript_path)
    violations: list[dict[str, Any]] = []
    for finding in report.get("findings", []):
        if finding.get("confidence") == "unverifiable":
            continue
        ev = finding.get("evidence")
        if ev is None:
            violations.append({
                "finding_id": finding.get("id"),
                "reason": "evidence is null but confidence is not unverifiable",
            })
            continue
        if not isinstance(ev, dict):
            violations.append({
                "finding_id": finding.get("id"),
                "reason": "evidence must be an object with command + expected_output_signature",
            })
            continue
        match = find_grounding(ev, transcript)
        if match is None:
            violations.append({
                "finding_id": finding.get("id"),
                "evidence_command": ev.get("command"),
                "expected_signature": ev.get("expected_output_signature"),
                "source_tool_use_id": ev.get("source_tool_use_id"),
                "reason": (
                    "no transcript record matches both the command and the expected "
                    "output signature — evidence is fabricated or output contradicts claim"
                ),
            })
    if violations:
        print(json.dumps({"fabrications": violations}, indent=2))
        return 1
    print("evidence grounded")
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: verify_evidence_grounded.py <report.json> <transcript.jsonl>",
            file=sys.stderr,
        )
        return 2
    return verify(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    sys.exit(main())
