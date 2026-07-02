from specpipe.findings import ERROR, WARNING, Finding, exit_code, report


def test_exit_code_error_is_1():
    assert exit_code([Finding(ERROR, "X-1", "boom")]) == 1


def test_exit_code_warning_only_is_0():
    assert exit_code([Finding(WARNING, "X-2", "meh")]) == 0


def test_exit_code_empty_is_0():
    assert exit_code([]) == 0


def test_report_human_counts():
    out = report([Finding(ERROR, "X-1", "boom", "f.md:3"), Finding(WARNING, "X-2", "meh")])
    assert "X-1" in out and "f.md:3" in out
    assert "1 error(s), 1 warning(s)" in out


def test_report_empty():
    assert report([]) == "OK — no findings"


def test_report_json_shape():
    import json
    data = json.loads(report([Finding(ERROR, "X-1", "boom")], as_json=True))
    assert data["errors"] == 1 and data["warnings"] == 0
    assert data["findings"][0]["code"] == "X-1"
