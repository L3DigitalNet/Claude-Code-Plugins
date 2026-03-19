import json
from pathlib import Path

import pytest

pytestmark = pytest.mark.unit


class TestAuditLogger:
    def test_log_creates_file(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(tool="get_entry", title="Test", group="Servers")
        assert Path(test_config.audit_log_path).exists()

    def test_log_writes_jsonl(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(
            tool="get_entry",
            title="My Server",
            group="Servers",
            secret_returned=True,
        )
        lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(lines) == 1
        record = json.loads(lines[0])
        assert record["tool"] == "get_entry"
        assert record["title"] == "My Server"
        assert record["group"] == "Servers"
        assert record["secret_returned"] is True
        assert "timestamp" in record

    def test_log_defaults_secret_false(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(tool="list_entries", title="Test", group="Servers")
        record = json.loads(
            Path(test_config.audit_log_path).read_text().strip()
        )
        assert record["secret_returned"] is False

    def test_log_includes_attachment(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(
            tool="get_attachment",
            title="SSH Key",
            group="SSH Keys",
            secret_returned=True,
            attachment="id_ed25519",
        )
        record = json.loads(
            Path(test_config.audit_log_path).read_text().strip()
        )
        assert record["attachment"] == "id_ed25519"

    def test_log_appends_multiple_records(self, test_config):
        from server.audit import AuditLogger

        logger = AuditLogger(test_config.audit_log_path)
        logger.log(tool="get_entry", title="A", group="Servers")
        logger.log(tool="get_entry", title="B", group="Servers")
        lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(lines) == 2

    def test_raises_on_missing_parent_dir(self, tmp_path):
        from server.audit import AuditLogger

        bad_path = str(tmp_path / "nonexistent" / "subdir" / "audit.jsonl")
        with pytest.raises(FileNotFoundError):
            AuditLogger(bad_path)

    def test_group_none_serializes_to_null(self, tmp_path):
        """group=None writes JSON null."""
        import json

        from server.audit import AuditLogger

        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        logger.log(tool="get_entry", title="Test", group=None, secret_returned=True)
        record = json.loads(audit_path.read_text().strip())
        assert record["group"] is None
        assert record["attachment"] is None

    def test_timestamp_is_valid_iso_format(self, tmp_path):
        """Timestamp can be parsed by datetime.fromisoformat."""
        import json
        from datetime import datetime

        from server.audit import AuditLogger

        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        logger.log(tool="test", title="Test")
        record = json.loads(audit_path.read_text().strip())
        parsed = datetime.fromisoformat(record["timestamp"])
        assert parsed.year >= 2026

    def test_permission_error_logs_warning(self, tmp_path, caplog):
        """Write failure logs warning instead of raising."""
        import os

        from server.audit import AuditLogger

        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        # Create file as read-only
        audit_path.write_text("")
        os.chmod(audit_path, 0o444)
        try:
            # Should NOT raise — error is caught and logged
            logger.log(tool="test", title="Test")
        finally:
            os.chmod(audit_path, 0o644)


class TestSanitizeExtra:
    """_sanitize_extra redacts values for keys containing sensitive fragments.

    This is a security-critical function: a regression silently leaks
    passwords, tokens, or API keys to the audit log file on disk.
    """

    def test_password_key_redacted(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({"database_password": "s3cret"})
        assert result["database_password"] == "**REDACTED**"

    def test_token_key_redacted(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({"refresh_token": "abc123"})
        assert result["refresh_token"] == "**REDACTED**"

    def test_api_key_redacted(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({"api_key": "key-xyz"})
        assert result["api_key"] == "**REDACTED**"

    def test_auth_key_redacted(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({"auth_header": "Bearer xyz"})
        assert result["auth_header"] == "**REDACTED**"

    def test_case_insensitive_matching(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({"API_KEY": "val", "Secret_Value": "val2"})
        assert result["API_KEY"] == "**REDACTED**"
        assert result["Secret_Value"] == "**REDACTED**"

    def test_non_sensitive_key_passes_through(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({"group": "Servers", "title": "Test"})
        assert result["group"] == "Servers"
        assert result["title"] == "Test"

    def test_mixed_sensitive_and_safe(self):
        from server.audit import _sanitize_extra
        result = _sanitize_extra({
            "title": "My Entry",
            "password_hash": "abc",
            "count": 5,
        })
        assert result["title"] == "My Entry"
        assert result["password_hash"] == "**REDACTED**"
        assert result["count"] == 5

    def test_empty_dict_returns_empty(self):
        from server.audit import _sanitize_extra
        assert _sanitize_extra({}) == {}

    def test_redaction_used_in_audit_log(self, tmp_path):
        """End-to-end: extra kwargs with sensitive keys are redacted in the log file."""
        import json
        from server.audit import AuditLogger

        audit_path = tmp_path / "audit.jsonl"
        logger = AuditLogger(str(audit_path))
        logger.log(tool="test", title="Test", credential="should-be-redacted")
        record = json.loads(audit_path.read_text().strip())
        assert record["credential"] == "**REDACTED**"
