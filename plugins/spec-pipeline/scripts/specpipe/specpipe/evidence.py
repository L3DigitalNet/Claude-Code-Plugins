"""RED/GREEN evidence capture under the execution-safety contract.

Runs the task's test command, asserts the expected outcome, and appends the
captured excerpt to the phase audit file — the committed RED→GREEN trail the
close-out report cites. Because the audit file is committed, execution is
constrained: shlex argv with no shell (metacharacters inert), timeout, 64 KiB
capture cap, best-effort secret redaction over the whole evidence block
(command string included), single O_APPEND write. Encodes the skill rule that
RED must fail for the RIGHT reason via positive signatures: pytest mode needs
a 'N failed'/'FAILED' marker and rejects collection/import errors, "no tests
ran", and arbitrary non-zero commands; --framework generic requires
--expect-failure-regex (no verification-free RED path exists). Rejected
attempts are appended too (labelled REJECTED) so the trail is honest about
failed gates.
"""
from __future__ import annotations

import datetime
import re
import shlex
import subprocess
from pathlib import Path

COLLECTION_ERROR_RE = re.compile(
    r"errors? during collection|ImportError while importing|INTERNALERROR"
    r"|error collecting|SyntaxError: invalid syntax", re.I)
# RED needs a POSITIVE pytest failure marker, not merely a non-zero exit —
# "no tests ran" (exit 5), usage/config errors (exit 4), and arbitrary
# failing commands must never pass as TDD evidence.
PYTEST_FAILURE_RE = re.compile(r"^FAILED |\b\d+ failed\b", re.M)
# Best-effort shapes of common credentials; the primary defense is the skill
# rule that only reviewed-plan test commands are ever passed here.
REDACTION_RES = [
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"xox[a-z]-[A-Za-z0-9-]{10,}"),
    re.compile(r"\bsk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"\bhvs\.[A-Za-z0-9_-]{20,}"),
    re.compile(r"(?i)\bbearer\s+[A-Za-z0-9._-]{20,}"),
]
TAIL_LINES = 30
CAPTURE_CAP = 64 * 1024  # bytes of combined output kept before excerpting


def _redact(text: str) -> str:
    for pattern in REDACTION_RES:
        text = pattern.sub("[REDACTED]", text)
    return text


def _to_text(v) -> str:
    # subprocess.TimeoutExpired captures stdout/stderr as BYTES even under
    # text=True (documented behavior) — decode defensively.
    if v is None:
        return ""
    return v.decode("utf-8", "replace") if isinstance(v, bytes) else v


def _append(audit: Path, task: str, label: str, cmd: str, code: int, output: str) -> None:
    audit.parent.mkdir(parents=True, exist_ok=True)
    capped = output[-CAPTURE_CAP:]
    tail = "\n".join(_redact(capped).strip().split("\n")[-TAIL_LINES:])
    stamp = datetime.datetime.now().astimezone().isoformat(timespec="seconds")
    # Redaction covers the WHOLE block — the command string can carry a token
    # (e.g. a test env arg) just as easily as the output can.
    block = (f"\n## Task {task} — {label}\n\n"
             f"- time: {stamp}\n- cmd: `{_redact(cmd)}`\n- exit: {code}\n\n"
             f"```text\n{tail}\n```\n")
    with audit.open("a", encoding="utf-8") as fh:  # single O_APPEND write
        fh.write(block)


def record(cmd: str, task: str, audit: Path, expect: str,
           framework: str = "pytest", timeout: float = 600.0,
           expect_failure_regex: str | None = None) -> int:
    if framework == "generic" and expect == "red" and not expect_failure_regex:
        # No verification-free RED path: generic runners must state the
        # expected failure signature, mirroring pytest's collection-error rule.
        print("ERROR: --framework generic requires --expect-failure-regex "
              "(the expected failing-assertion / missing-symbol signature)")
        return 2
    if expect_failure_regex:
        try:
            re.compile(expect_failure_regex)
        except re.error as exc:
            print(f"ERROR: invalid --expect-failure-regex: {exc}")
            return 2
    try:
        argv = shlex.split(cmd)
    except ValueError as exc:
        print(f"ERROR: cannot parse command: {exc}")
        return 1
    if not argv:
        print("ERROR: empty command")
        return 1
    try:
        proc = subprocess.run(argv, shell=False, capture_output=True, text=True,
                              timeout=timeout)
    except FileNotFoundError:
        print(f"ERROR: command not found: {argv[0]}")
        return 1
    except subprocess.TimeoutExpired as exc:
        output = _to_text(exc.stdout)
        stderr_text = _to_text(exc.stderr)
        if stderr_text:
            output += "\n" + stderr_text
        _append(audit, task, f"{expect.upper()} (REJECTED — timeout after {timeout:g}s)",
                cmd, -1, output)
        print(f"GATE NOT ESTABLISHED: command timed out after {timeout:g}s")
        return 1
    output = proc.stdout + ("\n" + proc.stderr if proc.stderr else "")
    if expect == "red":
        if proc.returncode == 0:
            _append(audit, task, "RED (REJECTED — command passed)", cmd,
                    proc.returncode, output)
            print("RED NOT ESTABLISHED: command passed (expected a failing test)")
            return 1
        if framework == "pytest" and COLLECTION_ERROR_RE.search(output):
            _append(audit, task, "RED (REJECTED — collection error)", cmd,
                    proc.returncode, output)
            print("RED NOT ESTABLISHED: collection/import/syntax error — a test that "
                  "errors on collection has not established RED; fix the test first")
            return 1
        if framework == "pytest" and not PYTEST_FAILURE_RE.search(output):
            _append(audit, task, "RED (REJECTED — no test-failure signature)", cmd,
                    proc.returncode, output)
            print("RED NOT ESTABLISHED: non-zero exit but no pytest failure marker "
                  "('N failed' / 'FAILED') — no failing test was proven (no tests "
                  "ran, usage/config error, or non-pytest command)")
            return 1
        if framework == "generic":
            if not re.search(expect_failure_regex, output):
                _append(audit, task, "RED (REJECTED — expected failure signature "
                        f"/{expect_failure_regex}/ not found)", cmd,
                        proc.returncode, output)
                print("RED NOT ESTABLISHED: command failed, but not for the expected "
                      f"reason (output does not match /{expect_failure_regex}/)")
                return 1
            label = "RED (generic — expected failure signature matched)"
        else:
            label = "RED"
        _append(audit, task, label, cmd, proc.returncode, output)
        print(f"RED established for task {task} (exit {proc.returncode}); "
              f"evidence appended to {audit}")
        return 0
    if proc.returncode != 0:
        _append(audit, task, "GREEN (REJECTED — command failed)", cmd,
                proc.returncode, output)
        print(f"GREEN NOT ESTABLISHED: command failed (exit {proc.returncode})")
        return 1
    _append(audit, task, "GREEN", cmd, proc.returncode, output)
    print(f"GREEN recorded for task {task}; evidence appended to {audit}")
    return 0


def cmd_record_red(args) -> int:
    return record(args.cmd, args.task, Path(args.audit), "red",
                  framework=args.framework, timeout=args.timeout,
                  expect_failure_regex=args.expect_failure_regex)


def cmd_record_green(args) -> int:
    return record(args.cmd, args.task, Path(args.audit), "green",
                  timeout=args.timeout)
