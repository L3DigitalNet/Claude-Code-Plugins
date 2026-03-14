import pytest
import yaml

from server.config import load_config
from server.yubikey import MockYubiKey


@pytest.fixture
def mock_yubikey():
    return MockYubiKey(present=True, slot=2)


@pytest.fixture
def test_config(tmp_path):
    db_path = tmp_path / "test.kdbx"
    db_path.touch()
    audit_path = tmp_path / "audit.jsonl"
    cfg = {
        "database_path": str(db_path),
        "yubikey_slot": "2",
        "grace_period_seconds": 2,
        "yubikey_poll_interval_seconds": 1,
        "write_lock_timeout_seconds": 2,
        "page_size": 50,
        "audit_log_path": str(audit_path),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    return load_config(str(config_file))
