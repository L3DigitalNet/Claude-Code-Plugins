import asyncio
import subprocess
from unittest.mock import patch

import pytest

from server.yubikey import MockYubiKey


class TestVaultExceptions:
    def test_all_exceptions_exist(self):
        from server.vault import (
            VaultLocked,
            YubiKeyNotPresent,
            EntryNotFound,
            GroupNotAllowed,
            DuplicateEntry,
            EntryInactive,
            WriteLockTimeout,
            KeePassCLIError,
        )
        for exc_cls in (
            VaultLocked, YubiKeyNotPresent, EntryNotFound,
            GroupNotAllowed, DuplicateEntry, EntryInactive,
            WriteLockTimeout, KeePassCLIError,
        ):
            assert issubclass(exc_cls, Exception)


class TestVaultState:
    def test_starts_locked(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.is_unlocked is False

    def test_unlock_raises_when_yubikey_absent(self, test_config):
        from server.vault import Vault, YubiKeyNotPresent

        yk = MockYubiKey(present=False)
        vault = Vault(test_config, yk)
        with pytest.raises(YubiKeyNotPresent):
            vault.unlock()

    @patch("subprocess.run")
    def test_unlock_succeeds_with_yubikey(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        assert vault.is_unlocked is True

    @patch("subprocess.run")
    def test_unlock_raises_on_cli_error(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=1, stdout="", stderr="Error: Invalid credentials"
        )
        from server.vault import Vault, KeePassCLIError

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(KeePassCLIError):
            vault.unlock()

    @patch("subprocess.run")
    def test_run_cli_raises_when_locked(self, mock_run, test_config, mock_yubikey):
        from server.vault import Vault, VaultLocked

        vault = Vault(test_config, mock_yubikey)
        with pytest.raises(VaultLocked):
            vault.run_cli("ls", test_config.database_path)


class TestVaultGroupAllowlist:
    @patch("subprocess.run")
    def test_check_group_allowed(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        vault.check_group_allowed("Servers")  # Should not raise

    @patch("subprocess.run")
    def test_check_group_not_allowed(self, mock_run, test_config, mock_yubikey):
        mock_run.return_value = subprocess.CompletedProcess(
            args=[], returncode=0, stdout="", stderr=""
        )
        from server.vault import Vault, GroupNotAllowed

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        with pytest.raises(GroupNotAllowed):
            vault.check_group_allowed("Banking")


class TestVaultRunCli:
    @patch("subprocess.run")
    def test_run_cli_returns_stdout(self, mock_run, test_config, mock_yubikey):
        mock_run.side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            subprocess.CompletedProcess(
                args=[], returncode=0, stdout="Group1/\nGroup2/\n", stderr=""
            ),
        ]
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        result = vault.run_cli("ls", test_config.database_path)
        assert "Group1/" in result

    @patch("subprocess.run")
    def test_run_cli_raises_on_error(self, mock_run, test_config, mock_yubikey):
        mock_run.side_effect = [
            subprocess.CompletedProcess(args=[], returncode=0, stdout="", stderr=""),
            subprocess.CompletedProcess(
                args=[], returncode=1, stdout="", stderr="Error: entry not found"
            ),
        ]
        from server.vault import Vault, KeePassCLIError

        vault = Vault(test_config, mock_yubikey)
        vault.unlock()
        with pytest.raises(KeePassCLIError):
            vault.run_cli("show", test_config.database_path, "Nonexistent")


class TestVaultEntryPath:
    def test_with_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", "Servers") == "Servers/My Entry"

    def test_without_group(self, test_config, mock_yubikey):
        from server.vault import Vault

        vault = Vault(test_config, mock_yubikey)
        assert vault.entry_path("My Entry", None) == "My Entry"


class TestVaultGraceTimer:
    @pytest.mark.asyncio
    async def test_lock_after_grace_period(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            vault.unlock()

        assert vault.is_unlocked is True

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        # Grace period is 2s in test_config — wait for it plus buffer
        await asyncio.sleep(3)
        assert vault.is_unlocked is False
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass

    @pytest.mark.asyncio
    async def test_reinsertion_cancels_grace(self, test_config):
        from server.vault import Vault

        yk = MockYubiKey(present=True)
        vault = Vault(test_config, yk)
        with patch("subprocess.run") as mock_run:
            mock_run.return_value = subprocess.CompletedProcess(
                args=[], returncode=0, stdout="", stderr=""
            )
            vault.unlock()

        poll_task = asyncio.create_task(vault.start_polling())
        await asyncio.sleep(0.1)
        yk.present = False
        await asyncio.sleep(0.5)  # Within grace period
        yk.present = True  # Reinsert before grace expires
        await asyncio.sleep(2)  # Wait past original grace period
        assert vault.is_unlocked is True  # Should still be unlocked
        poll_task.cancel()
        try:
            await poll_task
        except asyncio.CancelledError:
            pass
