import os
from pathlib import Path

import pytest
import yaml

pytestmark = pytest.mark.unit


@pytest.fixture
def valid_config(tmp_path):
    """Write a valid config YAML and create the database file."""
    db_path = tmp_path / "test.kdbx"
    db_path.touch()
    cfg = {
        "database_path": str(db_path),
        "yubikey_slot": 2,
        "grace_period_seconds": 10,
        "yubikey_poll_interval_seconds": 5,
        "write_lock_timeout_seconds": 10,
        "page_size": 50,
        "allowed_groups": ["Servers", "SSH Keys", "API Keys"],
        "audit_log_path": str(tmp_path / "audit.jsonl"),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    return str(config_file)


@pytest.fixture
def minimal_config(tmp_path):
    """Config with only required fields — defaults should fill the rest."""
    db_path = tmp_path / "test.kdbx"
    db_path.touch()
    cfg = {
        "database_path": str(db_path),
        "allowed_groups": ["Servers"],
        "audit_log_path": str(tmp_path / "audit.jsonl"),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    return str(config_file)


class TestConfigLoading:
    def test_loads_valid_config(self, valid_config, tmp_path):
        from server.config import load_config

        config = load_config(valid_config)
        assert config.database_path == str(tmp_path / "test.kdbx")
        assert config.yubikey_slot == "2"

    def test_defaults_applied_for_optional_fields(self, minimal_config):
        from server.config import load_config

        config = load_config(minimal_config)
        assert config.yubikey_slot == "2"
        assert config.grace_period_seconds == 10
        assert config.yubikey_poll_interval_seconds == 5
        assert config.write_lock_timeout_seconds == 10
        assert config.page_size == 50

    def test_expands_tilde_in_paths(self, tmp_path):
        # Use a real db path; test tilde expansion on audit_log_path (which need not exist)
        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "allowed_groups": ["Servers"],
            "audit_log_path": "~/audit.jsonl",
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        config = load_config(str(config_file))
        assert "~" not in config.audit_log_path
        assert config.audit_log_path == os.path.expanduser("~/audit.jsonl")

    def test_raises_on_missing_database_path(self, tmp_path):
        cfg = {
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        with pytest.raises(ValueError, match="database_path"):
            load_config(str(config_file))

    def test_loads_without_allowed_groups(self, tmp_path):
        """allowed_groups is no longer required — config loads without it."""
        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        config = load_config(str(config_file))
        assert config.database_path == str(db_path)

    def test_legacy_allowed_groups_key_ignored(self, tmp_path):
        """Old configs with allowed_groups still load — the key is silently dropped."""
        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "allowed_groups": ["Servers", "SSH Keys"],
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        config = load_config(str(config_file))
        assert config.database_path == str(db_path)

    def test_raises_on_missing_audit_log_path(self, tmp_path):
        cfg = {
            "database_path": str(tmp_path / "test.kdbx"),
            "allowed_groups": ["Servers"],
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        with pytest.raises(ValueError, match="audit_log_path"):
            load_config(str(config_file))

    def test_loads_from_env_var(self, valid_config, monkeypatch):
        monkeypatch.setenv("KEEPASS_CRED_MGR_CONFIG", valid_config)
        from server.config import load_config

        config = load_config()
        assert config.yubikey_slot == "2"

    def test_raises_on_missing_config_file(self):
        from server.config import load_config

        with pytest.raises(FileNotFoundError):
            load_config("/nonexistent/path.yaml")

    def test_raises_when_no_path_and_no_env_var(self, monkeypatch):
        """load_config() with no path and no env var."""
        from server.config import load_config

        monkeypatch.delenv("KEEPASS_CRED_MGR_CONFIG", raising=False)
        with pytest.raises(FileNotFoundError, match="No config path provided"):
            load_config()

    def test_empty_yaml_file_raises(self, tmp_path):
        """Empty YAML file still enforces required fields."""
        from server.config import load_config

        config_file = tmp_path / "empty.yaml"
        config_file.write_text("")
        with pytest.raises(ValueError, match="Missing required config field"):
            load_config(str(config_file))

    def test_invalid_yaml_raises(self, tmp_path):
        """Malformed YAML raises yaml.YAMLError."""
        import yaml as yaml_mod

        from server.config import load_config

        config_file = tmp_path / "bad.yaml"
        config_file.write_text("{{invalid:: yaml::")
        with pytest.raises(yaml_mod.YAMLError):
            load_config(str(config_file))

    def test_non_string_database_path_rejected(self, tmp_path):
        """Non-string database_path is rejected by validation."""
        from server.config import load_config

        cfg = {
            "database_path": 12345,
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        with pytest.raises(ValueError, match="database_path.*must be a string"):
            load_config(str(config_file))

    def test_allowed_groups_string_ignored(self, tmp_path):
        """allowed_groups with a string value is silently ignored (not validated)."""
        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "allowed_groups": "Servers",
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        from server.config import load_config

        config = load_config(str(config_file))
        assert config.database_path == str(db_path)

    def test_yubikey_slot_must_be_positive(self, tmp_path):
        """Zero or negative yubikey_slot is rejected."""
        from server.config import load_config

        cfg = {
            "database_path": str(tmp_path / "test.kdbx"),
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "yubikey_slot": 0,
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        with pytest.raises(ValueError, match="yubikey_slot"):
            load_config(str(config_file))

    def test_yubikey_slot_with_serial(self, tmp_path):
        """yubikey_slot accepts 'slot:serial' format."""
        from server.config import load_config

        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "yubikey_slot": "2:36834370",
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        config = load_config(str(config_file))
        assert config.yubikey_slot == "2:36834370"

    def test_yubikey_slot_int_coerced_to_str(self, tmp_path):
        """Integer yubikey_slot from YAML is coerced to string."""
        from server.config import load_config

        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "yubikey_slot": 2,
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        config = load_config(str(config_file))
        assert config.yubikey_slot == "2"

    def test_negative_timeout_rejected(self, tmp_path):
        """Negative timeout values are rejected."""
        from server.config import load_config

        cfg = {
            "database_path": str(tmp_path / "test.kdbx"),
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "grace_period_seconds": -5,
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        with pytest.raises(ValueError, match="grace_period_seconds.*>= 1"):
            load_config(str(config_file))

    def test_log_level_valid(self, tmp_path):
        """Custom log level is accepted when valid."""
        from server.config import load_config

        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "log_level": "DEBUG",
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        config = load_config(str(config_file))
        assert config.log_level == "DEBUG"

    def test_log_level_invalid_rejected(self, tmp_path):
        """Invalid log level is rejected."""
        from server.config import load_config

        cfg = {
            "database_path": str(tmp_path / "test.kdbx"),
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "log_level": "TRACE",
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        with pytest.raises(ValueError, match="log_level"):
            load_config(str(config_file))

    def test_log_level_default(self, minimal_config):
        """Log level defaults to INFO when omitted."""
        from server.config import load_config

        config = load_config(minimal_config)
        assert config.log_level == "INFO"

    def test_database_not_found_raises(self, tmp_path):
        """FileNotFoundError when database_path does not exist on disk."""
        from server.config import load_config

        cfg = {
            "database_path": str(tmp_path / "missing.kdbx"),
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        with pytest.raises(FileNotFoundError, match="KeePass database not found"):
            load_config(str(config_file))

    def test_non_integer_timeout_rejected(self, tmp_path):
        """A string value for an integer field raises ValueError with type info."""
        from server.config import load_config

        db_path = tmp_path / "test.kdbx"
        db_path.touch()
        cfg = {
            "database_path": str(db_path),
            "allowed_groups": ["Servers"],
            "audit_log_path": str(tmp_path / "audit.jsonl"),
            "grace_period_seconds": "ten",  # string, not int
        }
        config_file = tmp_path / "config.yaml"
        config_file.write_text(yaml.dump(cfg))
        with pytest.raises(ValueError, match="must be an integer"):
            load_config(str(config_file))
