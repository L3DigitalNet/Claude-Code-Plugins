import subprocess
from unittest.mock import patch

import pytest

from server.config import load_config
from server.yubikey import MockYubiKey


@pytest.fixture
def unlocked_vault(test_config, mock_yubikey):
    """A vault that's been unlocked (CLI calls are mocked)."""
    from server.vault import Vault
    from server.audit import AuditLogger

    with patch("subprocess.run") as mock_run:
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
    audit = AuditLogger(test_config.audit_log_path)
    return vault, audit


class TestReadTools:
    @patch("subprocess.run")
    def test_list_groups(self, mock_run, unlocked_vault):
        from server.tools.read import list_groups

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="Servers/\nSSH Keys/\nAPI Keys/\nBanking/\nRecycle Bin/\n",
            stderr="",
        )
        result = list_groups(vault)
        # Banking and Recycle Bin should be filtered out
        assert set(result) == {"Servers", "SSH Keys", "API Keys"}

    @patch("subprocess.run")
    def test_list_entries_filters_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Web Server\n[INACTIVE] Old Server\nDB Server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: DB Server\nUserName: dba\nURL: https://db.example.com\n",
                stderr="",
            ),
        ]
        result = list_entries(vault, audit, group="Servers")
        assert len(result) == 2
        titles = [e["title"] for e in result]
        assert "Web Server" in titles
        assert "[INACTIVE] Old Server" not in titles

    @patch("subprocess.run")
    def test_list_entries_includes_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Web Server\n[INACTIVE] Old Server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: [INACTIVE] Old Server\nUserName: old\nURL: https://old.example.com\n",
                stderr="",
            ),
        ]
        result = list_entries(vault, audit, group="Servers", include_inactive=True)
        assert len(result) == 2

    @patch("subprocess.run")
    def test_get_entry_returns_full_record(self, mock_run, unlocked_vault):
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout=(
                "Title: Web Server\n"
                "UserName: admin\n"
                "Password: s3cret\n"
                "URL: https://web.example.com\n"
                "Notes: Production server\n"
            ),
            stderr="",
        )
        result = get_entry(vault, audit, title="Web Server", group="Servers")
        assert result["title"] == "Web Server"
        assert result["username"] == "admin"
        assert result["password"] == "s3cret"
        assert result["url"] == "https://web.example.com"
        assert result["notes"] == "Production server"

    @patch("subprocess.run")
    def test_get_entry_raises_on_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import get_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            get_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_get_entry_audits_secret(self, mock_run, unlocked_vault, test_config):
        import json
        from pathlib import Path
        from server.tools.read import get_entry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="Title: Web Server\nUserName: admin\nPassword: s3cret\nURL: \nNotes: \n",
            stderr="",
        )
        get_entry(vault, audit, title="Web Server", group="Servers")
        log_line = Path(test_config.audit_log_path).read_text().strip()
        record = json.loads(log_line)
        assert record["tool"] == "get_entry"
        assert record["secret_returned"] is True

    @patch("subprocess.run")
    def test_search_entries(self, mock_run, unlocked_vault):
        from server.tools.read import search_entries

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Servers/Web Server\nBanking/My Bank\nAPI Keys/Anthropic\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nUserName: admin\nURL: https://web.example.com\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Anthropic\nUserName: key\nURL: https://api.anthropic.com\n",
                stderr="",
            ),
        ]
        result = search_entries(vault, audit, query="server")
        # Banking/My Bank should be filtered out (not in allowed_groups)
        assert len(result) == 2
        groups = [e["group"] for e in result]
        assert "Banking" not in groups

    @patch("subprocess.run")
    def test_get_attachment(self, mock_run, unlocked_vault, test_config):
        import json
        from pathlib import Path
        from server.tools.read import get_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0,
            stdout="ssh-ed25519 AAAA... user@host\n",
            stderr="",
        )
        result = get_attachment(
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

    @patch("subprocess.run")
    def test_get_attachment_raises_on_inactive(self, mock_run, unlocked_vault):
        from server.tools.read import get_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            get_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                group="SSH Keys",
            )

    @patch("subprocess.run")
    def test_list_entries_group_not_allowed(self, mock_run, unlocked_vault):
        from server.tools.read import list_entries
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            list_entries(vault, audit, group="Banking")


class TestWriteTools:
    @patch("subprocess.run")
    def test_create_entry(self, mock_run, unlocked_vault, test_config):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="Existing Entry\n", stderr=""
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
        ]
        create_entry(
            vault, audit,
            title="New Server",
            group="Servers",
            username="admin",
            password="pass123",
            url="https://new.example.com",
            notes="Test notes",
        )
        add_call = mock_run.call_args_list[-1]
        cmd = add_call.args[0] if add_call.args else add_call[0][0]
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)
        assert "add" in cmd_str

    @patch("subprocess.run")
    def test_create_entry_rejects_duplicate(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import DuplicateEntry

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="Existing Entry\n", stderr=""
        )
        with pytest.raises(DuplicateEntry):
            create_entry(
                vault, audit,
                title="Existing Entry",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_create_entry_rejects_slash_in_title(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry

        vault, audit = unlocked_vault
        with pytest.raises(ValueError, match="slash"):
            create_entry(
                vault, audit,
                title="Bad/Title",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_create_entry_group_not_allowed(self, mock_run, unlocked_vault):
        from server.tools.write import create_entry
        from server.vault import GroupNotAllowed

        vault, audit = unlocked_vault
        with pytest.raises(GroupNotAllowed):
            create_entry(
                vault, audit,
                title="New Entry",
                group="Banking",
            )

    @patch("subprocess.run")
    def test_deactivate_entry(self, mock_run, unlocked_vault):
        from server.tools.write import deactivate_entry

        vault, audit = unlocked_vault
        mock_run.side_effect = [
            subprocess.CompletedProcess(
                args=[], returncode=0,
                stdout="Title: Web Server\nNotes: Production server\n",
                stderr="",
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            ),
        ]
        deactivate_entry(vault, audit, title="Web Server", group="Servers")

        title_edit_call = mock_run.call_args_list[1]
        cmd = title_edit_call.args[0] if title_edit_call.args else title_edit_call[0][0]
        cmd_str = " ".join(cmd) if isinstance(cmd, list) else str(cmd)
        assert "[INACTIVE]" in cmd_str

    @patch("subprocess.run")
    def test_deactivate_already_inactive(self, mock_run, unlocked_vault):
        from server.tools.write import deactivate_entry
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            deactivate_entry(
                vault, audit,
                title="[INACTIVE] Old Server",
                group="Servers",
            )

    @patch("subprocess.run")
    def test_add_attachment(self, mock_run, unlocked_vault):
        from server.tools.write import add_attachment

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        add_attachment(
            vault, audit,
            title="SSH Key",
            attachment_name="id_ed25519",
            content=b"ssh-ed25519 AAAA...",
            group="SSH Keys",
        )

    @patch("subprocess.run")
    def test_add_attachment_cleans_temp_file(self, mock_run, unlocked_vault):
        import os
        from server.tools.write import add_attachment
        import tempfile

        vault, audit = unlocked_vault
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )

        original_ntf = tempfile.NamedTemporaryFile
        created_paths = []

        def tracking_ntf(**kwargs):
            f = original_ntf(**kwargs)
            created_paths.append(f.name)
            return f

        with patch("tempfile.NamedTemporaryFile", side_effect=tracking_ntf):
            add_attachment(
                vault, audit,
                title="SSH Key",
                attachment_name="id_ed25519",
                content=b"ssh-ed25519 AAAA...",
                group="SSH Keys",
            )

        for path in created_paths:
            assert not os.path.exists(path), f"Temp file not cleaned up: {path}"

    @patch("subprocess.run")
    def test_add_attachment_inactive_rejected(self, mock_run, unlocked_vault):
        from server.tools.write import add_attachment
        from server.vault import EntryInactive

        vault, audit = unlocked_vault
        with pytest.raises(EntryInactive):
            add_attachment(
                vault, audit,
                title="[INACTIVE] Old Key",
                attachment_name="id_rsa",
                content=b"key data",
                group="SSH Keys",
            )
