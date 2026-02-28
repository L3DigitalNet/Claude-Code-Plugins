"""Integration tests against real test.kdbx.

Requires keepassxc-cli installed. No YubiKey needed (test db uses password only).
These tests call real keepassxc-cli commands via the PasswordVault helper.
"""

import shutil
from pathlib import Path

import pytest

from server.audit import AuditLogger
from server.config import load_config
from server.vault import DuplicateEntry, GroupNotAllowed

# Skip entire module if keepassxc-cli not available
pytestmark = [pytest.mark.integration, pytest.mark.asyncio]

KEEPASSXC_CLI = shutil.which("keepassxc-cli")
if not KEEPASSXC_CLI:
    pytest.skip("keepassxc-cli not installed", allow_module_level=True)

FIXTURES_DIR = Path(__file__).parent.parent / "fixtures"
TEST_DB = FIXTURES_DIR / "test.kdbx"

if not TEST_DB.exists():
    pytest.skip("test.kdbx not found — run create_test_db.sh", allow_module_level=True)


@pytest.fixture
async def integration_setup(tmp_path):
    """Copy test db to tmp, create config, unlock PasswordVault, return test fixtures.

    Uses PasswordVault which opens a real keepassxc-cli REPL with password auth.
    The vault is properly unlocked (REPL running) so all run_cli() calls work.
    """
    import yaml

    from tests.helpers import PasswordVault

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

    vault = PasswordVault(config, password="testpassword")
    await vault.unlock()
    audit = AuditLogger(str(audit_path))

    yield vault, audit, config, db_copy

    await vault.lock()  # clean up the REPL process after each test


class TestIntegrationReadCycle:
    async def test_list_groups_returns_allowed(self, integration_setup):
        """list_groups returns only allowed groups."""
        from server.tools.read import list_groups

        vault, audit, config, db = integration_setup
        groups = await list_groups(vault)
        assert set(groups) == {"Servers", "SSH Keys", "API Keys"}


class TestIntegrationWriteCycle:
    async def test_create_then_list(self, integration_setup):
        """create_entry then list_entries confirms presence."""
        from server.tools.read import list_entries
        from server.tools.write import create_entry

        vault, audit, config, db = integration_setup
        await create_entry(
            vault, audit, title="New Test Entry", group="Servers", username="testuser",
        )
        entries = await list_entries(vault, audit, group="Servers")
        titles = [e["title"] for e in entries]
        assert "New Test Entry" in titles


class TestIntegrationRotation:
    async def test_rotation_cycle(self, integration_setup):
        """create -> deactivate -> confirm [INACTIVE] -> create same title."""
        from server.tools.read import list_entries
        from server.tools.write import create_entry, deactivate_entry

        vault, audit, config, db = integration_setup
        await create_entry(vault, audit, title="Rotate Me", group="API Keys", username="u")
        await deactivate_entry(vault, audit, title="Rotate Me", group="API Keys")
        entries = await list_entries(vault, audit, group="API Keys", include_inactive=True)
        titles = [e["title"] for e in entries]
        assert "[INACTIVE] Rotate Me" in titles
        # Should be able to create a new entry with the same title
        await create_entry(vault, audit, title="Rotate Me", group="API Keys", username="u2")


class TestIntegrationDuplicatePrevention:
    async def test_duplicate_raises(self, integration_setup):
        """create_entry twice raises DuplicateEntry on second."""
        from server.tools.write import create_entry

        vault, audit, config, db = integration_setup
        await create_entry(vault, audit, title="Unique Entry", group="SSH Keys", username="u")
        with pytest.raises(DuplicateEntry):
            await create_entry(vault, audit, title="Unique Entry", group="SSH Keys", username="u2")


class TestIntegrationInactiveFiltering:
    async def test_inactive_hidden_by_default(self, integration_setup):
        """list_entries hides [INACTIVE]; shows with flag."""
        from server.tools.read import list_entries

        vault, audit, config, db = integration_setup
        visible = await list_entries(vault, audit, group="Servers")
        visible_titles = [e["title"] for e in visible]
        assert "[INACTIVE] Old Server" not in visible_titles

        all_entries = await list_entries(vault, audit, group="Servers", include_inactive=True)
        all_titles = [e["title"] for e in all_entries]
        assert "[INACTIVE] Old Server" in all_titles


class TestIntegrationGroupAllowlist:
    async def test_disallowed_group_raises(self, integration_setup):
        """Request for unlisted group raises GroupNotAllowed."""
        from server.tools.read import list_entries

        vault, audit, config, db = integration_setup
        with pytest.raises(GroupNotAllowed):
            await list_entries(vault, audit, group="Banking")
