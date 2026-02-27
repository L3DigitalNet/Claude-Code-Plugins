"""Integration tests against real test.kdbx.

Requires keepassxc-cli installed. No YubiKey needed (test db uses password only).
These tests are templates; they skip cleanly if keepassxc-cli is unavailable
or if the test database hasn't been created yet.
"""

import shutil
from pathlib import Path

import pytest

# Skip entire module if keepassxc-cli not available
pytestmark = pytest.mark.integration

KEEPASSXC_CLI = shutil.which("keepassxc-cli")
if not KEEPASSXC_CLI:
    pytest.skip("keepassxc-cli not installed", allow_module_level=True)

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"
TEST_DB = FIXTURES_DIR / "test.kdbx"

if not TEST_DB.exists():
    pytest.skip("test.kdbx not found — run create_test_db.sh", allow_module_level=True)


@pytest.fixture
def integration_setup(tmp_path):
    """Copy test db to tmp, create config, return vault + audit."""
    import yaml
    from server.config import load_config
    from server.vault import Vault
    from server.audit import AuditLogger
    from server.yubikey import MockYubiKey

    # Copy db so writes don't pollute the fixture
    db_copy = tmp_path / "test.kdbx"
    shutil.copy(TEST_DB, db_copy)

    audit_path = tmp_path / "audit.jsonl"
    cfg = {
        "database_path": str(db_copy),
        "yubikey_slot": 2,
        "grace_period_seconds": 2,
        "yubikey_poll_interval_seconds": 1,
        "write_lock_timeout_seconds": 5,
        "page_size": 50,
        "allowed_groups": ["Servers", "SSH Keys", "API Keys"],
        "audit_log_path": str(audit_path),
    }
    config_file = tmp_path / "config.yaml"
    config_file.write_text(yaml.dump(cfg))
    config = load_config(str(config_file))

    # Use MockYubiKey; integration tests don't need real YubiKey.
    # Force unlock state for password-only db.
    yk = MockYubiKey(present=True, slot=2)
    vault = Vault(config, yk)
    vault._unlocked = True
    audit = AuditLogger(str(audit_path))

    return vault, audit, config, db_copy


# NOTE: Integration tests are templates.
# The exact CLI invocations depend on keepassxc-cli version and password-mode behavior.
# The implementer should adapt Vault.run_cli or create a PasswordVault subclass
# for integration testing with password-only databases.


class TestIntegrationReadCycle:
    def test_list_groups_returns_allowed(self, integration_setup):
        """list_groups returns only allowed groups."""
        pass  # Requires password-mode vault override


class TestIntegrationWriteCycle:
    def test_create_then_list(self, integration_setup):
        """create_entry then list_entries confirms presence."""
        pass  # Requires password-mode vault override


class TestIntegrationRotation:
    def test_rotation_cycle(self, integration_setup):
        """create -> deactivate -> confirm [INACTIVE] -> create same title."""
        pass  # Requires password-mode vault override


class TestIntegrationDuplicatePrevention:
    def test_duplicate_raises(self, integration_setup):
        """create_entry twice raises DuplicateEntry on second."""
        pass  # Requires password-mode vault override


class TestIntegrationInactiveFiltering:
    def test_inactive_hidden_by_default(self, integration_setup):
        """list_entries hides [INACTIVE]; shows with flag."""
        pass  # Requires password-mode vault override


class TestIntegrationGroupAllowlist:
    def test_disallowed_group_raises(self, integration_setup):
        """Request for unlisted group raises GroupNotAllowed."""
        pass  # Requires password-mode vault override
