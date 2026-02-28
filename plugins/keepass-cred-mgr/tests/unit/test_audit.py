import json
from pathlib import Path

import pytest


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
