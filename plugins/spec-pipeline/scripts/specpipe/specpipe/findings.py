"""Finding model + report rendering shared by every specpipe validator.

Cross-file contract: validators return list[Finding]; __main__ handlers render
via report() and convert to the process exit code via exit_code().
"""
from __future__ import annotations

import json
from dataclasses import asdict, dataclass

ERROR = "error"
WARNING = "warning"


@dataclass
class Finding:
    severity: str  # ERROR | WARNING
    code: str      # stable machine id, e.g. PP-DUP-ID
    message: str
    location: str = ""  # "file:line" or "file"


def exit_code(findings: list[Finding]) -> int:
    return 1 if any(f.severity == ERROR for f in findings) else 0


def report(findings: list[Finding], as_json: bool = False) -> str:
    errors = [f for f in findings if f.severity == ERROR]
    warnings = [f for f in findings if f.severity == WARNING]
    if as_json:
        return json.dumps(
            {"errors": len(errors), "warnings": len(warnings),
             "findings": [asdict(f) for f in findings]},
            indent=2,
        )
    if not findings:
        return "OK — no findings"
    lines = [
        f"[{f.severity.upper():7}] {f.code}  {f.message}"
        + (f"  ({f.location})" if f.location else "")
        for f in findings
    ]
    lines.append(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    return "\n".join(lines)
