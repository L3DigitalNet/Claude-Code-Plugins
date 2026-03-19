"""Integration tests against real test.kdbx.

Requires keepassxc-cli installed. No YubiKey needed (test db uses password only).
These tests call real keepassxc-cli commands via the PasswordVault helper.
"""

import shutil
from pathlib import Path

import pytest

from server.audit import AuditLogger
from server.config import load_config
from server.vault import DuplicateEntry

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
        "yubikey_slot": "2",
        "grace_period_seconds": 2,
        "yubikey_poll_interval_seconds": 1,
        "write_lock_timeout_seconds": 5,
        "page_size": 50,
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
        entries = await list_entries(vault, group="Servers")
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
        entries = await list_entries(vault, group="API Keys", include_inactive=True)
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
        visible = await list_entries(vault, group="Servers")
        visible_titles = [e["title"] for e in visible]
        assert "[INACTIVE] Old Server" not in visible_titles

        all_entries = await list_entries(vault, group="Servers", include_inactive=True)
        all_titles = [e["title"] for e in all_entries]
        assert "[INACTIVE] Old Server" in all_titles


class TestIntegrationGroupAccess:
    async def test_any_group_accessible(self, integration_setup):
        """Any vault group is now accessible — no allowlist restriction."""
        from server.tools.read import list_entries

        vault, audit, config, db = integration_setup
        # "Servers" group exists in test.kdbx — no GroupNotAllowed exception
        result = await list_entries(vault, group="Servers")
        titles = [e["title"] for e in result]
        assert any("Server" in t or "DB" in t for t in titles)


class TestIntegrationGetEntry:
    async def test_get_entry_returns_password(self, integration_setup):
        """get_entry returns full record including password via real keepassxc-cli."""
        from server.tools.read import get_entry

        vault, audit, config, db = integration_setup
        # test.kdbx has pre-seeded entries in Servers group
        groups = await vault.run_cli("ls", str(db))
        group_names = [line.rstrip("/") for line in groups.strip().splitlines() if line.endswith("/")]
        assert len(group_names) > 0

        # List entries in first group and get one
        from server.tools.read import list_entries
        entries = await list_entries(vault, group=group_names[0])
        if entries:
            entry = await get_entry(vault, audit, title=entries[0]["title"], group=group_names[0])
            assert "title" in entry
            assert "password" in entry
            assert "username" in entry


class TestIntegrationSearch:
    async def test_search_entries_finds_existing(self, integration_setup):
        """search_entries finds entries by keyword via real keepassxc-cli."""
        from server.tools.read import search_entries

        vault, audit, config, db = integration_setup
        # "Server" should match entries in the Servers group
        results = await search_entries(vault, query="Server")
        assert len(results) > 0
        assert any("Server" in r.get("title", "") or "server" in r.get("title", "").lower()
                    for r in results)


class TestIntegrationGetAttachment:
    async def test_get_attachment_binary(self, integration_setup):
        """get_attachment returns binary data for an existing attachment."""
        from server.tools.read import get_attachment, list_entries
        from server.vault import KeePassCLIError

        vault, audit, config, db = integration_setup
        # Create an entry with an attachment first, then retrieve it
        from server.tools.write import create_entry, add_attachment

        await create_entry(vault, audit, title="Attach Test", group="SSH Keys", username="u")
        test_content = b"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 test@host"
        await add_attachment(
            vault, audit, title="Attach Test", attachment_name="test_key.pub",
            content=test_content, group="SSH Keys",
        )
        result = await get_attachment(
            vault, audit, title="Attach Test",
            attachment_name="test_key.pub", group="SSH Keys",
        )
        assert result == test_content


class TestIntegrationAddAttachment:
    async def test_add_attachment_roundtrip(self, integration_setup):
        """add_attachment stores a file that can be retrieved."""
        from server.tools.write import add_attachment, create_entry
        from server.tools.read import get_attachment

        vault, audit, config, db = integration_setup
        await create_entry(vault, audit, title="File Store", group="API Keys", username="u")
        content = b"api_key=abc123\nsecret=xyz789"
        await add_attachment(
            vault, audit, title="File Store", attachment_name="creds.env",
            content=content, group="API Keys",
        )
        result = await get_attachment(
            vault, audit, title="File Store",
            attachment_name="creds.env", group="API Keys",
        )
        assert result == content


class TestIntegrationImport:
    async def test_import_creates_entries(self, integration_setup):
        """import_entries creates entries that appear in list_entries after re-unlock.

        import_entries runs keepassxc-cli merge as a direct subprocess with
        --yubikey auth. This test patches subprocess.run to adapt the merge
        command for password auth (matching the PasswordVault test database).
        """
        import subprocess as _subprocess
        from unittest.mock import patch as _patch

        from server.tools.read import list_entries
        from server.tools.write import import_entries

        vault, audit, config, db = integration_setup
        db_password = "testpassword"
        real_run = _subprocess.run

        def merge_with_password(cmd, *args, **kwargs):
            """Adapt keepassxc-cli merge from YubiKey to password auth."""
            if isinstance(cmd, list) and len(cmd) > 1 and cmd[1] == "merge":
                new_cmd = []
                skip_next = False
                for c in cmd:
                    if skip_next:
                        skip_next = False
                        continue
                    if c == "--yubikey":
                        skip_next = True
                        continue
                    if c == "--no-password":
                        continue
                    new_cmd.append(c)
                existing_input = kwargs.get("input", "")
                kwargs["input"] = db_password + "\n" + existing_input
                return real_run(new_cmd, *args, **kwargs)
            return real_run(cmd, *args, **kwargs)

        with _patch("subprocess.run", side_effect=merge_with_password):
            result = await import_entries(vault, audit, entries=[
                {"group": "Servers", "title": "Imported-1", "username": "import_user"},
                {"group": "Servers", "title": "Imported-2", "username": "import_user2"},
            ])
        assert "Imported 2" in result

        # Vault is locked after import — re-unlock and verify entries exist.
        # keepassxc-cli merge creates entries under a parallel group (UUID
        # mismatch), so search vault-wide instead of listing a specific group.
        await vault.unlock()
        from server.tools.read import search_entries
        found = await search_entries(vault, query="Imported")
        found_titles = [e["title"] for e in found]
        assert "Imported-1" in found_titles
        assert "Imported-2" in found_titles
