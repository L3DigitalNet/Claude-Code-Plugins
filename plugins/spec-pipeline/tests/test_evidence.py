import sys
from pathlib import Path

from specpipe import evidence

PASSING = "def test_ok():\n    assert True\n"
FAILING = "def test_no():\n    assert 1 == 2\n"
BROKEN = "import module_that_does_not_exist_xyz\n\ndef test_x():\n    assert True\n"


def _pytest_cmd(path: Path) -> str:
    return f'"{sys.executable}" -m pytest "{path}" -q'


def _project(tmp_path, name, body):
    f = tmp_path / name
    f.write_text(body, encoding="utf-8")
    return f


def test_red_on_genuine_failure(tmp_path):
    f = _project(tmp_path, "test_fail.py", FAILING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 0
    content = audit.read_text(encoding="utf-8")
    assert "## Task T1 — RED" in content and "exit:" in content


def test_red_rejected_when_tests_pass(tmp_path):
    f = _project(tmp_path, "test_pass.py", PASSING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")


def test_red_rejected_on_collection_error(tmp_path):
    f = _project(tmp_path, "test_broken.py", BROKEN)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 1
    assert "collection" in audit.read_text(encoding="utf-8")


def test_green_on_pass(tmp_path):
    f = _project(tmp_path, "test_pass.py", PASSING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "green") == 0
    assert "## Task T1 — GREEN" in audit.read_text(encoding="utf-8")


def test_green_rejected_on_failure(tmp_path):
    f = _project(tmp_path, "test_fail.py", FAILING)
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "green") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")


def test_audit_parent_dirs_created(tmp_path):
    f = _project(tmp_path, "test_fail.py", FAILING)
    audit = tmp_path / "docs" / "handoff" / "audit" / "phase-1.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 0
    assert audit.exists()


def test_shell_metacharacters_are_inert(tmp_path):
    marker = tmp_path / "pwned.txt"
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "print(\'boom\'); exit(1)" ; touch "{marker}"'
    evidence.record(cmd, "T1", audit, "red", framework="generic",
                    expect_failure_regex="boom")
    assert not marker.exists()  # ';' was an argv token, not a shell operator


def test_timeout_rejects_gate(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "import time; time.sleep(5)"'
    assert evidence.record(cmd, "T1", audit, "green", timeout=0.5) == 1
    assert "timeout" in audit.read_text(encoding="utf-8")


def test_secret_output_redacted(tmp_path):
    audit = tmp_path / "audit.md"
    script = tmp_path / "leak.py"
    script.write_text("print('token ghp_" + "a" * 30 + "')\nraise SystemExit(1)\n",
                      encoding="utf-8")
    cmd = f'"{sys.executable}" "{script}"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="token") == 0
    content = audit.read_text(encoding="utf-8")
    assert "[REDACTED]" in content
    assert "ghp_" not in content


def test_command_string_redacted(tmp_path):
    audit = tmp_path / "audit.md"
    token = "ghp_" + "b" * 30
    script = tmp_path / "fail.py"
    script.write_text("print('boom')\nraise SystemExit(1)\n", encoding="utf-8")
    cmd = f'"{sys.executable}" "{script}" {token}'  # token as an argv arg
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="boom") == 0
    content = audit.read_text(encoding="utf-8")
    assert "[REDACTED]" in content
    assert "ghp_" not in content  # redaction covers the recorded cmd line too


def test_pytest_red_rejects_arbitrary_nonzero(tmp_path):
    # a non-pytest failing command must not pass as pytest RED evidence
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red") == 1
    assert "no test-failure signature" in audit.read_text(encoding="utf-8")


def test_pytest_red_rejects_no_tests_ran(tmp_path):
    # pytest exit 5 (no tests collected) is non-zero but proves nothing
    f = _project(tmp_path, "test_empty.py", "# intentionally no tests\n")
    audit = tmp_path / "audit.md"
    assert evidence.record(_pytest_cmd(f), "T1", audit, "red") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")


def test_timeout_with_partial_output_still_recorded(tmp_path):
    # TimeoutExpired.stdout/stderr are BYTES even with text=True — the handler
    # must decode, not crash, and still record the rejected gate
    audit = tmp_path / "audit.md"
    script = tmp_path / "noisy.py"
    script.write_text(
        "import sys, time\nprint('partial output', flush=True)\n"
        "print('warn', file=sys.stderr, flush=True)\ntime.sleep(5)\n",
        encoding="utf-8")
    cmd = f'"{sys.executable}" "{script}"'
    assert evidence.record(cmd, "T1", audit, "green", timeout=1.0) == 1
    content = audit.read_text(encoding="utf-8")
    assert "timeout" in content and "partial output" in content


def test_generic_without_regex_is_bad_invocation(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "raise SystemExit(3)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic") == 2
    assert not audit.exists()  # rejected before anything ran or was recorded


def test_generic_invalid_regex_is_bad_invocation(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="([unclosed") == 2
    assert not audit.exists()  # rejected before anything ran or was recorded


def test_generic_expect_failure_regex_matched(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "print(\'boom_assert failed\'); raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="boom_assert") == 0
    assert "signature matched" in audit.read_text(encoding="utf-8")


def test_generic_expect_failure_regex_unmatched_rejected(tmp_path):
    audit = tmp_path / "audit.md"
    cmd = f'"{sys.executable}" -c "print(\'segfault-ish runner crash\'); raise SystemExit(1)"'
    assert evidence.record(cmd, "T1", audit, "red", framework="generic",
                           expect_failure_regex="boom_assert") == 1
    assert "REJECTED" in audit.read_text(encoding="utf-8")
