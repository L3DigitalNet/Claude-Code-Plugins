"""Tests for read and write tool functions."""

from unittest.mock import AsyncMock, patch

import pytest

from server.config import load_config
from server.yubikey import MockYubiKey


def _mock_async_proc(stdout: bytes = b"", stderr: bytes = b"", returncode: int = 0) -> AsyncMock:
    """Create a mock async subprocess process."""
    proc = AsyncMock()
    proc.communicate.return_value = (stdout, stderr)
    proc.returncode = returncode
    return proc


@pytest.fixture
def unlocked_vault(test_config, mock_yubikey):
    """A vault that's been unlocked (no subprocess mocking needed)."""
    from server.audit import AuditLogger
    from server.vault import Vault

    vault = Vault(test_config, mock_yubikey)
    vault._unlocked = True
    audit = AuditLogger(test_config.audit_log_path)
    return vault, audit


class TestParseShowOutput:
    """Direct tests for the _parse_show_output helper."""

    def test_empty_input(self):
        from server.tools.read import _parse_show_output
        assert _parse_show_output("") == {}

    def test_value_containing_colon(self):
        """Values with ': ' are handled correctly by partition."""
        from server.tools.read import _parse_show_output
        result = _parse_show_output("Notes: URL: https://example.com\n")
        assert result["notes"] == "URL: https://example.com"

    def test_unknown_fields_ignored(self):
        from server.tools.read import _parse_show_output
        result = _parse_show_output("CustomField: something\nTitle: My Entry\n")
        assert result == {"title": "My Entry"}

    def test_case_insensitive_keys(self):
        from server.tools.read import _parse_show_output
        result = _parse_show_output("USERNAME: admin\nPASSWORD: s3cret\n")
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"


class TestReadTools:
    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_list_groups(self, mock_exec, unlocked_vault):
        from server.tools.read import list_groups

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc(
            stdout=b"Servers/\nSSH Keys/\nAPI Keys/\nBanking/\nRecycle Bin/\n"
        )
        result = await list_groups(vault)
        # Banking and Recycle Bin should be filtered out
        assert set(result) == {"Servers", "SSH Keys", "API Keys"}

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_list_entries_filters_inactive(self, mock_exec, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(stdout=b"Web Server\n[INACTIVE] Old Server\nDB Server\n"),
            _mock_async_proc(
                stdout=b"Title: Web Server\nUserName: admin\nURL: https://web.example.com\n"
            ),
            _mock_async_proc(
                stdout=b"Title: DB Server\nUserName: dba\nURL: https://db.example.com\n"
            ),
        ]
        result = await list_entries(vault, audit, group="Servers")
        assert len(result) == 2
        titles = [e["title"] for e in result]
        assert "Web Server" in titles
        assert "[INACTIVE] Old Server" not in titles

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_list_entries_includes_inactive(self, mock_exec, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(stdout=b"Web Server\n[INACTIVE] Old Server\n"),
            _mock_async_proc(
                stdout=b"Title: Web Server\nUserName: admin\nURL: https://web.example.com\n"
            ),
            _mock_async_proc(
                stdout=b"Title: [INACTIVE] Old Server\nUserName: old\nURL: https://old.example.com\n"
            ),
        ]
        result = await list_entries(vault, audit, group="Servers", include_inactive=True)
        assert len(result) == 2

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_get_entry_returns_full_record(self, mock_exec, unlocked_vault):
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc(
            stdout=(
                b"Title: Web Server\n"
                b"UserName: admin\n"
                b"Password: s3cret\n"
                b"URL: https://web.example.com\n"
                b"Notes: Production server\n"
            )
        )
        result = await get_entry(vault, audit, title="Web Server", group="Servers")
        assert result["title"] == "Web Server"
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"
        assert result["url"] == "https://web.example.com"
        assert result["notes"] == "Production server"

    @pytest.mark.asyncio
    async def test_get_entry_raises_on_inactive(self, unlocked_vault):
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await get_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_get_entry_audits_secret(self, mock_exec, unlocked_vault, test_config):
        import json
        from pathlib import Path

        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc(
            stdout=b"Title: Web Server\nUserName: admin\nPassword: s3cret\nURL: \nNotes: \n"
        )
        await get_entry(vault, audit, title="Web Server", group="Servers")
        log_line = Path(test_config.audit_log_path).read_text().strip()
        record = json.loads(log_line)
        assert record["tool"] == "get_entry"
        assert record["secret_returned"] is True

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_search_entries(self, mock_exec, unlocked_vault):
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(
                stdout=b"Servers/Web Server\nBanking/My Bank\nAPI Keys/Anthropic\n"
            ),
            _mock_async_proc(
                stdout=b"Title: Web Server\nUserName: admin\nURL: https://web.example.com\n"
            ),
            _mock_async_proc(
                stdout=b"Title: Anthropic\nUserName: key\nURL: https://api.anthropic.com\n"
            ),
        ]
        result = await search_entries(vault, audit, query="server")
        # Banking/My Bank should be filtered out (not in allowed_groups)
        assert len(result) == 2
        groups = [e["group"] for e in result]
        assert "Banking" not in groups

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_get_attachment(self, mock_exec, unlocked_vault, test_config):
        import json
        from pathlib import Path

        from server.tools.read import get_attachment

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc(
            stdout=b"ssh-ed25519 AAAA... user@host\n"
        )
        result = await get_attachment(
            vault, audit,
            title="SSH Key", attachment_name="id_ed25519.pub", group="SSH Keys",
        )
        assert b"ssh-ed25519" in result

        # Verify audit log
        log_line = Path(test_config.audit_log_path).read_text().strip().split("\n")[-1]
        record = json.loads(log_line)
        assert record["tool"] == "get_attachment"
        assert record["secret_returned"] is True
        assert record["attachment"] == "id_ed25519.pub"

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_get_attachment_binary_content(self, mock_exec, unlocked_vault):
        """Non-UTF-8 bytes survive the run_cli_binary path."""
        from server.tools.read import get_attachment

        vault, audit = unlocked_vault
        binary_blob = b"\x00\x01\xff\xfe\x80\x90"
        mock_exec.return_value = _mock_async_proc(stdout=binary_blob)
        result = await get_attachment(
            vault, audit,
            title="Binary File", attachment_name="cert.der", group="SSH Keys",
        )
        assert result == binary_blob

    @pytest.mark.asyncio
    async def test_get_attachment_raises_on_inactive(self, unlocked_vault):
        from server.tools.read import get_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await get_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                group="SSH Keys",
            )

    @pytest.mark.asyncio
    async def test_list_entries_group_not_allowed(self, unlocked_vault):
        from server.tools.read import list_entries
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            await list_entries(vault, audit, group="Banking")

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_list_entries_group_none_iterates_all(self, mock_exec, unlocked_vault):
        """group=None iterates all allowed_groups."""
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        # 3 allowed groups: Servers, SSH Keys, API Keys
        # Each returns one entry + one show call = 6 total subprocess calls
        mock_exec.side_effect = [
            # ls Servers
            _mock_async_proc(stdout=b"Web Server\n"),
            # show Web Server
            _mock_async_proc(stdout=b"Title: Web Server\nUserName: admin\nURL: https://web\n"),
            # ls SSH Keys
            _mock_async_proc(stdout=b"My SSH Key\n"),
            # show My SSH Key
            _mock_async_proc(stdout=b"Title: My SSH Key\nUserName: user\nURL: \n"),
            # ls API Keys
            _mock_async_proc(stdout=b"Anthropic\n"),
            # show Anthropic
            _mock_async_proc(stdout=b"Title: Anthropic\nUserName: key\nURL: https://api\n"),
        ]
        result = await list_entries(vault, audit, group=None)
        assert len(result) == 3
        groups = {e["group"] for e in result}
        assert groups == {"Servers", "SSH Keys", "API Keys"}

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_list_entries_page_size_truncation(self, mock_exec, unlocked_vault, test_config):
        """Results truncated at page_size limit."""
        from pathlib import Path

        import yaml

        from server.tools.read import list_entries
        from server.vault import Vault

        vault, audit = unlocked_vault
        # Create a custom vault with page_size=2
        tmp_dir = Path(test_config.database_path).parent
        cfg = {
            "database_path": test_config.database_path,
            "yubikey_slot": 2,
            "grace_period_seconds": 2,
            "yubikey_poll_interval_seconds": 1,
            "write_lock_timeout_seconds": 2,
            "page_size": 2,
            "allowed_groups": ["Servers"],
            "audit_log_path": test_config.audit_log_path,
        }
        config_file = tmp_dir / "config_small.yaml"
        config_file.write_text(yaml.dump(cfg))
        small_config = load_config(str(config_file))
        small_vault = Vault(small_config, MockYubiKey(present=True))
        small_vault._unlocked = True
        from server.audit import AuditLogger
        small_audit = AuditLogger(small_config.audit_log_path)

        mock_exec.side_effect = [
            # ls returns 5 entries
            _mock_async_proc(stdout=b"Entry1\nEntry2\nEntry3\nEntry4\nEntry5\n"),
            # show Entry1
            _mock_async_proc(stdout=b"Title: Entry1\nUserName: u1\nURL: \n"),
            # show Entry2
            _mock_async_proc(stdout=b"Title: Entry2\nUserName: u2\nURL: \n"),
            # Entry3-5 should never be called because page_size=2
        ]
        result = await list_entries(small_vault, small_audit, group="Servers")
        assert len(result) == 2


class TestWriteTools:
    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_create_entry(self, mock_exec, unlocked_vault, test_config):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(stdout=b"Existing Entry\n"),
            _mock_async_proc(),
        ]
        await create_entry(
            vault, audit,
            title="New Server",
            group="Servers",
            username="admin",
            password="pass123",
            url="https://new.example.com",
            notes="Test notes",
        )
        add_call = mock_exec.call_args_list[-1]
        cmd_args = add_call.args
        assert "add" in cmd_args

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_create_entry_rejects_duplicate(self, mock_exec, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import DuplicateEntry

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc(stdout=b"Existing Entry\n")
        with pytest.raises(DuplicateEntry):
            await create_entry(
                vault, audit,
                title="Existing Entry",
                group="Servers",
            )

    @pytest.mark.asyncio
    async def test_create_entry_rejects_slash_in_title(self, unlocked_vault):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="slash"):
            await create_entry(
                vault, audit,
                title="Bad/Title",
                group="Servers",
            )

    @pytest.mark.asyncio
    async def test_create_entry_group_not_allowed(self, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            await create_entry(
                vault, audit,
                title="New Entry",
                group="Banking",
            )

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_deactivate_entry(self, mock_exec, unlocked_vault):
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(stdout=b"Title: Web Server\nNotes: Production server\n"),
            _mock_async_proc(),
            _mock_async_proc(),
        ]
        await deactivate_entry(vault, audit, title="Web Server", group="Servers")

        title_edit_call = mock_exec.call_args_list[1]
        cmd_str = " ".join(str(a) for a in title_edit_call.args)
        assert "[INACTIVE]" in cmd_str

    @pytest.mark.asyncio
    async def test_deactivate_already_inactive(self, unlocked_vault):
        from server.tools.write import deactivate_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await deactivate_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_deactivate_notes_failure_logs_warning(self, mock_exec, unlocked_vault):
        """Notes update failure after rename is non-fatal — entry still deactivated."""
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(stdout=b"Title: Test\nNotes: \n"),  # show
            _mock_async_proc(),  # rename succeeds
            _mock_async_proc(stdout=b"", stderr=b"error", returncode=1),  # notes fails
        ]
        # Should NOT raise — notes failure is caught
        await deactivate_entry(vault, audit, title="Test", group="Servers")

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_add_attachment(self, mock_exec, unlocked_vault):
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc()
        await add_attachment(
            vault, audit,
            title="SSH Key",
            attachment_name="id_ed25519",
            content=b"ssh-ed25519 AAAA...",
            group="SSH Keys",
        )

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_add_attachment_cleans_temp_file(self, mock_exec, unlocked_vault):
        import os
        import tempfile

        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc()

        original_ntf = tempfile.NamedTemporaryFile
        created_paths = []

        def tracking_ntf(**kwargs):
            f = original_ntf(**kwargs)
            created_paths.append(f.name)
            return f

        with patch("tempfile.NamedTemporaryFile", side_effect=tracking_ntf):
            await add_attachment(
                vault, audit,
                title="SSH Key",
                attachment_name="id_ed25519",
                content=b"ssh-ed25519 AAAA...",
                group="SSH Keys",
            )

        for path in created_paths:
            assert not os.path.exists(path), f"Temp file not cleaned up: {path}"

    @pytest.mark.asyncio
    async def test_add_attachment_inactive_rejected(self, unlocked_vault):
        from server.tools.write import add_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await add_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                content=b"key data",
                group="SSH Keys",
            )

    def test_write_lock_timeout_raises(self, unlocked_vault, test_config):
        """WriteLockTimeout when lock is held by another process."""
        from filelock import FileLock

        from server.tools.write import _write_lock
        from server.vault import WriteLockTimeout

        vault, audit = unlocked_vault
        lock_path = test_config.database_path + ".lock"
        # Acquire lock from outside to simulate contention
        blocking_lock = FileLock(lock_path, timeout=0)
        blocking_lock.acquire()
        try:
            with pytest.raises(WriteLockTimeout), _write_lock(vault):
                pass
        finally:
            blocking_lock.release()

    def test_shred_file_nonexistent(self, tmp_path):
        """_shred_file on nonexistent file does not raise."""
        from server.tools.write import _shred_file
        fake_path = str(tmp_path / "nonexistent.tmp")
        # Should not raise
        _shred_file(fake_path)

    def test_shred_file_zero_length(self, tmp_path):
        """_shred_file on zero-length file still unlinks."""
        import os

        from server.tools.write import _shred_file
        empty_file = tmp_path / "empty.tmp"
        empty_file.write_bytes(b"")
        _shred_file(str(empty_file))
        assert not os.path.exists(str(empty_file))

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_create_entry_partial_fields(self, mock_exec, unlocked_vault):
        """create_entry with only username (no password, url, notes)."""
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            # ls returns no existing entries
            _mock_async_proc(stdout=b""),
            # add succeeds
            _mock_async_proc(),
        ]
        await create_entry(vault, audit, title="New", group="Servers", username="admin")
        add_call = mock_exec.call_args_list[-1]
        cmd_args = add_call.args
        assert "--username" in cmd_args
        assert "--password" not in cmd_args
        assert "--url" not in cmd_args
        assert "--notes" not in cmd_args

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_add_attachment_with_str_content(self, mock_exec, unlocked_vault):
        """str content is encoded to UTF-8 before writing to temp file."""
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_exec.return_value = _mock_async_proc()
        # Pass string instead of bytes
        await add_attachment(
            vault, audit,
            title="SSH Key",
            attachment_name="id_ed25519.pub",
            content="ssh-ed25519 AAAA... user@host",
            group="SSH Keys",
        )

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_write_tools_produce_audit_records(self, mock_exec, unlocked_vault, test_config):
        """All 3 write tools produce audit records."""
        import json
        from pathlib import Path

        from server.tools.write import add_attachment, create_entry, deactivate_entry

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            # create_entry: ls for duplicates
            _mock_async_proc(stdout=b""),
            # create_entry: add
            _mock_async_proc(),
            # deactivate_entry: show for notes
            _mock_async_proc(stdout=b"Title: Entry2\nNotes: \n"),
            # deactivate_entry: edit title
            _mock_async_proc(),
            # deactivate_entry: edit notes
            _mock_async_proc(),
            # add_attachment: attachment-import
            _mock_async_proc(),
        ]

        await create_entry(vault, audit, title="Entry1", group="Servers", username="u")
        await deactivate_entry(vault, audit, title="Entry2", group="Servers")
        await add_attachment(
            vault, audit, title="Entry3", attachment_name="f.txt", content=b"data", group="SSH Keys"
        )

        log_lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(log_lines) == 3
        tools = [json.loads(line)["tool"] for line in log_lines]
        assert tools == ["create_entry", "deactivate_entry", "add_attachment"]


class TestSearchEntries:
    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_search_with_group_filter(self, mock_exec, unlocked_vault):
        """Explicit group filters results to only that group."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            # search returns entries from multiple groups
            _mock_async_proc(
                stdout=b"Servers/Web Server\nSSH Keys/SSH Key\nAPI Keys/Anthropic\n"
            ),
            # show Web Server (only this should be fetched for group="Servers")
            _mock_async_proc(
                stdout=b"Title: Web Server\nUserName: admin\nURL: https://web\n"
            ),
        ]
        result = await search_entries(vault, audit, query="Server", group="Servers")
        assert len(result) == 1
        assert result[0]["title"] == "Web Server"

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_search_filters_inactive_by_default(self, mock_exec, unlocked_vault):
        """Inactive entries excluded when include_inactive=False."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(
                stdout=b"Servers/Active Entry\nServers/[INACTIVE] Old Entry\n"
            ),
            # show Active Entry
            _mock_async_proc(
                stdout=b"Title: Active Entry\nUserName: u\nURL: \n"
            ),
        ]
        result = await search_entries(vault, audit, query="Entry")
        assert len(result) == 1
        assert result[0]["title"] == "Active Entry"

    @pytest.mark.asyncio
    @patch("asyncio.create_subprocess_exec")
    async def test_search_entry_without_group_prefix(self, mock_exec, unlocked_vault):
        """Entries without group prefix (no '/') get group=None."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_exec.side_effect = [
            _mock_async_proc(stdout=b"Standalone Entry\n"),
            _mock_async_proc(
                stdout=b"Title: Standalone Entry\nUserName: u\nURL: \n"
            ),
        ]
        result = await search_entries(vault, audit, query="Standalone")
        assert len(result) == 1
        assert result[0]["group"] is None
