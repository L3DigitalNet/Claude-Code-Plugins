"""Tests for read and write tool functions."""

import subprocess
from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from server.config import load_config
from server.yubikey import MockYubiKey
from tests.helpers import _mock_async_proc, _mock_repl_proc, _repl_resp

pytestmark = pytest.mark.unit


# ---------------------------------------------------------------------------
# unlocked_vault fixture — wires a mock REPL proc so run_cli() works
# ---------------------------------------------------------------------------

@pytest.fixture
def unlocked_vault(test_config, mock_yubikey):
    """An unlocked Vault with a mock REPL proc.

    Tests configure vault._repl_proc.stdout.readuntil.side_effect = [...]
    for their specific response sequences. The mock proc starts with a single
    default empty response; tests with multiple run_cli() calls must set
    side_effect before the test body executes.
    """
    from server.audit import AuditLogger
    from server.vault import Vault

    vault = Vault(test_config, mock_yubikey)
    vault._unlocked = True
    vault._repl_proc = _mock_repl_proc()  # default: empty response for any call
    audit = AuditLogger(test_config.audit_log_path)
    return vault, audit


# ---------------------------------------------------------------------------
# _parse_show_output
# ---------------------------------------------------------------------------

class TestParseShowOutput:
    def test_empty_input(self):
        from server.tools.read import _parse_show_output
        assert _parse_show_output("") == {}

    def test_value_containing_colon(self):
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

    def test_multiline_notes(self):
        from server.tools.read import _parse_show_output
        output = (
            "Title: Web Server\n"
            "UserName: admin\n"
            "Password: s3cret\n"
            "URL: https://example.com\n"
            "Notes: Line one\n"
            "Line two\n"
            "Line three\n"
        )
        result = _parse_show_output(output)
        assert result["notes"] == "Line one\nLine two\nLine three"

    def test_multiline_notes_followed_by_field(self):
        """Notes continuation stops when another known field appears."""
        from server.tools.read import _parse_show_output
        output = (
            "Title: Entry\n"
            "Notes: First line\n"
            "Second line\n"
            "Tags: some-tag\n"
        )
        result = _parse_show_output(output)
        assert result["notes"] == "First line\nSecond line"

    def test_single_line_notes_unchanged(self):
        """Existing single-line notes behavior preserved."""
        from server.tools.read import _parse_show_output
        output = "Title: Entry\nNotes: Single line\nUserName: admin\n"
        result = _parse_show_output(output)
        assert result["notes"] == "Single line"


# ---------------------------------------------------------------------------
# _parse_tags
# ---------------------------------------------------------------------------

class TestParseTags:
    def test_tags_parsed(self):
        from server.tools.read import _parse_tags
        result = _parse_tags("Title: Entry\nTags: AI RESTRICTED;READ ONLY\n")
        assert result == {"ai restricted", "read only"}

    def test_empty_tags_value(self):
        from server.tools.read import _parse_tags
        result = _parse_tags("Title: Entry\nTags: \n")
        assert result == set()

    def test_no_tags_line(self):
        from server.tools.read import _parse_tags
        result = _parse_tags("Title: Entry\nUserName: admin\n")
        assert result == set()


# ---------------------------------------------------------------------------
# Read tools
# ---------------------------------------------------------------------------

class TestReadTools:

    async def test_list_groups(self, unlocked_vault):
        """list_groups returns all groups with no filtering."""
        from server.tools.read import list_groups

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Servers/\nSSH Keys/\nAPI Keys/\nBanking/\nRecycle Bin/\n"),
        ]
        result = await list_groups(vault)
        assert set(result) == {"Servers", "SSH Keys", "API Keys", "Banking", "Recycle Bin"}


    async def test_list_entries_filters_inactive(self, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Web Server\n[INACTIVE] Old Server\nDB Server\n"),
            _repl_resp(b"Title: Web Server\nUserName: admin\nURL: https://web.example.com\n"),
            _repl_resp(b"Title: DB Server\nUserName: dba\nURL: https://db.example.com\n"),
        ]
        result = await list_entries(vault, group="Servers")
        assert len(result) == 2
        titles = [e["title"] for e in result]
        assert "Web Server" in titles
        assert "[INACTIVE] Old Server" not in titles


    async def test_list_entries_includes_inactive(self, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Web Server\n[INACTIVE] Old Server\n"),
            _repl_resp(b"Title: Web Server\nUserName: admin\nURL: https://web.example.com\n"),
            _repl_resp(b"Title: [INACTIVE] Old Server\nUserName: old\nURL: https://old.example.com\n"),
        ]
        result = await list_entries(vault, group="Servers", include_inactive=True)
        assert len(result) == 2


    async def test_get_entry_returns_full_record(self, unlocked_vault):
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(
                b"Title: Web Server\n"
                b"UserName: admin\n"
                b"Password: s3cret\n"
                b"URL: https://web.example.com\n"
                b"Notes: Production server\n"
            )
        ]
        result = await get_entry(vault, audit, title="Web Server", group="Servers")
        assert result["title"] == "Web Server"
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"
        assert result["url"] == "https://web.example.com"
        assert result["notes"] == "Production server"


    async def test_get_entry_raises_on_inactive(self, unlocked_vault):
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await get_entry(vault, audit, title="[INACTIVE] Old Server", group="Servers")

    async def test_get_entry_allows_inactive_when_flag_set(self, unlocked_vault):
        """get_entry with allow_inactive=True returns the entry without raising."""
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(
                b"Title: [INACTIVE] Old Server\n"
                b"UserName: admin\n"
                b"Password: oldpass\n"
                b"URL: https://old.example.com\n"
                b"Notes: Some notes\n[DEACTIVATED: 2026-03-01T00:00:00+00:00]\n"
            )
        ]
        result = await get_entry(
            vault, audit,
            title="[INACTIVE] Old Server", group="Servers",
            allow_inactive=True,
        )
        assert result["title"] == "[INACTIVE] Old Server"
        assert result["password"] == "oldpass"
        assert "DEACTIVATED" in result["notes"]

    async def test_get_entry_still_blocks_inactive_by_default(self, unlocked_vault):
        """Default behavior unchanged — inactive entries raise EntryInactive."""
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await get_entry(vault, audit, title="[INACTIVE] Old Server", group="Servers")


    async def test_get_entry_audits_secret(self, unlocked_vault, test_config):
        import json
        from pathlib import Path

        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Web Server\nUserName: admin\nPassword: s3cret\nURL: \nNotes: \n")
        ]
        await get_entry(vault, audit, title="Web Server", group="Servers")
        log_line = Path(test_config.audit_log_path).read_text().strip()
        record = json.loads(log_line)
        assert record["tool"] == "get_entry"
        assert record["secret_returned"] is True


    async def test_search_entries(self, unlocked_vault):
        """search_entries returns results from all groups vault-wide."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Servers/Web Server\nBanking/My Bank\nAPI Keys/Anthropic\n"),
            _repl_resp(b"Title: Web Server\nUserName: admin\nURL: https://web.example.com\n"),
            _repl_resp(b"Title: My Bank\nUserName: user\nURL: https://bank.example.com\n"),
            _repl_resp(b"Title: Anthropic\nUserName: key\nURL: https://api.anthropic.com\n"),
        ]
        result = await search_entries(vault, query="server")
        assert len(result) == 3
        groups = [e["group"] for e in result]
        assert "Banking" in groups


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

        log_line = Path(test_config.audit_log_path).read_text().strip().split("\n")[-1]
        record = json.loads(log_line)
        assert record["tool"] == "get_attachment"
        assert record["secret_returned"] is True
        assert record["attachment"] == "id_ed25519.pub"


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


    async def test_get_attachment_raises_on_inactive(self, unlocked_vault):
        from server.tools.read import get_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await get_attachment(
                vault, audit,
                title="[INACTIVE] Old Key", attachment_name="id_rsa", group="SSH Keys",
            )


    async def test_list_entries_any_group_accessible(self, unlocked_vault):
        """Any group is accessible — no allowlist restriction."""
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Checking Account\nSavings\n"),
            _repl_resp(b"Title: Checking Account\nUserName: user\nURL: \n"),
            _repl_resp(b"Title: Savings\nUserName: user\nURL: \n"),
        ]
        result = await list_entries(vault, group="Banking")
        assert len(result) == 2
        assert all(e["group"] == "Banking" for e in result)


    async def test_list_entries_group_none_iterates_all(self, unlocked_vault):
        """group=None iterates all vault groups, not just an allowlist."""
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        # list_groups (1 ls) + 3 groups × (1 ls + 1 show) = 7 readuntil calls
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Servers/\nSSH Keys/\nAPI Keys/\n"),  # list_groups
            _repl_resp(b"Web Server\n"),
            _repl_resp(b"Title: Web Server\nUserName: admin\nURL: https://web\n"),
            _repl_resp(b"My SSH Key\n"),
            _repl_resp(b"Title: My SSH Key\nUserName: user\nURL: \n"),
            _repl_resp(b"Anthropic\n"),
            _repl_resp(b"Title: Anthropic\nUserName: key\nURL: https://api\n"),
        ]
        result = await list_entries(vault, group=None)
        assert len(result) == 3
        groups = {e["group"] for e in result}
        assert groups == {"Servers", "SSH Keys", "API Keys"}


    async def test_list_entries_page_size_truncation(self, unlocked_vault, test_config):
        """Results truncated at page_size limit."""
        import yaml
        from pathlib import Path

        from server.tools.read import list_entries
        from server.vault import Vault

        vault, audit = unlocked_vault
        tmp_dir = Path(test_config.database_path).parent
        cfg = {
            "database_path": test_config.database_path,
            "yubikey_slot": 2,
            "grace_period_seconds": 2,
            "yubikey_poll_interval_seconds": 1,
            "write_lock_timeout_seconds": 2,
            "page_size": 2,
            "audit_log_path": test_config.audit_log_path,
        }
        config_file = tmp_dir / "config_small.yaml"
        config_file.write_text(yaml.dump(cfg))
        small_config = load_config(str(config_file))
        from server.audit import AuditLogger
        small_vault = Vault(small_config, MockYubiKey(present=True))
        small_vault._unlocked = True
        # 5 entries returned, but page_size=2 stops after 2 show calls
        small_vault._repl_proc = _mock_repl_proc([
            _repl_resp(b"Entry1\nEntry2\nEntry3\nEntry4\nEntry5\n"),
            _repl_resp(b"Title: Entry1\nUserName: u1\nURL: \n"),
            _repl_resp(b"Title: Entry2\nUserName: u2\nURL: \n"),
        ])
        small_audit = AuditLogger(small_config.audit_log_path)

        result = await list_entries(small_vault, group="Servers")
        assert len(result) == 2


# ---------------------------------------------------------------------------
# Write tools
# ---------------------------------------------------------------------------

class TestWriteTools:

    async def test_create_entry(self, unlocked_vault):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Existing Entry\n"),  # ls: existing entries
            _repl_resp(b""),                  # add: success (no stdout output)
        ]
        await create_entry(
            vault, audit,
            title="New Server", group="Servers",
            username="admin", password="pass123",
            url="https://new.example.com", notes="Test notes",
        )
        # Verify the add command was written to REPL stdin
        write_calls = vault._repl_proc.stdin.write.call_args_list
        assert any(b"add" in c[0][0] for c in write_calls)


    async def test_create_entry_rejects_duplicate(self, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import DuplicateEntry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Existing Entry\n"),  # ls
        ]
        with pytest.raises(DuplicateEntry):
            await create_entry(vault, audit, title="Existing Entry", group="Servers")


    async def test_create_entry_rejects_slash_in_title(self, unlocked_vault):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="slash"):
            await create_entry(vault, audit, title="Bad/Title", group="Servers")


    async def test_create_entry_any_group_accessible(self, unlocked_vault):
        """create_entry accepts any group — no allowlist restriction."""
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b""),  # ls: empty group
            _repl_resp(b""),  # add: success
        ]
        await create_entry(vault, audit, title="New Entry", group="Banking")


    async def test_deactivate_entry(self, unlocked_vault):
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Web Server\nNotes: Production server\n"),  # show
            _repl_resp(b""),  # edit --title
            _repl_resp(b""),  # edit --notes
        ]
        await deactivate_entry(vault, audit, title="Web Server", group="Servers")

        # Verify [INACTIVE] prefix appears in the rename command
        write_calls = vault._repl_proc.stdin.write.call_args_list
        rename_cmd = write_calls[1][0][0]  # second write is edit --title
        assert b"[INACTIVE]" in rename_cmd


    async def test_deactivate_already_inactive(self, unlocked_vault):
        from server.tools.write import deactivate_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await deactivate_entry(vault, audit, title="[INACTIVE] Old Server", group="Servers")


    async def test_deactivate_notes_failure_logs_warning(self, unlocked_vault):
        """Notes update failure after rename is non-fatal."""
        from server.vault import KeePassCLIError
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Test\nNotes: \n"),           # show
            _repl_resp(b""),                                  # rename succeeds
            _repl_resp(b"Error: failed to update notes\n"),  # notes fails
        ]
        # Should not raise — notes failure is non-fatal
        await deactivate_entry(vault, audit, title="Test", group="Servers")


    async def test_add_attachment(self, unlocked_vault):
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: SSH Key\nUserName: root\nNotes: \n"),  # show (tag check)
            _repl_resp(b""),  # attachment-import success
        ]
        await add_attachment(
            vault, audit,
            title="SSH Key", attachment_name="id_ed25519",
            content=b"ssh-ed25519 AAAA...", group="SSH Keys",
        )


    async def test_add_attachment_cleans_temp_file(self, unlocked_vault):
        import os
        import tempfile

        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: SSH Key\nUserName: root\nNotes: \n"),  # show (tag check)
            _repl_resp(b""),  # attachment-import success
        ]

        original_ntf = tempfile.NamedTemporaryFile
        created_paths = []

        def tracking_ntf(**kwargs):
            f = original_ntf(**kwargs)
            created_paths.append(f.name)
            return f

        with patch("tempfile.NamedTemporaryFile", side_effect=tracking_ntf):
            await add_attachment(
                vault, audit,
                title="SSH Key", attachment_name="id_ed25519",
                content=b"ssh-ed25519 AAAA...", group="SSH Keys",
            )

        for path in created_paths:
            assert not os.path.exists(path), f"Temp file not cleaned up: {path}"


    async def test_add_attachment_inactive_rejected(self, unlocked_vault):
        from server.tools.write import add_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            await add_attachment(
                vault, audit,
                title="[INACTIVE] Old Key", attachment_name="id_rsa",
                content=b"key data", group="SSH Keys",
            )

    def test_write_lock_timeout_raises(self, unlocked_vault, test_config):
        """WriteLockTimeout when lock is held by another process."""
        from filelock import FileLock

        from server.tools.write import _write_lock
        from server.vault import WriteLockTimeout

        vault, audit = unlocked_vault
        lock_path = test_config.database_path + ".lock"
        blocking_lock = FileLock(lock_path, timeout=0)
        blocking_lock.acquire()
        try:
            with pytest.raises(WriteLockTimeout), _write_lock(vault):
                pass
        finally:
            blocking_lock.release()

    def test_shred_file_nonexistent(self, tmp_path):
        from server.tools.write import _shred_file
        fake_path = str(tmp_path / "nonexistent.tmp")
        _shred_file(fake_path)  # Should not raise

    def test_shred_file_zero_length(self, tmp_path):
        import os

        from server.tools.write import _shred_file
        empty_file = tmp_path / "empty.tmp"
        empty_file.write_bytes(b"")
        _shred_file(str(empty_file))
        assert not os.path.exists(str(empty_file))


    async def test_create_entry_partial_fields(self, unlocked_vault):
        """create_entry with only username omits -p/--url/--notes."""
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b""),  # ls: no existing entries
            _repl_resp(b""),  # add success
        ]
        await create_entry(vault, audit, title="New", group="Servers", username="admin")
        write_calls = vault._repl_proc.stdin.write.call_args_list
        add_cmd = write_calls[1][0][0]
        assert b"--username" in add_cmd
        assert b"-p" not in add_cmd  # no password prompt flag when password omitted
        assert b"--url" not in add_cmd
        assert b"--notes" not in add_cmd


    async def test_create_entry_empty_string_username_passed(self, unlocked_vault):
        """Empty string username is passed to CLI, not silently dropped."""
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b""),  # ls: no existing entries
            _repl_resp(b""),  # add success
        ]
        await create_entry(vault, audit, title="New", group="Servers", username="")
        write_calls = vault._repl_proc.stdin.write.call_args_list
        add_cmd = write_calls[1][0][0]
        assert b"--username" in add_cmd

    async def test_create_entry_with_password_uses_stdin_lines(self, unlocked_vault):
        """create_entry with password uses -p flag and writes password to stdin.

        keepassxc-cli add has no --password flag; -p prompts stdin. We pre-write
        the password to stdin before readuntil() to avoid deadlock.
        """
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b""),  # ls: no existing entries
            _repl_resp(b""),  # add success
        ]
        written_calls = []
        vault._repl_proc.stdin.write = lambda data: written_calls.append(data)

        await create_entry(
            vault, audit, title="Secure", group="Servers",
            username="admin", password="s3cr3t",
        )

        # write_calls: [0]=ls cmd, [1]=add cmd, [2]=password line
        add_cmd = written_calls[1]
        assert b"-p" in add_cmd           # uses password-prompt flag
        assert b"--password" not in add_cmd  # never the non-existent --password flag
        assert written_calls[2] == b"s3cr3t\n"  # password written to stdin


    async def test_add_attachment_with_str_content(self, unlocked_vault):
        """str content is encoded to UTF-8 before writing to temp file."""
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: SSH Key\nUserName: root\nNotes: \n"),  # show (tag check)
            _repl_resp(b""),  # attachment-import success
        ]
        await add_attachment(
            vault, audit,
            title="SSH Key", attachment_name="id_ed25519.pub",
            content="ssh-ed25519 AAAA... user@host", group="SSH Keys",
        )


    async def test_write_tools_produce_audit_records(self, unlocked_vault, test_config):
        """All 3 original write tools produce audit records."""
        import json
        from pathlib import Path

        from server.tools.write import add_attachment, create_entry, deactivate_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b""),                                   # create: ls (empty)
            _repl_resp(b""),                                   # create: add
            _repl_resp(b"Title: Entry2\nNotes: \n"),          # deactivate: show
            _repl_resp(b""),                                   # deactivate: edit title
            _repl_resp(b""),                                   # deactivate: edit notes
            _repl_resp(b"Title: Entry3\nNotes: \n"),          # attachment: show (tag check)
            _repl_resp(b""),                                   # attachment-import
        ]
        await create_entry(vault, audit, title="Entry1", group="Servers", username="u")
        await deactivate_entry(vault, audit, title="Entry2", group="Servers")
        await add_attachment(
            vault, audit, title="Entry3", attachment_name="f.txt",
            content=b"data", group="SSH Keys",
        )

        log_lines = Path(test_config.audit_log_path).read_text().strip().split("\n")
        assert len(log_lines) == 3
        tools = [json.loads(line)["tool"] for line in log_lines]
        assert tools == ["create_entry", "deactivate_entry", "add_attachment"]


# ---------------------------------------------------------------------------
# Search entries
# ---------------------------------------------------------------------------

class TestSearchEntries:

    async def test_search_with_group_filter(self, unlocked_vault):
        """Explicit group filters results to only that group."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Servers/Web Server\nSSH Keys/SSH Key\nAPI Keys/Anthropic\n"),
            _repl_resp(b"Title: Web Server\nUserName: admin\nURL: https://web\n"),
        ]
        result = await search_entries(vault, query="Server", group="Servers")
        assert len(result) == 1
        assert result[0]["title"] == "Web Server"


    async def test_search_filters_inactive_by_default(self, unlocked_vault):
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Servers/Active Entry\nServers/[INACTIVE] Old Entry\n"),
            _repl_resp(b"Title: Active Entry\nUserName: u\nURL: \n"),
        ]
        result = await search_entries(vault, query="Entry")
        assert len(result) == 1
        assert result[0]["title"] == "Active Entry"


    async def test_search_entry_without_group_prefix(self, unlocked_vault):
        """Entries without group prefix get group=None."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Standalone Entry\n"),
            _repl_resp(b"Title: Standalone Entry\nUserName: u\nURL: \n"),
        ]
        result = await search_entries(vault, query="Standalone")
        assert len(result) == 1
        assert result[0]["group"] is None

    async def test_search_multilevel_path(self, unlocked_vault):
        """rsplit handles multi-level paths: 'SSH Keys/Personal/SSH - laptop'."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"SSH Keys/Personal/SSH - laptop\n"),
            _repl_resp(b"Title: SSH - laptop\nUserName: chris\nURL: \n"),
        ]
        result = await search_entries(vault, query="laptop")
        assert len(result) == 1
        assert result[0]["title"] == "SSH - laptop"
        assert result[0]["group"] == "SSH Keys/Personal"


# ---------------------------------------------------------------------------
# import_entries
# ---------------------------------------------------------------------------

class TestSearchEntriesTruncation:

    async def test_search_truncates_at_page_size(self, unlocked_vault):
        """search_entries stops after page_size results and logs a warning."""
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        # page_size is 50 in test_config; mock 51 search results (entries without groups)
        paths = "\n".join(f"Entry{i}" for i in range(51))
        show_responses = [_repl_resp(f"Title: Entry{i}\nUserName: u\nURL: \n".encode()) for i in range(51)]
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(paths.encode()),
            *show_responses,
        ]
        result = await search_entries(vault, query="Entry")
        assert len(result) == 50


class TestImportEntries:
    def _make_subprocess_result(self, returncode: int = 0, stderr: str = "") -> MagicMock:
        result = MagicMock()
        result.returncode = returncode
        result.stderr = stderr
        result.stdout = ""
        return result


    async def test_empty_list_returns_message(self, unlocked_vault):
        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        result = await import_entries(vault, audit, entries=[])
        assert result == "No entries provided"


    async def test_missing_group_raises(self, unlocked_vault):
        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="'group'"):
            await import_entries(vault, audit, entries=[{"title": "X"}])


    async def test_missing_title_raises(self, unlocked_vault):
        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="'title'"):
            await import_entries(vault, audit, entries=[{"group": "Servers"}])


    async def test_slash_in_title_raises(self, unlocked_vault):
        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="slash"):
            await import_entries(
                vault, audit,
                entries=[{"group": "Servers", "title": "Bad/Title"}],
            )


    @patch("subprocess.run")
    async def test_any_group_importable(self, mock_run, unlocked_vault):
        """import_entries accepts any group — no allowlist restriction."""
        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            self._make_subprocess_result(0),  # keepassxc-cli import
            self._make_subprocess_result(0),  # keepassxc-cli merge
        ]
        result = await import_entries(
            vault, audit,
            entries=[{"group": "Banking", "title": "Entry"}],
        )
        assert "Imported 1" in result
        assert "Banking" in result


    @patch("subprocess.run")
    async def test_success_locks_vault_and_returns_summary(
        self, mock_run, unlocked_vault
    ):
        """import_entries: vault is locked after merge; return summary is correct."""
        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            self._make_subprocess_result(0),  # keepassxc-cli import
            self._make_subprocess_result(0),  # keepassxc-cli merge
        ]
        entries = [
            {"group": "Servers", "title": "Server1", "username": "u1"},
            {"group": "Servers", "title": "Server2"},
            {"group": "SSH Keys", "title": "Key1", "password": "p"},
        ]
        result = await import_entries(vault, audit, entries=entries)

        assert "3" in result or "Imported 3" in result
        assert "Servers" in result
        assert vault.is_unlocked is False  # vault locked by import_entries


    @patch("subprocess.run")
    async def test_cli_import_error_raises(self, mock_run, unlocked_vault):
        """KeePassCLIError when keepassxc-cli import fails."""
        from server.tools.write import import_entries
        from server.vault import KeePassCLIError

        vault, audit = unlocked_vault
        mock_run.return_value = self._make_subprocess_result(
            returncode=1, stderr="Error: bad xml"
        )
        with pytest.raises(KeePassCLIError, match="import failed"):
            await import_entries(
                vault, audit, entries=[{"group": "Servers", "title": "X"}]
            )


    @patch("subprocess.run")
    async def test_temp_files_shredded_on_success(self, mock_run, unlocked_vault, tmp_path):
        """Both tmp_xml and tmp_db are unlinked after successful import."""
        import os
        import tempfile

        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            self._make_subprocess_result(0),
            self._make_subprocess_result(0),
        ]

        created_files = []
        created_dirs = []
        real_mkstemp = tempfile.mkstemp
        real_mkdtemp = tempfile.mkdtemp

        def tracking_mkstemp(**kwargs):
            fd, path = real_mkstemp(**kwargs)
            created_files.append(path)
            return fd, path

        def tracking_mkdtemp(**kwargs):
            path = real_mkdtemp(**kwargs)
            created_dirs.append(path)
            return path

        with (
            patch("tempfile.mkstemp", side_effect=tracking_mkstemp),
            patch("tempfile.mkdtemp", side_effect=tracking_mkdtemp),
        ):
            await import_entries(
                vault, audit, entries=[{"group": "Servers", "title": "T"}]
            )

        for path in created_files:
            assert not os.path.exists(path), f"Temp file not cleaned: {path}"
        for path in created_dirs:
            assert not os.path.exists(path), f"Temp dir not cleaned: {path}"


    @patch("subprocess.run")
    async def test_cli_merge_error_raises(self, mock_run, unlocked_vault):
        """KeePassCLIError when keepassxc-cli merge fails."""
        from server.tools.write import import_entries
        from server.vault import KeePassCLIError

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            self._make_subprocess_result(0),            # import succeeds
            self._make_subprocess_result(1, "Error: conflict"),  # merge fails
        ]
        with pytest.raises(KeePassCLIError, match="merge failed"):
            await import_entries(
                vault, audit, entries=[{"group": "Servers", "title": "X"}]
            )


    @patch("subprocess.run")
    async def test_audit_record_written(self, mock_run, unlocked_vault, test_config):
        """import_entries writes an audit record with tool=import_entries."""
        import json
        from pathlib import Path

        from server.tools.write import import_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            self._make_subprocess_result(0),
            self._make_subprocess_result(0),
        ]
        await import_entries(
            vault, audit,
            entries=[
                {"group": "Servers", "title": "A"},
                {"group": "API Keys", "title": "B"},
            ],
        )
        log_line = Path(test_config.audit_log_path).read_text().strip().split("\n")[-1]
        record = json.loads(log_line)
        assert record["tool"] == "import_entries"
        assert record["total"] == 2


# ---------------------------------------------------------------------------
# XML builder (pure functions)
# ---------------------------------------------------------------------------

class TestBuildImportXml:
    def test_valid_xml_structure(self):
        """_build_import_xml produces well-formed KeePassXC-compatible XML."""
        import xml.etree.ElementTree as ET

        from server.tools.write import _build_import_xml

        xml_str = _build_import_xml(
            {
                "Servers": [
                    {"title": "s1", "username": "u", "password": "p", "url": "", "notes": ""},
                ]
            }
        )
        root = ET.fromstring(xml_str)
        assert root.tag == "KeePassFile"
        meta = root.find("Meta")
        assert meta is not None
        assert meta.findtext("Generator") == "KeePassXC"
        # Root group should contain one child group (Servers)
        root_group = root.find("Root/Group")
        assert root_group is not None
        child_groups = root_group.findall("Group")
        assert len(child_groups) == 1
        assert child_groups[0].findtext("Name") == "Servers"

    def test_password_protected_in_memory(self):
        """Password Value element has ProtectInMemory='True'."""
        import xml.etree.ElementTree as ET

        from server.tools.write import _build_import_xml

        xml_str = _build_import_xml(
            {"API Keys": [{"title": "key", "password": "secret"}]}
        )
        root = ET.fromstring(xml_str)
        # Find all String/Value elements where the sibling Key == "Password"
        for entry in root.iter("Entry"):
            for string_el in entry.findall("String"):
                if string_el.findtext("Key") == "Password":
                    value_el = string_el.find("Value")
                    assert value_el is not None
                    assert value_el.get("ProtectInMemory") == "True"

    def test_multiple_groups(self):
        """Multiple groups produce multiple child Group elements."""
        import xml.etree.ElementTree as ET

        from server.tools.write import _build_import_xml

        xml_str = _build_import_xml(
            {
                "Servers": [{"title": "s1"}],
                "API Keys": [{"title": "a1"}, {"title": "a2"}],
            }
        )
        root = ET.fromstring(xml_str)
        root_group = root.find("Root/Group")
        assert root_group is not None
        names = {g.findtext("Name") for g in root_group.findall("Group")}
        assert names == {"Servers", "API Keys"}


# ---------------------------------------------------------------------------
# AI RESTRICTED enforcement
# ---------------------------------------------------------------------------

class TestAiRestrictedEnforcement:

    async def test_get_entry_raises_on_restricted(self, unlocked_vault):
        from server.tools.read import get_entry
        from server.vault import EntryRestricted

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Secret Project\nTags: AI RESTRICTED\n"),
        ]
        with pytest.raises(EntryRestricted):
            await get_entry(vault, audit, title="Secret Project", group="API Keys")

    @patch("asyncio.create_subprocess_exec")
    async def test_get_attachment_raises_on_restricted(self, mock_exec, unlocked_vault):
        from server.tools.read import get_attachment
        from server.vault import EntryRestricted

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Secret Project\nTags: AI RESTRICTED\n"),
        ]
        with pytest.raises(EntryRestricted):
            await get_attachment(
                vault, audit,
                title="Secret Project", attachment_name="key.pem", group="API Keys",
            )

    async def test_search_entries_excludes_restricted(self, unlocked_vault):
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"API Keys/Anthropic\nAPI Keys/Secret Project\n"),
            _repl_resp(b"Title: Anthropic\nUserName: key\nURL: https://api.anthropic.com\n"),
            _repl_resp(b"Title: Secret Project\nTags: AI RESTRICTED\n"),
        ]
        result = await search_entries(vault, query="api")
        assert len(result) == 1
        assert result[0]["title"] == "Anthropic"

    async def test_list_entries_excludes_restricted(self, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Anthropic API - main\nSecret Project\n"),
            _repl_resp(b"Title: Anthropic API - main\nUserName: key\nURL: \n"),
            _repl_resp(b"Title: Secret Project\nTags: AI RESTRICTED\n"),
        ]
        result = await list_entries(vault, group="API Keys")
        assert len(result) == 1
        assert result[0]["title"] == "Anthropic API - main"


# ---------------------------------------------------------------------------
# READ ONLY enforcement
# ---------------------------------------------------------------------------

class TestReadOnlyEnforcement:

    async def test_deactivate_entry_raises_on_read_only(self, unlocked_vault):
        from server.tools.write import deactivate_entry
        from server.vault import EntryReadOnly

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Production DB\nNotes: \nTags: READ ONLY\n"),
        ]
        with pytest.raises(EntryReadOnly):
            await deactivate_entry(vault, audit, title="Production DB", group="Servers")

    async def test_add_attachment_raises_on_read_only(self, unlocked_vault):
        from server.tools.write import add_attachment
        from server.vault import EntryReadOnly

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(b"Title: Production DB\nNotes: \nTags: READ ONLY\n"),
        ]
        with pytest.raises(EntryReadOnly):
            await add_attachment(
                vault, audit,
                title="Production DB", attachment_name="backup.sql",
                content=b"data", group="Servers",
            )

    async def test_get_entry_succeeds_on_read_only(self, unlocked_vault):
        """READ ONLY tag blocks writes but allows reads."""
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        vault._repl_proc.stdout.readuntil.side_effect = [
            _repl_resp(
                b"Title: Production DB\nUserName: dba\nPassword: prodpass\n"
                b"URL: https://prod.example.com\nNotes: \nTags: READ ONLY\n"
            ),
        ]
        result = await get_entry(vault, audit, title="Production DB", group="Servers")
        assert result["username"] == "dba"
        assert result["password"] == "prodpass"
